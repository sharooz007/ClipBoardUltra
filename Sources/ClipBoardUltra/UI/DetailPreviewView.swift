import SwiftUI
import Cocoa

/// Right-hand readout: the selected clip on a recessed screen, with its action keys below.
public struct DetailPreviewView: View {
    public let item: ClipboardItem?
    public let onPaste: () -> Void
    public let onCopy: () -> Void
    public let onTogglePin: () -> Void
    public let onDelete: () -> Void

    public var body: some View {
        VStack(spacing: 10) {
            screen
            actionRow
        }
    }

    // MARK: Screen

    private var screen: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let item {
                VStack(alignment: .leading, spacing: 4) {
                    Text(metaLine(for: item))
                        .font(Theme.mono(10, .semibold))
                        .foregroundColor(Theme.amber)
                        .lineLimit(1)
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.bone)
                        .lineLimit(2)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

                Rectangle().fill(Theme.hairline).frame(height: 1)

                content(for: item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(spacing: 6) {
                    Spacer()
                    Text("NO CLIP SELECTED")
                        .font(Theme.mono(11, .semibold))
                        .foregroundColor(Theme.amber.opacity(0.8))
                    Text("Pick a slip on the left to see all of it here.")
                        .font(.system(size: 11.5))
                        .foregroundColor(Theme.boneDim)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.screen)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.black.opacity(0.75), lineWidth: 1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .trim(from: 0.52, to: 0.98)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func content(for item: ClipboardItem) -> some View {
        switch item.type {
        case .text, .code, .snippet:
            let isCode: Bool = { if case .text = item.type { return false }; return true }()
            ScrollView(isCode ? [.vertical, .horizontal] : [.vertical]) {
                Text(String((item.fullText ?? item.previewText).prefix(20_000)))
                    .font(isCode ? Theme.mono(11.5) : .system(size: 12.5))
                    .foregroundColor(Theme.bone.opacity(0.92))
                    .lineSpacing(isCode ? 2 : 3)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: isCode, vertical: false)
                    .frame(maxWidth: isCode ? nil : .infinity, alignment: .topLeading)
                    .padding(14)
            }

        case .image, .screenshot:
            VStack(spacing: 8) {
                if let image = previewImage(for: item) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Spacer()
                    Text("Image file is missing")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.boneDim)
                    Spacer()
                }
                if let path = item.filePath {
                    HStack(spacing: 8) {
                        Text(abbreviate(path))
                            .font(Theme.mono(10))
                            .foregroundColor(Theme.boneDim)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 4)
                        Button("Show in Finder") { reveal(path) }
                            .buttonStyle(KeycapStyle(tone: .graphite, compact: true))
                    }
                }
            }
            .padding(14)

        case .file(let path):
            VStack(spacing: 12) {
                Spacer()
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .frame(width: 72, height: 72)
                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                Text(abbreviate(path))
                    .font(Theme.mono(10.5))
                    .foregroundColor(Theme.boneDim)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 16)
                if !FileManager.default.fileExists(atPath: path) {
                    Text("This file has moved or been deleted")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.orange)
                }
                Button("Show in Finder") { reveal(path) }
                    .buttonStyle(KeycapStyle(tone: .graphite, compact: true))
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Actions

    private var actionRow: some View {
        HStack(spacing: 8) {
            if item?.isSnippet == true {
                Button {
                    if let id = item?.id {
                        OverlayPanelManager.shared.hide()
                        SettingsWindowController.shared.show(tab: .snippets, selectSnippet: id)
                    }
                } label: {
                    Label("Edit Snippet", systemImage: "pencil")
                }
                .buttonStyle(KeycapStyle(tone: .graphite, compact: true))
            } else {
                pinAndDelete
            }

            Spacer(minLength: 6)

            Button(action: onCopy) {
                HStack(spacing: 6) {
                    Text("⌘C").font(Theme.mono(10, .bold)).opacity(0.7)
                    Text("Copy")
                }
            }
            .buttonStyle(KeycapStyle(tone: .bone))
            .help("Copy to the clipboard without pasting")

            Button(action: onPaste) {
                HStack(spacing: 6) {
                    Text("↩").font(.system(size: 12, weight: .bold))
                    Text("Paste")
                }
                .frame(minWidth: 70)
            }
            .buttonStyle(KeycapStyle(tone: .orange))
            .help("Paste into the app you were using · ⇧↩ switches plain/formatted")
        }
        .disabled(item == nil)
    }

    @ViewBuilder
    private var pinAndDelete: some View {
        Button(action: onTogglePin) {
            Label(item?.isPinned == true ? "Unpin" : "Pin", systemImage: item?.isPinned == true ? "pin.slash" : "pin")
        }
        .buttonStyle(KeycapStyle(tone: .graphite, lit: item?.isPinned == true, compact: true))
        .help("⌘P")

        Button(action: onDelete) {
            Label("Delete", systemImage: "trash")
        }
        .buttonStyle(KeycapStyle(tone: .graphite, compact: true))
        .help("⌘⌫")

        if item?.isTextual == true {
            Button {
                if let item { OverlayPanelManager.shared.saveAsSnippet(item) }
            } label: {
                Label("Snippet", systemImage: "bookmark")
            }
            .buttonStyle(KeycapStyle(tone: .graphite, compact: true))
            .help("Save as snippet (⌘S)")
        }
    }

    // MARK: Helpers

    private func metaLine(for item: ClipboardItem) -> String {
        var parts: [String] = [item.kindLabel]
        if let keyword = item.keyword { parts.append("KEYWORD \(keyword.uppercased())") }
        if item.hasRichText { parts.append("FORMATTED") }
        if let lines = item.lineCount, let chars = item.charCount {
            parts.append("\(lines) \(lines == 1 ? "LINE" : "LINES")")
            parts.append("\(chars) CHARS")
        } else if let w = item.imageWidth, let h = item.imageHeight {
            parts.append("\(Int(w)) × \(Int(h)) PX")
        }
        if !item.formattedSize.isEmpty { parts.append(item.formattedSize.uppercased()) }
        if let app = item.sourceAppName, app != "ScreenCapture" { parts.append("FROM \(app.uppercased())") }
        parts.append(item.relativeTime.uppercased())
        return parts.joined(separator: " · ")
    }

    private func previewImage(for item: ClipboardItem) -> NSImage? {
        if let rel = item.imageRelativePath {
            return StorageManager.shared.getThumbnail(for: rel, isRelative: true, size: 1000)
        }
        if let path = item.filePath {
            return StorageManager.shared.getThumbnail(for: path, isRelative: false, size: 1000)
        }
        return nil
    }

    private func abbreviate(_ path: String) -> String {
        (path as NSString).abbreviatingWithTildeInPath
    }

    private func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        OverlayPanelManager.shared.hide()
    }
}
