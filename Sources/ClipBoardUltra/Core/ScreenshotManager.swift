import Foundation
import Cocoa
import ImageIO

public final class ScreenshotManager {
    public static let shared = ScreenshotManager()

    public var onNewScreenshot: ((ClipboardItem) -> Void)?

    private var directorySource: DispatchSourceFileSystemObject?
    private var directoryFileDescriptor: CInt = -1
    private var knownFilePaths = Set<String>()

    private init() {}

    public var screenshotDirectoryURL: URL {
        if let custom = SettingsStore.shared.customScreenshotFolder,
           FileManager.default.fileExists(atPath: custom) {
            return URL(fileURLWithPath: custom)
        }
        return systemScreenshotDirectoryURL
    }

    /// Where macOS saves screenshots (Screenshot app › Options › Save to).
    public var systemScreenshotDirectoryURL: URL {
        if let customLocation = UserDefaults.standard.persistentDomain(forName: "com.apple.screencapture")?["location"] as? String {
            let expanded = (customLocation as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expanded) {
                return URL(fileURLWithPath: expanded)
            }
        }
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        return desktop
    }

    public func startMonitoring() {
        let dirURL = screenshotDirectoryURL
        let path = dirURL.path

        // Seed initial known files
        let initial = fetchRecentScreenshotItems(limit: 20)
        for item in initial {
            if let p = item.filePath {
                knownFilePaths.insert(p)
            }
        }

        directoryFileDescriptor = open(path, O_EVTONLY)
        guard directoryFileDescriptor >= 0 else {
            print("Could not open screenshot directory for monitoring: \(path)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: directoryFileDescriptor,
            eventMask: [.write, .extend, .rename],
            queue: DispatchQueue.main
        )

        source.setEventHandler { [weak self] in
            self?.checkForNewScreenshots()
        }

        let fd = directoryFileDescriptor
        source.setCancelHandler {
            // Close the descriptor this source owns (not whatever the property holds later).
            close(fd)
        }

        source.resume()
        self.directorySource = source
    }

    public func stopMonitoring() {
        directorySource?.cancel()
        directorySource = nil
    }

    /// Re-points the folder watcher after the screenshot folder setting changes.
    public func restartMonitoring() {
        stopMonitoring()
        knownFilePaths.removeAll()
        startMonitoring()
    }

    public func fetchRecentScreenshotItems(limit: Int = 15) -> [ClipboardItem] {
        let dirURL = screenshotDirectoryURL
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: dirURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return []
        }

        var candidates: [(url: URL, date: Date, size: Int64)] = []

        while let fileURL = enumerator.nextObject() as? URL {
            let fileName = fileURL.lastPathComponent
            let ext = fileURL.pathExtension.lowercased()

            guard ext == "png" || ext == "jpg" || ext == "jpeg" else { continue }
            let isScreenshotName = fileName.hasPrefix("Screenshot") ||
                                   fileName.hasPrefix("Screen Shot") ||
                                   fileName.hasPrefix("CleanShot") ||
                                   fileName.contains("Capture")

            if isScreenshotName {
                let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                let date = values?.contentModificationDate ?? Date.distantPast
                let size = Int64(values?.fileSize ?? 0)
                candidates.append((url: fileURL, date: date, size: size))
            }
        }

        candidates.sort { $0.date > $1.date }

        var items: [ClipboardItem] = []
        for candidate in candidates.prefix(limit) {
            if let item = makeScreenshotItem(from: candidate.url, date: candidate.date, size: candidate.size) {
                items.append(item)
            }
        }

        return items
    }

    private func checkForNewScreenshots() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self else { return }
            let recent = self.fetchRecentScreenshotItems(limit: 5)
            for item in recent {
                guard let path = item.filePath else { continue }
                if !self.knownFilePaths.contains(path) {
                    self.knownFilePaths.insert(path)
                    self.onNewScreenshot?(item)
                }
            }
        }
    }

    private func makeScreenshotItem(from fileURL: URL, date: Date, size: Int64) -> ClipboardItem? {
        // Read dimensions directly from header using CGImageSource without loading full bitmap into RAM
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }

        let width = properties[kCGImagePropertyPixelWidth] as? CGFloat ?? 0
        let height = properties[kCGImagePropertyPixelHeight] as? CGFloat ?? 0
        let fileName = fileURL.lastPathComponent

        return ClipboardItem(
            type: .screenshot,
            title: fileName,
            previewText: "Screenshot (\(Int(width))×\(Int(height)))",
            fullText: nil,
            imageRelativePath: nil,
            imageWidth: width,
            imageHeight: height,
            filePath: fileURL.path,
            timestamp: date,
            isPinned: false,
            sourceAppName: "ScreenCapture",
            charCount: nil,
            lineCount: nil,
            byteSize: size
        )
    }
}
