import AppKit
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

struct CustomActionMediaDraft: Sendable {
    let sourceData: Data
    let sourceExtension: String
    let backgroundPNG: Data
    var foregroundPNG: Data?
    var removesBackground: Bool
}

enum CustomActionMediaError: LocalizedError {
    case fileTooLarge
    case unsupportedImage
    case missingFiles
    case backgroundRemovalUnavailable
    case noForegroundFound
    case imageProcessingFailed

    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return "请选择 10MB 以内的图片"
        case .unsupportedImage:
            return "无法读取这张图片，请选择 PNG、JPG、HEIC 或 WebP 文件"
        case .missingFiles:
            return "素材文件已丢失，请重新选择图片"
        case .backgroundRemovalUnavailable:
            return "去除背景需要 macOS 14 或更高版本"
        case .noForegroundFound:
            return "没有识别到清晰的前景主体，请换一张图片"
        case .imageProcessingFailed:
            return "图片处理失败，请换一张图片重试"
        }
    }
}

/// Owns local custom-action files and keeps image processing outside SwiftUI views.
@MainActor
final class CustomActionMediaStore {
    static let shared = CustomActionMediaStore()

    nonisolated private static let maximumFileSize = 10 * 1024 * 1024
    nonisolated private static let outputWidth = 216
    nonisolated private static let outputHeight = 288

    private let fileManager = FileManager.default
    private let mediaRoot: URL
    private var imageCache: [String: NSImage] = [:]

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        mediaRoot = appSupport
            .appendingPathComponent("AssTimer", isDirectory: true)
            .appendingPathComponent("custom-actions", isDirectory: true)
        ensureDirectoryExists()
    }

    func prepareDraft(from fileURL: URL) async throws -> CustomActionMediaDraft {
        let hasSecurityScope = fileURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard resourceValues.isRegularFile == true else {
            throw CustomActionMediaError.unsupportedImage
        }
        guard (resourceValues.fileSize ?? 0) <= Self.maximumFileSize else {
            throw CustomActionMediaError.fileTooLarge
        }
        let sourceData = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        guard sourceData.count <= Self.maximumFileSize else {
            throw CustomActionMediaError.fileTooLarge
        }

        let sourceExtension = Self.normalizedSourceExtension(fileURL.pathExtension)
        let backgroundPNG = try await Self.runDetached {
            try Self.makeBackgroundPNG(from: sourceData)
        }
        return CustomActionMediaDraft(
            sourceData: sourceData,
            sourceExtension: sourceExtension,
            backgroundPNG: backgroundPNG,
            foregroundPNG: nil,
            removesBackground: false
        )
    }

    func loadDraft(entry: CustomActionMediaEntry) async throws -> CustomActionMediaDraft {
        let sourceURL = mediaRoot.appendingPathComponent(entry.sourceFileName)
        let backgroundURL = mediaRoot.appendingPathComponent(entry.backgroundFileName)
        let foregroundURL = entry.foregroundFileName.map { mediaRoot.appendingPathComponent($0) }

        return try await Self.runDetached {
            guard let sourceData = try? Data(contentsOf: sourceURL),
                  let backgroundPNG = try? Data(contentsOf: backgroundURL) else {
                throw CustomActionMediaError.missingFiles
            }
            let foregroundPNG = foregroundURL.flatMap { try? Data(contentsOf: $0) }
            return CustomActionMediaDraft(
                sourceData: sourceData,
                sourceExtension: sourceURL.pathExtension,
                backgroundPNG: backgroundPNG,
                foregroundPNG: foregroundPNG,
                removesBackground: entry.removesBackground && foregroundPNG != nil
            )
        }
    }

    func generateForegroundPNG(from sourceData: Data) async throws -> Data {
        guard #available(macOS 14.0, *) else {
            throw CustomActionMediaError.backgroundRemovalUnavailable
        }
        return try await Self.runDetached {
            try Self.makeForegroundPNG(from: sourceData)
        }
    }

    func save(
        draft: CustomActionMediaDraft,
        slot: CustomActionSlot,
        replacing oldEntry: CustomActionMediaEntry?
    ) async throws -> CustomActionMediaEntry {
        ensureDirectoryExists()

        let revision = UUID()
        let stem = "\(slot.rawValue)-\(revision.uuidString.lowercased())"
        let sourceFileName = "\(stem)-source.\(draft.sourceExtension)"
        let backgroundFileName = "\(stem)-background.png"
        let foregroundFileName = draft.foregroundPNG == nil ? nil : "\(stem)-foreground.png"
        let sourceURL = mediaRoot.appendingPathComponent(sourceFileName)
        let backgroundURL = mediaRoot.appendingPathComponent(backgroundFileName)
        let foregroundURL = foregroundFileName.map { mediaRoot.appendingPathComponent($0) }

        try await Self.runDetached {
            try draft.sourceData.write(to: sourceURL, options: [.atomic])
            do {
                try draft.backgroundPNG.write(to: backgroundURL, options: [.atomic])
                if let foregroundPNG = draft.foregroundPNG, let foregroundURL {
                    try foregroundPNG.write(to: foregroundURL, options: [.atomic])
                }
            } catch {
                try? FileManager.default.removeItem(at: sourceURL)
                try? FileManager.default.removeItem(at: backgroundURL)
                if let foregroundURL {
                    try? FileManager.default.removeItem(at: foregroundURL)
                }
                throw error
            }
        }

        let entry = CustomActionMediaEntry(
            sourceFileName: sourceFileName,
            backgroundFileName: backgroundFileName,
            foregroundFileName: foregroundFileName,
            removesBackground: draft.removesBackground && foregroundFileName != nil,
            revision: revision
        )
        imageCache.removeAll()
        if let oldEntry {
            removeFiles(for: oldEntry)
        }
        return entry
    }

    func image(for entry: CustomActionMediaEntry) -> NSImage? {
        let preferredName = entry.removesBackground
            ? (entry.foregroundFileName ?? entry.backgroundFileName)
            : entry.backgroundFileName
        let cacheKey = "\(entry.revision.uuidString)-\(preferredName)"
        if let cached = imageCache[cacheKey] {
            return cached
        }

        let preferredURL = mediaRoot.appendingPathComponent(preferredName)
        let fallbackURL = mediaRoot.appendingPathComponent(entry.backgroundFileName)
        let image = NSImage(contentsOf: preferredURL) ?? NSImage(contentsOf: fallbackURL)
        if let image {
            imageCache[cacheKey] = image
        }
        return image
    }

    func remove(entry: CustomActionMediaEntry) {
        removeFiles(for: entry)
        imageCache.removeAll()
    }

    func clearAll() {
        imageCache.removeAll()
        try? fileManager.removeItem(at: mediaRoot)
        ensureDirectoryExists()
    }

    private func removeFiles(for entry: CustomActionMediaEntry) {
        let names = [
            entry.sourceFileName,
            entry.backgroundFileName,
            entry.foregroundFileName,
        ].compactMap { $0 }
        for name in names {
            try? fileManager.removeItem(at: mediaRoot.appendingPathComponent(name))
        }
    }

    private func ensureDirectoryExists() {
        try? fileManager.createDirectory(at: mediaRoot, withIntermediateDirectories: true)
    }

    private nonisolated static func runDetached<T: Sendable>(
        _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        let task = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let result = try work()
            try Task.checkCancellation()
            return result
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private nonisolated static func normalizedSourceExtension(_ value: String) -> String {
        let normalized = value.lowercased()
        let allowed = ["png", "jpg", "jpeg", "heic", "webp"]
        return allowed.contains(normalized) ? normalized : "img"
    }

    private nonisolated static func decodedImage(from data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw CustomActionMediaError.unsupportedImage
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 4096,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw CustomActionMediaError.unsupportedImage
        }
        return image
    }

    private nonisolated static func makeBackgroundPNG(from data: Data) throws -> Data {
        let image = try decodedImage(from: data)
        guard let context = makeBitmapContext(width: outputWidth, height: outputHeight) else {
            throw CustomActionMediaError.imageProcessingFailed
        }

        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        let scale = max(CGFloat(outputWidth) / imageWidth, CGFloat(outputHeight) / imageHeight)
        let drawWidth = imageWidth * scale
        let drawHeight = imageHeight * scale
        let rect = CGRect(
            x: (CGFloat(outputWidth) - drawWidth) / 2,
            y: (CGFloat(outputHeight) - drawHeight) / 2,
            width: drawWidth,
            height: drawHeight
        )
        context.interpolationQuality = .high
        context.draw(image, in: rect)
        guard let output = context.makeImage() else {
            throw CustomActionMediaError.imageProcessingFailed
        }
        return try pngData(from: output)
    }

    @available(macOS 14.0, *)
    private nonisolated static func makeForegroundPNG(from data: Data) throws -> Data {
        let image = try decodedImage(from: data)
        try Task.checkCancellation()

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        try Task.checkCancellation()

        guard let observation = request.results?.first,
              !observation.allInstances.isEmpty else {
            throw CustomActionMediaError.noForegroundFound
        }
        let pixelBuffer = try observation.generateMaskedImage(
            ofInstances: observation.allInstances,
            from: handler,
            croppedToInstancesExtent: true
        )
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let ciContext = CIContext(options: [.cacheIntermediates: false])
        guard let maskedImage = ciContext.createCGImage(ciImage, from: ciImage.extent),
              let outputContext = makeBitmapContext(width: outputWidth, height: outputHeight) else {
            throw CustomActionMediaError.imageProcessingFailed
        }

        let padding: CGFloat = 14
        let availableWidth = CGFloat(outputWidth) - padding * 2
        let availableHeight = CGFloat(outputHeight) - padding * 2
        let maskedWidth = CGFloat(maskedImage.width)
        let maskedHeight = CGFloat(maskedImage.height)
        let scale = min(availableWidth / maskedWidth, availableHeight / maskedHeight)
        let drawWidth = maskedWidth * scale
        let drawHeight = maskedHeight * scale
        let rect = CGRect(
            x: (CGFloat(outputWidth) - drawWidth) / 2,
            y: (CGFloat(outputHeight) - drawHeight) / 2,
            width: drawWidth,
            height: drawHeight
        )
        outputContext.clear(CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
        outputContext.interpolationQuality = .high
        outputContext.draw(maskedImage, in: rect)
        guard let output = outputContext.makeImage() else {
            throw CustomActionMediaError.imageProcessingFailed
        }
        return try pngData(from: output)
    }

    private nonisolated static func makeBitmapContext(width: Int, height: Int) -> CGContext? {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    private nonisolated static func pngData(from image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw CustomActionMediaError.imageProcessingFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CustomActionMediaError.imageProcessingFailed
        }
        return data as Data
    }
}
