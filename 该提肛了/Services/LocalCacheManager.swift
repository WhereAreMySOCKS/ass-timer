import AppKit
import CryptoKit
import Foundation

/// Disk-backed cache for lightweight app data that should survive relaunches.
final class LocalCacheManager {
    static let shared = LocalCacheManager()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let imageCache = NSCache<NSURL, NSImage>()

    private let maxMessagesPerGroup = 100
    private let cacheRoot: URL
    private let chatDirectory: URL
    private let avatarDirectory: URL

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        cacheRoot = appSupport.appendingPathComponent("AssTimer", isDirectory: true)
        chatDirectory = cacheRoot.appendingPathComponent("chat", isDirectory: true)
        avatarDirectory = cacheRoot.appendingPathComponent("avatars", isDirectory: true)
        ensureDirectoriesExist()
    }

    // MARK: - Chat Messages

    func loadMessages(groupID: String) -> [ChatMessageResponse] {
        let url = chatFileURL(groupID: groupID)
        guard let data = try? Data(contentsOf: url),
              let messages = try? decoder.decode([ChatMessageResponse].self, from: data)
        else {
            return []
        }
        return sortedMessages(messages)
    }

    @discardableResult
    func saveMessages(_ messages: [ChatMessageResponse], groupID: String) -> [ChatMessageResponse] {
        ensureDirectoriesExist()
        let recent = Array(sortedMessages(messages).suffix(maxMessagesPerGroup))
        if let data = try? encoder.encode(recent) {
            try? data.write(to: chatFileURL(groupID: groupID), options: [.atomic])
        }
        return recent
    }

    @discardableResult
    func mergeMessages(_ incoming: [ChatMessageResponse], groupID: String) -> [ChatMessageResponse] {
        let existing = loadMessages(groupID: groupID)
        let merged = deduplicatedMessages(existing + incoming)
        return saveMessages(merged, groupID: groupID)
    }

    // MARK: - Avatars

    func cachedAvatarImage(for url: URL) -> NSImage? {
        let cacheKey = url as NSURL
        if let memoryImage = imageCache.object(forKey: cacheKey) {
            return memoryImage
        }

        let diskURL = avatarFileURL(for: url)
        guard let data = try? Data(contentsOf: diskURL),
              let image = NSImage(data: data)
        else {
            return nil
        }

        imageCache.setObject(image, forKey: cacheKey)
        return image
    }

    func loadAvatarImage(from url: URL) async -> NSImage? {
        if let cached = cachedAvatarImage(for: url) {
            return cached
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let image = NSImage(data: data)
            else {
                return nil
            }

            ensureDirectoriesExist()
            try? data.write(to: avatarFileURL(for: url), options: [.atomic])
            imageCache.setObject(image, forKey: url as NSURL)
            return image
        } catch {
            return nil
        }
    }

    func clearAllCaches() {
        imageCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheRoot)
        ensureDirectoriesExist()
    }

    // MARK: - Helpers

    private func ensureDirectoriesExist() {
        try? fileManager.createDirectory(at: chatDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: avatarDirectory, withIntermediateDirectories: true)
    }

    private func chatFileURL(groupID: String) -> URL {
        chatDirectory.appendingPathComponent("\(sha256Hex(groupID)).json")
    }

    private func avatarFileURL(for url: URL) -> URL {
        avatarDirectory.appendingPathComponent("\(sha256Hex(url.absoluteString)).img")
    }

    private func deduplicatedMessages(_ messages: [ChatMessageResponse]) -> [ChatMessageResponse] {
        var byID: [String: ChatMessageResponse] = [:]
        for message in messages {
            byID[message.message_id] = message
        }
        return sortedMessages(Array(byID.values))
    }

    private func sortedMessages(_ messages: [ChatMessageResponse]) -> [ChatMessageResponse] {
        messages.sorted { lhs, rhs in
            compareTimestamps(lhs.created_at, rhs.created_at)
        }
    }

    private func compareTimestamps(_ lhs: String, _ rhs: String) -> Bool {
        if let lhsDate = Self.dateFormatter.date(from: lhs),
           let rhsDate = Self.dateFormatter.date(from: rhs) {
            return lhsDate < rhsDate
        }
        return lhs < rhs
    }

    private func sha256Hex(_ string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
