import AppKit

/// Loads and caches sprite images from the bundle Resources/Sprites directory.
enum SpriteLoader {
    /// In-memory cache of loaded sprite images, keyed by base name (e.g. "站立-1").
    private static var cache: [String: NSImage] = [:]

    /// Load a sprite image by its base name (without extension).
    /// Returns a cached instance if already loaded.
    static func loadSprite(named name: String) -> NSImage? {
        // Return cached if available
        if let cached = cache[name] {
            return cached
        }

        guard let url = spriteURL(named: name) else {
            return nil
        }

        guard let image = NSImage(contentsOf: url) else { return nil }

        // Downscale to fit the pet window while preserving the source aspect ratio.
        let targetSize = Constants.petSpriteSize
        if image.size.width > targetSize.width || image.size.height > targetSize.height {
            let scaled = NSImage(size: targetSize)
            let scale = min(targetSize.width / image.size.width, targetSize.height / image.size.height)
            let drawSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
            let drawRect = NSRect(
                x: (targetSize.width - drawSize.width) / 2,
                y: (targetSize.height - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            scaled.lockFocus()
            NSColor.clear.setFill()
            NSRect(origin: .zero, size: targetSize).fill()
            image.draw(in: drawRect, from: .zero, operation: .copy, fraction: 1.0)
            scaled.unlockFocus()
            cache[name] = scaled
            return scaled
        }

        cache[name] = image
        return image
    }

    private static func spriteURL(named name: String) -> URL? {
        let bundle = Bundle.main
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
        return nil
    }
}
