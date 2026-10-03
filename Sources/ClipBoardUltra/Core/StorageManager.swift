import Foundation
import Cocoa
import ImageIO
import CryptoKit

public final class StorageManager {
    public static let shared = StorageManager()

    private let fileManager = FileManager.default
    private let appSupportURL: URL
    private let imagesURL: URL
    private let richURL: URL
    private let historyFileURL: URL
    private let snippetsFileURL: URL
    private let thumbnailCache = NSCache<NSString, NSImage>()
    private let writeQueue = DispatchQueue(label: "com.ultra.ClipBoardUltra.storage", qos: .utility)

    private init() {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.appSupportURL = base.appendingPathComponent("ClipBoardUltra", isDirectory: true)
        self.imagesURL = appSupportURL.appendingPathComponent("images", isDirectory: true)
        self.richURL = appSupportURL.appendingPathComponent("rich", isDirectory: true)
        self.historyFileURL = appSupportURL.appendingPathComponent("history.json")
        self.snippetsFileURL = appSupportURL.appendingPathComponent("snippets.json")

        thumbnailCache.countLimit = 100
        createDirectoriesIfNeeded()
    }

    private func createDirectoriesIfNeeded() {
        try? fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: richURL, withIntermediateDirectories: true)
    }

    // MARK: - Snippets

    public func saveSnippets(_ snippets: [Snippet]) {
        writeQueue.async { [weak self] in
            guard let self else { return }
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(snippets).write(to: self.snippetsFileURL, options: .atomic)
            } catch {
                print("Failed to save snippets: \(error)")
            }
        }
    }

    public func loadSnippets() -> [Snippet] {
        guard let data = try? Data(contentsOf: snippetsFileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Snippet].self, from: data)) ?? []
    }

    // MARK: - Rich text (RTF / HTML kept next to the plain string)

    /// Stores formatted representations keyed by pasteboard type. Returns the file name.
    public func saveRichData(_ data: [String: Data]) -> String? {
        guard !data.isEmpty else { return nil }
        createDirectoriesIfNeeded()
        let name = "\(UUID().uuidString).plist"
        do {
            let plist = try PropertyListSerialization.data(fromPropertyList: data, format: .binary, options: 0)
            try plist.write(to: richURL.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            print("Failed to save rich text: \(error)")
            return nil
        }
    }

    public func loadRichData(named name: String) -> [String: Data]? {
        guard let data = try? Data(contentsOf: richURL.appendingPathComponent(name)) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Data]
    }

    public func deleteRichData(named name: String) {
        try? fileManager.removeItem(at: richURL.appendingPathComponent(name))
    }

    /// Removes every file an item owns on disk (image copy, formatted text).
    public func deleteAssets(of item: ClipboardItem) {
        if let img = item.imageRelativePath { deleteImage(named: img) }
        if let rich = item.richRelativePath { deleteRichData(named: rich) }
    }

    // MARK: - Disk usage

    public func diskUsageBytes() -> Int64 {
        var total: Int64 = 0
        if let e = fileManager.enumerator(at: appSupportURL, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let url as URL in e {
                total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            }
        }
        return total
    }

    public func saveHistory(_ items: [ClipboardItem]) {
        // Serial queue keeps writes in order so an older snapshot never overwrites a newer one.
        writeQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(items)
                try data.write(to: self.historyFileURL, options: .atomic)
            } catch {
                print("Failed to save history: \(error)")
            }
        }
    }

    public func loadHistory() -> [ClipboardItem] {
        guard fileManager.fileExists(atPath: historyFileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: historyFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let items = try decoder.decode([ClipboardItem].self, from: data)
            return items
        } catch {
            print("Failed to load history: \(error)")
            return []
        }
    }

    public func saveImage(_ image: NSImage) -> (relativePath: String, width: CGFloat, height: CGFloat, byteSize: Int64, hash: String)? {
        createDirectoriesIfNeeded()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            return nil
        }

        let hash = SHA256.hash(data: pngData).map { String(format: "%02x", $0) }.joined()
        let fileName = "\(UUID().uuidString).png"
        let fileURL = imagesURL.appendingPathComponent(fileName)

        do {
            try pngData.write(to: fileURL, options: .atomic)
            // Pixel dimensions, not points, so Retina captures report their real size.
            return (fileName, CGFloat(rep.pixelsWide), CGFloat(rep.pixelsHigh), Int64(pngData.count), hash)
        } catch {
            print("Failed to save image file: \(error)")
            return nil
        }
    }

    public func loadImage(named fileName: String) -> NSImage? {
        let fileURL = imagesURL.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return NSImage(contentsOf: fileURL)
    }

    public func getThumbnail(for filePathOrRelative: String, isRelative: Bool = false, size: Int = 100) -> NSImage? {
        let fullPath = isRelative ? imagesURL.appendingPathComponent(filePathOrRelative).path : filePathOrRelative
        let cacheKey = "\(fullPath)_\(size)" as NSString

        if let cached = thumbnailCache.object(forKey: cacheKey) {
            return cached
        }

        guard fileManager.fileExists(atPath: fullPath) else { return nil }
        let url = URL(fileURLWithPath: fullPath)

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: size
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let thumb = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        thumbnailCache.setObject(thumb, forKey: cacheKey)
        return thumb
    }

    public func deleteImage(named fileName: String) {
        let fileURL = imagesURL.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
    }

    public func pruneOrphanedImages(activeItems: [ClipboardItem]) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let active = Set(activeItems.compactMap { $0.imageRelativePath } + activeItems.compactMap { $0.richRelativePath })
            for dir in [self.imagesURL, self.richURL] {
                guard let files = try? self.fileManager.contentsOfDirectory(atPath: dir.path) else { continue }
                for file in files where !active.contains(file) {
                    let url = dir.appendingPathComponent(file)
                    // Skip very new files so anything saved during launch is never removed.
                    let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                    if Date().timeIntervalSince(modified) > 120 {
                        try? self.fileManager.removeItem(at: url)
                    }
                }
            }
        }
    }
}
