import SwiftUI
import Cocoa

// MARK: - AppKit Visual Effect View for Behind-Window Blending

/// Native AppKit NSVisualEffectView for hardware-accelerated optical blur behind window.
public struct VisualEffectBlur: NSViewRepresentable {
    public var material: NSVisualEffectView.Material = .underWindowBackground
    public var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    public var state: NSVisualEffectView.State = .active

    public init(
        material: NSVisualEffectView.Material = .underWindowBackground,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.autoresizingMask = [.width, .height]
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - Liquid Glass Design System Tokens & Modifiers

public enum LiquidGlass {
    // Apple System Blue & Vibrant Accents
    public static let accent = Color(hex: 0x0A84FF)
    public static let accentGlow = Color(hex: 0x0A84FF).opacity(0.4)
    public static let glassTint = Color.white.opacity(0.06)

    // Specular Rim Gradient: Simulates light hitting the top-left edge of real glass
    public static var specularRim: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.45),
                Color.white.opacity(0.16),
                Color.white.opacity(0.06),
                Color.white.opacity(0.22)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static var specularRimSubtle: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.25),
                Color.white.opacity(0.08),
                Color.white.opacity(0.03),
                Color.white.opacity(0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Liquid Glass Container Styles

/// Shape that rounds only top-left and top-right corners
public struct TopRoundedCorners: Shape {
    public var radius: CGFloat
    public init(radius: CGFloat) { self.radius = radius }

    public func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        p.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

public struct LiquidGlassChassis: ViewModifier {
    public var cornerRadius: CGFloat = 18

    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Optical behind-window material
                    VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                    // Secondary ultra-thin diffusion layer
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // Atmospheric ambient tint
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.28))

                    // Overhead optical sheen reflection
                    VStack {
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.white.opacity(0.02), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 38)
                        .clipShape(TopRoundedCorners(radius: cornerRadius))
                        Spacer()
                    }

                    // Apple Signature Specular Rim Light Border
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(LiquidGlass.specularRim, lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.35), radius: 28, x: 0, y: 14)
            )
    }
}

public struct LiquidGlassCard: ViewModifier {
    public var cornerRadius: CGFloat = 12
    public var isSelected: Bool = false
    public var isHovered: Bool = false

    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    if isSelected {
                        // Vibrant active selection pill
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(LiquidGlass.accent.opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                            )
                            .shadow(color: LiquidGlass.accent.opacity(0.35), radius: 8, x: 0, y: 2)
                    } else if isHovered {
                        // Soft frosted hover glow
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.thinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.75)
                            )
                    } else {
                        // Quiet translucent resting state
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.primary.opacity(0.02))
                    }
                }
            )
    }
}

public extension View {
    func liquidGlassChassis(cornerRadius: CGFloat = 18) -> some View {
        self.modifier(LiquidGlassChassis(cornerRadius: cornerRadius))
    }

    func liquidGlassCard(cornerRadius: CGFloat = 12, isSelected: Bool = false, isHovered: Bool = false) -> some View {
        self.modifier(LiquidGlassCard(cornerRadius: cornerRadius, isSelected: isSelected, isHovered: isHovered))
    }
}

// MARK: - Liquid Glass Pill Buttons

public struct GlassPillStyle: ButtonStyle {
    public enum Tone {
        case regular
        case accent
        case destructive
    }

    public var tone: Tone = .regular
    public var isSelected: Bool = false
    public var compact: Bool = false

    public func makeBody(configuration: Configuration) -> some View {
        GlassPillBody(configuration: configuration, tone: tone, isSelected: isSelected, compact: compact)
    }

    private struct GlassPillBody: View {
        let configuration: Configuration
        let tone: Tone
        let isSelected: Bool
        let compact: Bool
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovered = false

        var body: some View {
            let pressed = configuration.isPressed

            configuration.label
                .font(.system(size: compact ? 11 : 12, weight: isSelected ? .semibold : .medium))
                .foregroundColor(foregroundColor)
                .padding(.horizontal, compact ? 9 : 12)
                .frame(height: compact ? 22 : 26)
                .background(backgroundView(pressed: pressed))
                .scaleEffect(pressed ? 0.97 : 1.0)
                .animation(.spring(response: 0.18, dampingFraction: 0.75), value: pressed)
                .opacity(isEnabled ? 1.0 : 0.45)
                .onHover { isHovered = $0 }
                .contentShape(Capsule())
        }

        private var foregroundColor: Color {
            if isSelected || tone == .accent {
                return Color.white
            }
            if tone == .destructive {
                return Color.red
            }
            return isHovered ? Color.primary : Color.secondary
        }

        @ViewBuilder
        private func backgroundView(pressed: Bool) -> some View {
            if isSelected || tone == .accent {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [LiquidGlass.accent, LiquidGlass.accent.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.75)
                    )
                    .shadow(color: LiquidGlass.accent.opacity(pressed ? 0.2 : 0.4), radius: pressed ? 2 : 5, y: 1)
            } else {
                Capsule(style: .continuous)
                    .fill(
                        isHovered
                            ? Color.primary.opacity(0.12)
                            : Color.primary.opacity(0.06)
                    )
                    .background(
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(
                                isHovered ? Color.white.opacity(0.28) : Color.white.opacity(0.14),
                                lineWidth: 0.5
                            )
                    )
            }
        }
    }
}

// MARK: - Liquid Glass Clip Row View

public struct GlassClipRowView: View {
    public let item: ClipboardItem
    public let isSelected: Bool
    public let quickIndex: Int?
    public let onSelect: () -> Void
    public let onPaste: () -> Void
    public let onTogglePin: () -> Void
    public let onDelete: () -> Void

    @State private var isHovered = false

    private var textColor: Color { isSelected ? .white : .primary }
    private var secondaryTextColor: Color { isSelected ? .white.opacity(0.78) : .secondary }

    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            leadingBadge

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium, design: isCode ? .monospaced : .default))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(metaLine)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(secondaryTextColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isHovered && !isSelected && !item.isSnippet {
                hoverActions
            } else if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? .white : LiquidGlass.accent)
                    .accessibilityLabel("Pinned")
            }

            if let thumb = thumbnailImage {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.18), lineWidth: 0.75)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 3, y: 1)
            } else if case .file(let path) = item.type {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 56)
        .background(
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [LiquidGlass.accent, Color(hex: 0x0071E3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.38), lineWidth: 1)
                        )
                        .shadow(color: LiquidGlass.accent.opacity(0.4), radius: 8, x: 0, y: 3)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.75)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.025))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
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

    @ViewBuilder
    private var leadingBadge: some View {
        ZStack {
            if let idx = quickIndex {
                Text("⌘\(idx)")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(textColor)
                    .frame(width: 28, height: 20)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? Color.white.opacity(0.22) : Color.primary.opacity(0.06))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.15), lineWidth: 0.5)
                    )
            } else {
                Image(systemName: item.type.iconName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(secondaryTextColor)
                    .frame(width: 28, height: 20)
            }
        }
        .accessibilityHidden(true)
    }

    private var hoverActions: some View {
        HStack(spacing: 3) {
            Button(action: onTogglePin) {
                Image(systemName: item.isPinned ? "pin.slash" : "pin")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(GlassPillStyle(isSelected: item.isPinned, compact: true))
            .help(item.isPinned ? "Unpin" : "Pin to top")
            .accessibilityLabel(item.isPinned ? "Unpin" : "Pin")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(GlassPillStyle(tone: .destructive, compact: true))
            .help("Delete from history")
            .accessibilityLabel("Delete")
        }
    }

    private var isCode: Bool {
        if case .code = item.type { return true }
        return false
    }

    private var metaLine: String {
        var parts: [String] = [item.kindLabel]
        switch item.type {
        case .text, .code:
            if let lines = item.lineCount, lines > 1 { parts.append("\(lines) lines") }
            else if let chars = item.charCount { parts.append("\(chars) chars") }
            if item.hasRichText { parts.append("Formatted") }
        case .snippet:
            if let keyword = item.keyword { parts.append(keyword.uppercased()) }
            if let lines = item.lineCount, lines > 1 { parts.append("\(lines) lines") }
            return parts.joined(separator: " · ")
        case .image, .screenshot:
            if let w = item.imageWidth, let h = item.imageHeight { parts.append("\(Int(w))×\(Int(h))") }
        case .file:
            if !item.formattedSize.isEmpty { parts.append(item.formattedSize) }
        }
        parts.append(item.relativeTime)
        if let app = item.sourceAppName, app != "ScreenCapture" { parts.append(app) }
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

// MARK: - Liquid Glass History List

public struct GlassHistoryList: View {
    public let items: [ClipboardItem]
    public let selectedId: UUID?
    public let query: String
    public let category: FilterCategory
    public let showBadges: Bool
    public let reduceMotion: Bool
    public let onSelect: (ClipboardItem) -> Void
    public let onPaste: (ClipboardItem) -> Void
    public let onTogglePin: (ClipboardItem) -> Void
    public let onDelete: (ClipboardItem) -> Void

    public var body: some View {
        ZStack {
            // Optical background blur
            VisualEffectBlur(material: .sidebar, blendingMode: .withinWindow)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.15))

            // Specular rim
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(LiquidGlass.specularRimSubtle, lineWidth: 1)

            if items.isEmpty {
                GlassEmptyState(query: query, category: category)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                GlassClipRowView(
                                    item: item,
                                    isSelected: selectedId == item.id,
                                    quickIndex: showBadges && index < 9 ? index + 1 : nil,
                                    onSelect: { onSelect(item) },
                                    onPaste: { onPaste(item) },
                                    onTogglePin: { onTogglePin(item) },
                                    onDelete: { onDelete(item) }
                                )
                                .id(item.id)
                                .transition(reduceMotion ? .opacity : .asymmetric(
                                    insertion: .scale(scale: 0.96).combined(with: .opacity),
                                    removal: .opacity
                                ))
                            }
                        }
                        .padding(6)
                        .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.8), value: items.map(\.id))
                    }
                    .onChange(of: selectedId) { newId in
                        guard let newId else { return }
                        proxy.scrollTo(newId)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Liquid Glass Empty State

public struct GlassEmptyState: View {
    public let query: String
    public let category: FilterCategory

    public var body: some View {
        VStack(spacing: 10) {
            Spacer()
            if query.isEmpty && category == .snippets {
                Image(systemName: "bookmark")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(LiquidGlass.accent)
                    .padding(.bottom, 2)
                Text("No Snippets Yet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Select any text clip and press ⌘S to save it as a snippet,\nor create one in Settings › Snippets.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Open Snippet Settings") {
                    OverlayPanelManager.shared.hide()
                    SettingsWindowController.shared.show(tab: .snippets)
                }
                .buttonStyle(GlassPillStyle(tone: .accent, compact: true))
                .padding(.top, 4)
            } else if query.isEmpty {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(LiquidGlass.accent)
                    .padding(.bottom, 2)
                Text("Clipboard is Empty")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Copy text, code, images, or files to start collecting.\nNew screenshots appear automatically.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Text("\(SettingsStore.shared.hotkeyDisplay) opens ClipBoardUltra anywhere")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.8))
                    .padding(.top, 4)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 2)
                Text("No Clips Match “\(query)”")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text("Try different keywords, another category, or press esc to clear.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Liquid Glass Key Legend

public struct GlassKeyLegend: View {
    public let keys: String
    public let label: String

    public init(keys: String, label: String) {
        self.keys = keys
        self.label = label
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text(keys)
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.horizontal, 5)
                .frame(minWidth: 18, minHeight: 18)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                        )
                )
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

