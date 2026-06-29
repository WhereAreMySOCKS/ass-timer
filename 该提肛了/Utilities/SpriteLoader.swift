import AppKit
import ImageIO

/// Loads and caches sprite images bundled with the app.
enum SpriteLoader {
    private static var cache: [String: NSImage] = [:]

    static func loadSprite(named name: String) -> NSImage? {
        let cacheKey = normalizedResourceName(name)
        if let cached = cache[cacheKey] {
            return cached
        }

        guard let url = spriteURL(named: name),
              let image = downsampledImage(at: url, fitting: Constants.petSpriteSize) else {
            return nil
        }

        cache[cacheKey] = image
        return image
    }

    private static func spriteURL(named name: String) -> URL? {
        let bundle = Bundle.main

        // Xcode's synchronized folder currently flattens these resources into
        // Contents/Resources. Keep the subdirectory checks for older builds.
        for ext in ["png", "PNG"] {
            if let url = bundle.url(forResource: name, withExtension: ext) {
                return url
            }
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Sprites") {
                return url
            }
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Resources/Sprites") {
                return url
            }
        }

        // File names can arrive with a different Unicode normalization or
        // extension case after an app is archived/copied to another volume.
        // Compare the actual bundled files instead of relying on an exact path.
        guard let resourcesURL = bundle.resourceURL,
              let enumerator = FileManager.default.enumerator(
                at: resourcesURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else {
            return nil
        }

        let expectedName = normalizedResourceName(name)
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "png" else { continue }
            let candidate = normalizedResourceName(url.deletingPathExtension().lastPathComponent)
            if candidate == expectedName {
                return url
            }
        }

        return nil
    }

    /// ImageIO decodes the PNG to its display size without using AppKit's
    /// focus stack. Besides being much smaller in memory, this avoids blank
    /// images observed on some machines when `NSImage.lockFocus()` is used.
    private static func downsampledImage(at url: URL, fitting targetSize: CGSize) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        let maxPixelSize = Int(ceil(max(targetSize.width, targetSize.height) * 2))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let width = CGFloat(thumbnail.width)
        let height = CGFloat(thumbnail.height)
        let scale = min(targetSize.width / width, targetSize.height / height)
        let displaySize = NSSize(width: width * scale, height: height * scale)
        return NSImage(cgImage: thumbnail, size: displaySize)
    }

    private static func normalizedResourceName(_ name: String) -> String {
        name.precomposedStringWithCanonicalMapping.lowercased()
    }
}
