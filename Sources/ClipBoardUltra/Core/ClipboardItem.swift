import Foundation
import Cocoa

public enum ClipboardContentType: Codable, Equatable {
    case text
    case code(language: String)
    case image
    case screenshot
    case file(path: String)
    /// A saved snippet shown in the overlay (never stored in history).
    case snippet

    public var rawBadge: String {
        switch self {
        case .text: return "TEXT"
        case .code(let lang): return "CODE: \(lang.uppercased())"
        case .image: return "IMAGE"
        case .screenshot: return "SCREENSHOT"
        case .file: return "FILE"
        case .snippet: return "SNIPPET"
        }
    }
    
    public var iconName: String {
        switch self {
        case .text: return "doc.text"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .image: return "photo"
        case .screenshot: return "camera.viewfinder"
        case .file: return "folder"
        case .snippet: return "bookmark"
        }
    }
}

public struct ClipboardItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public var type: ClipboardContentType
    public var title: String
    public var previewText: String
    public var fullText: String?
    public var imageRelativePath: String?
    public var imageWidth: CGFloat?
    public var imageHeight: CGFloat?
    public var filePath: String?
    public var timestamp: Date
    public var isPinned: Bool
    public var sourceAppName: String?
    public var charCount: Int?
    public var lineCount: Int?
    public var byteSize: Int64?
    /// SHA-256 of image bytes, used to avoid storing the same copied image twice.
    public var contentHash: String?
    /// File in Application Support/rich holding RTF/HTML for "paste with formatting".
    public var richRelativePath: String?
    /// Snippet shortcut word, only for `.snippet` rows.
    public var keyword: String?

    public var hasRichText: Bool { richRelativePath != nil }

    public var isSnippet: Bool {
        if case .snippet = type { return true }
        return false
    }

    public var isTextual: Bool {
        switch type {
        case .text, .code, .snippet: return true
        default: return false
        }
    }

    public init(
        id: UUID = UUID(),
        type: ClipboardContentType,
        title: String,
        previewText: String,
        fullText: String? = nil,
        imageRelativePath: String? = nil,
        imageWidth: CGFloat? = nil,
        imageHeight: CGFloat? = nil,
        filePath: String? = nil,
        timestamp: Date = Date(),
        isPinned: Bool = false,
        sourceAppName: String? = nil,
        charCount: Int? = nil,
        lineCount: Int? = nil,
        byteSize: Int64? = nil,
        contentHash: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.previewText = previewText
        self.fullText = fullText
        self.imageRelativePath = imageRelativePath
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.filePath = filePath
        self.timestamp = timestamp
        self.isPinned = isPinned
        self.sourceAppName = sourceAppName
        self.charCount = charCount
        self.lineCount = lineCount
        self.byteSize = byteSize
        self.contentHash = contentHash
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useBytes, .useKB, .useMB]
        f.countStyle = .file
        return f
    }()

    public var relativeTime: String {
        if Date().timeIntervalSince(timestamp) < 10 { return "now" }
        return Self.relativeFormatter.localizedString(for: timestamp, relativeTo: Date())
    }

    public var formattedSize: String {
        guard let bytes = byteSize, bytes > 0 else { return "" }
        return Self.byteFormatter.string(fromByteCount: bytes)
    }

    /// Short uppercase kind label used in metadata lines, e.g. "SWIFT", "TEXT".
    public var kindLabel: String {
        switch type {
        case .text: return "TEXT"
        case .code(let lang): return lang.isEmpty ? "CODE" : lang.uppercased()
        case .image: return "IMAGE"
        case .screenshot: return "SCREENSHOT"
        case .file: return "FILE"
        case .snippet: return "SNIPPET"
        }
    }
}
