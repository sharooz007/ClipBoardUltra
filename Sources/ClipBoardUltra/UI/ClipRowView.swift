import SwiftUI
import Cocoa

/// One slip on the paper roll. Selected slips print in reverse (paper on ink).
public struct ClipRowView: View {
    public let item: ClipboardItem
    public let isSelected: Bool
    public let quickIndex: Int?
    public let onSelect: () -> Void
    public let onPaste: () -> Void
    public let onTogglePin: () -> Void
    public let onDelete: () -> Void

    @State private var isHovered = false

    private var inkColor: Color { isSelected ? Theme.paper : Theme.ink }
    private var fadedColor: Color { isSelected ? Theme.paper.opacity(0.72) : Theme.inkFaded }

    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            leadingMark

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium, design: isCode ? .monospaced : .default))
                    .foregroundColor(inkColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(metaLine)
                    .font(Theme.mono(10))
                    .foregroundColor(fadedColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isHovered && !isSelected && !item.isSnippet {
                hoverActions
            } else if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? Theme.amber : Theme.orangeDeep)
                    .accessibilityLabel("Pinned")
            }

            if let thumb = thumbnailImage {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(inkColor.opacity(0.25), lineWidth: 1))
            } else if case .file(let path) = item.type {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .frame(width: 30, height: 30)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(minHeight: 56)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isSelected ? Theme.ink : (isHovered ? Theme.paperShade : Color.clear))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
        .simultaneousGesture(TapGesture(count: 2).onEnded { onPaste() })
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.kindLabel.capitalized): \(item.title)")
        .accessibilityHint("Double-click or press Return to paste")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    /// ⌘1–⌘9 key for the first nine slips, a type glyph for the rest.
    @ViewBuilder
    private var leadingMark: some View {
        ZStack {
            if let idx = quickIndex {
                Text("⌘\(idx)")
                    .font(Theme.mono(9.5, .semibold))
                    .foregroundColor(inkColor.opacity(isSelected ? 1 : 0.8))
                    .frame(width: 28, height: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(inkColor.opacity(isSelected ? 0.5 : 0.28), lineWidth: 1)
                    )
            } else {
                Image(systemName: item.type.iconName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(fadedColor)
                    .frame(width: 28, height: 20)
            }
        }
        .accessibilityHidden(true)
    }

    private var hoverActions: some View {
        HStack(spacing: 2) {
            Button(action: onTogglePin) {
                Image(systemName: item.isPinned ? "pin.slash" : "pin")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .help(item.isPinned ? "Unpin" : "Pin to top")
            .accessibilityLabel(item.isPinned ? "Unpin" : "Pin")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .help("Delete from history")
            .accessibilityLabel("Delete")
        }
        .buttonStyle(.plain)
        .foregroundColor(Theme.inkFaded)
    }

    private var isCode: Bool {
        if case .code = item.type { return true }
        return false
    }

    private var metaLine: String {
        var parts: [String] = [item.kindLabel]
        switch item.type {
        case .text, .code:
            if let lines = item.lineCount, lines > 1 { parts.append("\(lines) LN") }
            else if let chars = item.charCount { parts.append("\(chars) CH") }
            if item.hasRichText { parts.append("FORMATTED") }
        case .snippet:
            if let keyword = item.keyword { parts.append(keyword.uppercased()) }
            if let lines = item.lineCount, lines > 1 { parts.append("\(lines) LN") }
            return parts.joined(separator: " · ")
        case .image, .screenshot:
            if let w = item.imageWidth, let h = item.imageHeight { parts.append("\(Int(w))×\(Int(h))") }
        case .file:
            if !item.formattedSize.isEmpty { parts.append(item.formattedSize.uppercased()) }
        }
        parts.append(item.relativeTime.uppercased())
        if let app = item.sourceAppName, app != "ScreenCapture" { parts.append(app.uppercased()) }
        return parts.joined(separator: " · ")
    }

    private var thumbnailImage: NSImage? {
        if let rel = item.imageRelativePath {
            return StorageManager.shared.getThumbnail(for: rel, isRelative: true, size: 96)
        } else if case .screenshot = item.type, let path = item.filePath {
            return StorageManager.shared.getThumbnail(for: path, isRelative: false, size: 96)
        }
        return nil
    }
}
