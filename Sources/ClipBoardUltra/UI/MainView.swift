import SwiftUI
import Cocoa

public struct MainView: View {
    @ObservedObject var clipboardManager = ClipboardManager.shared
    @ObservedObject var pasteEngine = PasteEngine.shared
    @ObservedObject var settings = SettingsStore.shared

    public var onPasteItem: (ClipboardItem) -> Void
    public var onCopyItem: (ClipboardItem) -> Void
    public var onClose: () -> Void

    @FocusState private var isSearchFocused: Bool
    @State private var confirmingClear = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isLiquidGlass: Bool { settings.appTheme == .liquidGlass }

    public var body: some View {
        VStack(spacing: 0) {
            if !pasteEngine.isAccessibilityGranted {
                permissionStrip
            }

            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            categoryKeys
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            HStack(alignment: .top, spacing: 14) {
                if isLiquidGlass {
                    GlassHistoryList(
                        items: clipboardManager.filteredItems,
                        selectedId: clipboardManager.selectedItemId,
                        query: clipboardManager.searchQuery,
                        category: clipboardManager.selectedCategory,
                        showBadges: settings.showQuickIndexBadges,
                        reduceMotion: reduceMotion,
                        onSelect: { clipboardManager.selectItem(id: $0.id) },
                        onPaste: onPasteItem,
                        onTogglePin: { clipboardManager.togglePin(for: $0) },
                        onDelete: { clipboardManager.deleteItem($0) }
                    )
                    .frame(width: 408)
                } else {
                    PaperRoll(
                        items: clipboardManager.filteredItems,
                        selectedId: clipboardManager.selectedItemId,
                        query: clipboardManager.searchQuery,
                        category: clipboardManager.selectedCategory,
                        showBadges: settings.showQuickIndexBadges,
                        reduceMotion: reduceMotion,
                        onSelect: { clipboardManager.selectItem(id: $0.id) },
                        onPaste: onPasteItem,
                        onTogglePin: { clipboardManager.togglePin(for: $0) },
                        onDelete: { clipboardManager.deleteItem($0) }
                    )
                    .frame(width: 408)
                }

                DetailPreviewView(
                    item: clipboardManager.getSelectedItem(),
                    onPaste: { if let it = clipboardManager.getSelectedItem() { onPasteItem(it) } },
                    onCopy: { if let it = clipboardManager.getSelectedItem() { onCopyItem(it) } },
                    onTogglePin: { if let it = clipboardManager.getSelectedItem() { clipboardManager.togglePin(for: it) } },
                    onDelete: { if let it = clipboardManager.getSelectedItem() { clipboardManager.deleteItem(it) } }
                )
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity)

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
        }
        .frame(width: OverlayPanelManager.panelSize.width, height: OverlayPanelManager.panelSize.height)
        .background(chassis)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear(perform: focusSearch)
        .onReceive(NotificationCenter.default.publisher(for: .overlayDidShow)) { _ in
            confirmingClear = false
            focusSearch()
        }
    }

    private func focusSearch() {
        // Next runloop pass: the panel must be key before SwiftUI can move focus.
        DispatchQueue.main.async { isSearchFocused = true }
    }

    // MARK: Chassis

    @ViewBuilder
    private var chassis: some View {
        if isLiquidGlass {
            ZStack {
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.28))

                VStack {
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.02), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 38)
                    .clipShape(TopRoundedCorners(radius: 18))
                    Spacer()
                }

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(LiquidGlass.specularRim, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.35), radius: 28, x: 0, y: 14)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.chassisTop, Theme.chassis, Color(hex: 0x1A1C1F)],
                                         startPoint: .top, endPoint: .bottom))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.02)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
            }
        }
    }

    // MARK: Header: mark, search slot, readout

    private var header: some View {
        HStack(spacing: 12) {
            LogoMark(size: 24)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: isLiquidGlass ? 13 : 12.5, weight: .semibold))
                    .foregroundColor(isLiquidGlass ? .secondary : Theme.boneDim)

                TextField("Search clips, code, files, screenshots", text: $clipboardManager.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(isLiquidGlass ? .primary : Theme.bone)
                    .focused($isSearchFocused)
                    .accessibilityLabel("Search clipboard history")

                if !clipboardManager.searchQuery.isEmpty {
                    Button { clipboardManager.searchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(isLiquidGlass ? .secondary : Theme.boneDim)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(searchFieldBackground)

            readout
        }
    }

    @ViewBuilder
    private var searchFieldBackground: some View {
        if isLiquidGlass {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(LiquidGlass.specularRimSubtle, lineWidth: 0.75)
                )
        } else {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.chassisLow)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.black.opacity(0.6), lineWidth: 1)
                )
                .overlay(
                    // Lower lip catches light: reads as a recessed slot.
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .trim(from: 0.52, to: 0.98)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private var readout: some View {
        let count = clipboardManager.filteredItems.count
        let paused = settings.isPaused

        if isLiquidGlass {
            HStack(spacing: 6) {
                Circle()
                    .fill(paused ? Color.orange : LiquidGlass.accent)
                    .frame(width: 7, height: 7)
                    .shadow(color: (paused ? Color.orange : LiquidGlass.accent).opacity(0.6), radius: 3)
                Text("\(min(count, 999))")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                VStack(alignment: .leading, spacing: 0) {
                    Text(clipboardManager.selectedCategory == .snippets ? "SNIPS" : (count == 1 ? "CLIP" : "CLIPS"))
                    if paused { Text("PAUSED").foregroundColor(.orange) }
                }
                .font(.system(size: 8.5, weight: .bold))
                .foregroundColor(.secondary)
            }
            .help(paused ? (settings.pauseDescription ?? "Recording paused") : "")
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(LiquidGlass.specularRimSubtle, lineWidth: 0.75)
                    )
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(paused ? "\(count) clips shown, recording paused" : "\(count) clips shown")
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(String(format: "%03d", min(count, 999)))
                    .font(Theme.mono(17, .semibold))
                    .foregroundColor(Theme.amber)
                    .shadow(color: Theme.amber.opacity(0.45), radius: 3)
                VStack(alignment: .leading, spacing: 0) {
                    Text(clipboardManager.selectedCategory == .snippets ? "SNIPS" : (count == 1 ? "CLIP" : "CLIPS"))
                    if paused { Text("PAUSED").foregroundColor(Theme.orange) }
                }
                .font(Theme.mono(9, .semibold))
                .foregroundColor(Theme.amber.opacity(0.75))
            }
            .help(paused ? (settings.pauseDescription ?? "Recording paused") : "")
            .padding(.horizontal, 11)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.screen)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.black.opacity(0.7), lineWidth: 1))
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(paused ? "\(count) clips shown, recording paused" : "\(count) clips shown")
        }
    }

    // MARK: Category keys

    private var categoryKeys: some View {
        HStack(spacing: 7) {
            ForEach(FilterCategory.allCases) { category in
                let active = clipboardManager.selectedCategory == category
                if isLiquidGlass {
                    Button {
                        clipboardManager.selectedCategory = category
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: category.icon).font(.system(size: 9.5, weight: .semibold))
                            Text(category.rawValue)
                        }
                    }
                    .buttonStyle(GlassPillStyle(isSelected: active, compact: true))
                    .accessibilityAddTraits(active ? .isSelected : [])
                } else {
                    Button {
                        clipboardManager.selectedCategory = category
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: category.icon).font(.system(size: 9.5, weight: .semibold))
                            Text(category.rawValue)
                        }
                    }
                    .buttonStyle(KeycapStyle(tone: .graphite, lit: active, compact: true))
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Permission strip

    private var permissionStrip: some View {
        HStack(spacing: 10) {
            Circle().fill(isLiquidGlass ? Color.orange : Theme.orange).frame(width: 7, height: 7)
                .shadow(color: (isLiquidGlass ? Color.orange : Theme.orange).opacity(0.8), radius: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text("AUTO-PASTE IS OFF")
                    .font(isLiquidGlass ? .system(size: 10.5, weight: .bold, design: .rounded) : Theme.mono(10.5, .bold))
                    .foregroundColor(isLiquidGlass ? .orange : Theme.amber)
                Text("Turn on ClipBoardUltra in Privacy & Security › Accessibility. Until then, Enter copies and you press ⌘V.")
                    .font(.system(size: 11))
                    .foregroundColor(isLiquidGlass ? .secondary : Theme.bone.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            Spacer(minLength: 8)
            if isLiquidGlass {
                Button("Grant Access") { pasteEngine.requestAccessibilityPermission() }
                    .buttonStyle(GlassPillStyle(tone: .accent, compact: true))
            } else {
                Button("Grant Access") { pasteEngine.requestAccessibilityPermission() }
                    .buttonStyle(KeycapStyle(tone: .orange, compact: true))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(
            ZStack {
                if isLiquidGlass {
                    Rectangle().fill(.ultraThinMaterial)
                } else {
                    Theme.screen
                }
            }
        )
        .overlay(Rectangle().fill(Color.black.opacity(0.6)).frame(height: 1), alignment: .bottom)
    }

    // MARK: Footer cheat sheet

    private var footer: some View {
        HStack(spacing: 12) {
            if isLiquidGlass {
                GlassKeyLegend(keys: "↩", label: settings.returnAction == .paste ? "Paste" : "Copy")
                GlassKeyLegend(keys: "⇧↩", label: settings.pastePlainTextByDefault ? "Formatted" : "Plain")
                GlassKeyLegend(keys: "⌘1–9", label: "Quick")
                GlassKeyLegend(keys: "⇥", label: "Filter")
                GlassKeyLegend(keys: "⌘P", label: "Pin")
                GlassKeyLegend(keys: "⌘S", label: "Snippet")
                GlassKeyLegend(keys: "⌘⌫", label: "Delete")
            } else {
                KeyLegend(keys: "↩", label: settings.returnAction == .paste ? "Paste" : "Copy")
                KeyLegend(keys: "⇧↩", label: settings.pastePlainTextByDefault ? "Formatted" : "Plain text")
                KeyLegend(keys: "⌘1–9", label: "Quick")
                KeyLegend(keys: "⇥", label: "Filter")
                KeyLegend(keys: "⌘P", label: "Pin")
                KeyLegend(keys: "⌘S", label: "Snippet")
                KeyLegend(keys: "⌘⌫", label: "Delete")
            }

            Spacer(minLength: 8)

            if isLiquidGlass {
                Button {
                    if confirmingClear {
                        clipboardManager.clearAllUnpinned()
                        confirmingClear = false
                    } else {
                        confirmingClear = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { confirmingClear = false }
                    }
                } label: {
                    Text(confirmingClear ? "Clear unpinned?" : "Clear")
                }
                .buttonStyle(GlassPillStyle(tone: confirmingClear ? .destructive : .regular, compact: true))
                .help("Remove every clip that isn't pinned")

                Button {
                    onClose()
                    SettingsWindowController.shared.show()
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(GlassPillStyle(compact: true))
                .help("Settings (⌘,)")
                .accessibilityLabel("Settings")
            } else {
                Button {
                    if confirmingClear {
                        clipboardManager.clearAllUnpinned()
                        confirmingClear = false
                    } else {
                        confirmingClear = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { confirmingClear = false }
                    }
                } label: {
                    Text(confirmingClear ? "Clear unpinned?" : "Clear")
                }
                .buttonStyle(KeycapStyle(tone: confirmingClear ? .orange : .graphite, compact: true))
                .help("Remove every clip that isn't pinned")

                Button {
                    onClose()
                    SettingsWindowController.shared.show()
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(KeycapStyle(tone: .graphite, compact: true))
                .help("Settings (⌘,)")
                .accessibilityLabel("Settings")
            }
        }
    }
}

// MARK: - Paper roll

/// History list drawn as a roll of thermal paper fed from a slot; newest slip at the top.
struct PaperRoll: View {
    let items: [ClipboardItem]
    let selectedId: UUID?
    let query: String
    let category: FilterCategory
    let showBadges: Bool
    let reduceMotion: Bool
    let onSelect: (ClipboardItem) -> Void
    let onPaste: (ClipboardItem) -> Void
    let onTogglePin: (ClipboardItem) -> Void
    let onDelete: (ClipboardItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Printer slot the paper feeds out of
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(hex: 0x0B0C0D))
                .frame(height: 8)
                .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1), alignment: .bottom)
                .zIndex(1)

            ZStack(alignment: .top) {
                Theme.paper

                if items.isEmpty {
                    emptyState
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                    ClipRowView(
                                        item: item,
                                        isSelected: selectedId == item.id,
                                        quickIndex: showBadges && index < 9 ? index + 1 : nil,
                                        onSelect: { onSelect(item) },
                                        onPaste: { onPaste(item) },
                                        onTogglePin: { onTogglePin(item) },
                                        onDelete: { onDelete(item) }
                                    )
                                    .id(item.id)
                                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                                    Perforation().padding(.horizontal, 10)
                                }
                            }
                            .padding(.top, 4)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: items.map(\.id))
                        }
                        .onChange(of: selectedId) { newId in
                            guard let newId else { return }
                            proxy.scrollTo(newId)
                        }
                    }
                }

                // Shadow cast by the slot lip onto the paper
                LinearGradient(colors: [Color.black.opacity(0.22), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 10)
                    .allowsHitTesting(false)
            }
            .clipShape(UnevenRoundedCorners(bottom: 6))
            .padding(.horizontal, 5)
        }
        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            if query.isEmpty && category == .snippets {
                Text("No snippets yet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.ink)
                Text("Select any text clip and press ⌘S to keep it as a snippet,\nor add one in Settings › Snippets.")
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.inkFaded)
                    .multilineTextAlignment(.center)
                Button("Open Snippet Settings") {
                    OverlayPanelManager.shared.hide()
                    SettingsWindowController.shared.show(tab: .snippets)
                }
                .buttonStyle(KeycapStyle(tone: .bone, compact: true))
                .padding(.top, 6)
            } else if query.isEmpty {
                Text("Nothing on the roll yet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.ink)
                Text("Copy text, code, images or files and each one prints here.\nNew screenshots show up on their own.")
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.inkFaded)
                    .multilineTextAlignment(.center)
                Text("\(SettingsStore.shared.hotkeyDisplay) opens this from any app")
                    .font(Theme.mono(10.5, .medium))
                    .foregroundColor(Theme.inkFaded)
                    .padding(.top, 6)
            } else {
                Text("No clips match “\(query)”")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                Text("Try fewer letters, another category, or press esc to clear.")
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.inkFaded)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

/// Square top (hidden under the slot), rounded bottom — macOS 13 compatible.
struct UnevenRoundedCorners: Shape {
    var bottom: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - bottom, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bottom), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
