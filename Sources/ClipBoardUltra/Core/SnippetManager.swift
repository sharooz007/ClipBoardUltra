import Foundation
import Cocoa
import Combine

/// Reusable text you write once and paste often (signatures, addresses, boilerplate).
public struct Snippet: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var content: String
    /// Optional short word to find it quickly, e.g. "sig" or ";addr".
    public var keyword: String
    public var createdAt: Date
    public var updatedAt: Date
    public var useCount: Int

    public init(id: UUID = UUID(), name: String, content: String, keyword: String = "") {
        self.id = id
        self.name = name
        self.content = content
        self.keyword = keyword
        self.createdAt = Date()
        self.updatedAt = Date()
        self.useCount = 0
    }

    /// A row the overlay can list next to clipboard items.
    var asClipboardItem: ClipboardItem {
        var item = ClipboardItem(
            id: id,
            type: .snippet,
            title: name.isEmpty ? "Untitled snippet" : name,
            previewText: String(content.prefix(600)),
            fullText: content,
            timestamp: updatedAt,
            charCount: content.count,
            lineCount: content.components(separatedBy: .newlines).count
        )
        item.keyword = keyword.isEmpty ? nil : keyword
        return item
    }
}

public final class SnippetManager: ObservableObject {
    public static let shared = SnippetManager()

    @Published public private(set) var snippets: [Snippet] = [] {
        didSet { ClipboardManager.shared.recomputeFilteredItems() }
    }

    /// Placeholders the user can put in a snippet; shown as help in Settings.
    public static let placeholders: [(token: String, meaning: String)] = [
        ("{date}", "Today, e.g. 2026-09-29"),
        ("{time}", "Current time, e.g. 14:05"),
        ("{datetime}", "Date and time"),
        ("{weekday}", "Day name, e.g. Tuesday"),
        ("{clipboard}", "Whatever is on the clipboard right now"),
        ("{uuid}", "A new random UUID"),
        ("{cursor}", "Where the text cursor ends up after pasting")
    ]

    private init() {
        snippets = StorageManager.shared.loadSnippets()
    }

    /// Alphabetical, most-used first within equal names is not needed; keep it predictable.
    public var sorted: [Snippet] {
        snippets.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func snippet(id: UUID) -> Snippet? {
        snippets.first { $0.id == id }
    }

    @discardableResult
    public func add(name: String, content: String, keyword: String = "") -> Snippet {
        let s = Snippet(name: name, content: content, keyword: keyword)
        snippets.append(s)
        persist()
        return s
    }

    public func update(_ snippet: Snippet) {
        guard let i = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        var s = snippet
        s.updatedAt = Date()
        snippets[i] = s
        persist()
    }

    public func delete(id: UUID) {
        snippets.removeAll { $0.id == id }
        persist()
    }

    public func markUsed(id: UUID) {
        guard let i = snippets.firstIndex(where: { $0.id == id }) else { return }
        snippets[i].useCount += 1
        persist()
    }

    private func persist() {
        StorageManager.shared.saveSnippets(snippets)
    }

    // MARK: Expansion

    public struct Expansion {
        public let text: String
        /// How many characters the cursor must move left after pasting to land on {cursor}.
        public let cursorOffsetFromEnd: Int?
    }

    /// Replaces placeholders. Call before the pasteboard is overwritten so {clipboard} is correct.
    public static func expand(_ content: String, now: Date = Date(), clipboard: String? = NSPasteboard.general.string(forType: .string)) -> Expansion {
        func fmt(_ pattern: String) -> String {
            let f = DateFormatter()
            f.locale = Locale.current
            f.dateFormat = pattern
            return f.string(from: now)
        }
        let dateStyle: DateFormatter = {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            return f
        }()

        var text = content
        let replacements: [String: String] = [
            "{date}": fmt("yyyy-MM-dd"),
            "{time}": fmt("HH:mm"),
            "{datetime}": dateStyle.string(from: now),
            "{weekday}": fmt("EEEE"),
            "{clipboard}": clipboard ?? ""
        ]
        for (token, value) in replacements {
            text = text.replacingOccurrences(of: token, with: value)
        }
        while let r = text.range(of: "{uuid}") {
            text.replaceSubrange(r, with: UUID().uuidString)
        }

        var offset: Int?
        if let r = text.range(of: "{cursor}") {
            let after = text[r.upperBound...].replacingOccurrences(of: "{cursor}", with: "")
            text = String(text[..<r.lowerBound]) + after
            // Left-arrow presses count UTF-16 code units poorly for emoji; Characters match caret steps.
            offset = after.count
        }
        return Expansion(text: text, cursorOffsetFromEnd: offset)
    }
}
