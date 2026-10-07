import Cocoa
import SwiftUI
import Carbon
import UniformTypeIdentifiers
import Combine

// MARK: - Window

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case history = "History"
    case paste = "Paste"
    case privacy = "Privacy"
    case snippets = "Snippets"
    case dropShelf = "Drop Shelf"
    case about = "About"

    public var id: String { rawValue }
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .history: return "clock.arrow.circlepath"
        case .paste: return "doc.on.clipboard"
        case .privacy: return "hand.raised"
        case .snippets: return "bookmark"
        case .dropShelf: return "tray.and.arrow.down"
        case .about: return "info.circle"
        }
    }
}

/// Shared navigation state so other parts of the app can open a specific tab/snippet.
final class SettingsNavigation: ObservableObject {
    @Published var tab: SettingsTab = .general
    @Published var selectedSnippetId: UUID?
}

public final class SettingsWindowController: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowController()
    private var window: NSWindow?
    let navigation = SettingsNavigation()
    private var themeCancellable: AnyCancellable?

    public func show(tab: SettingsTab? = nil, selectSnippet: UUID? = nil) {
        if let tab { navigation.tab = tab }
        if let selectSnippet { navigation.selectedSnippetId = selectSnippet }

        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 820, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
            w.title = "ClipBoardUltra Settings"
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.contentView = NSHostingView(rootView: SettingsView(navigation: navigation))
            w.center()
            window = w

            updateAppearance()

            themeCancellable = SettingsStore.shared.$appTheme
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.updateAppearance()
                }
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.orderFrontRegardless()
        window?.makeKeyAndOrderFront(nil)
    }

    public func updateAppearance() {
        guard let window else { return }
        switch SettingsStore.shared.appTheme {
        case .tactileDesk:
            window.appearance = NSAppearance(named: .darkAqua)
            window.backgroundColor = NSColor(Theme.chassis)
        case .liquidGlass:
            window.appearance = nil
            window.backgroundColor = .clear
        }
    }
}

// MARK: - Root view

struct SettingsView: View {
    @ObservedObject var navigation: SettingsNavigation
    @ObservedObject private var settings = SettingsStore.shared

    private var isLiquidGlass: Bool { settings.appTheme == .liquidGlass }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                LogoMark(size: 22)
                Text("Settings")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isLiquidGlass ? .primary : Theme.bone)
                Spacer(minLength: 6)
                HStack(spacing: 4) {
                    ForEach(SettingsTab.allCases) { tab in
                        if isLiquidGlass {
                            Button {
                                navigation.tab = tab
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: tab.icon).font(.system(size: 10, weight: .semibold))
                                    Text(tab.rawValue).font(.system(size: 11, weight: .medium))
                                }
                            }
                            .buttonStyle(GlassPillStyle(isSelected: navigation.tab == tab, compact: true))
                            .fixedSize(horizontal: true, vertical: false)
                            .accessibilityAddTraits(navigation.tab == tab ? .isSelected : [])
                        } else {
                            Button {
                                navigation.tab = tab
                            } label: {
                                HStack(spacing: 3.5) {
                                    Image(systemName: tab.icon).font(.system(size: 9, weight: .semibold))
                                    Text(tab.rawValue).font(Theme.mono(10, .medium))
                                }
                            }
                            .buttonStyle(KeycapStyle(tone: .graphite, lit: navigation.tab == tab, compact: true))
                            .fixedSize(horizontal: true, vertical: false)
                            .accessibilityAddTraits(navigation.tab == tab ? .isSelected : [])
                        }
                    }
                }
            }
            .padding(.leading, 72)   // clear the traffic-light buttons
            .padding(.trailing, 16)
            .padding(.top, 14)
            .padding(.bottom, 14)

            Rectangle()
                .fill(isLiquidGlass ? Color.primary.opacity(0.08) : Color.black.opacity(0.5))
                .frame(height: 1)

            Group {
                switch navigation.tab {
                case .general: GeneralPane()
                case .history: HistoryPane()
                case .paste: PastePane()
                case .privacy: PrivacyPane()
                case .snippets: SnippetsPane(navigation: navigation)
                case .dropShelf: DropShelfPane()
                case .about: AboutPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 760, minHeight: 560)
        .background(settingsBackground)
        .tint(isLiquidGlass ? LiquidGlass.accent : Theme.orange)
    }

    @ViewBuilder
    private var settingsBackground: some View {
        if isLiquidGlass {
            ZStack {
                VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
                Color(nsColor: .windowBackgroundColor).opacity(0.35)
            }
            .ignoresSafeArea()
        } else {
            LinearGradient(colors: [Theme.chassisTop, Theme.chassis], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Building blocks

/// A titled group of rows on a recessed panel.
struct SettingsSection<Content: View>: View {
    let title: String
    var footnote: String?
    @ViewBuilder var content: Content
    @ObservedObject private var settings = SettingsStore.shared
    private var isLiquidGlass: Bool { settings.appTheme == .liquidGlass }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(isLiquidGlass ? .system(size: 10, weight: .bold, design: .rounded) : Theme.mono(10, .semibold))
                .foregroundColor(isLiquidGlass ? LiquidGlass.accent : Theme.amber.opacity(0.85))
                .padding(.leading, 2)
            VStack(spacing: 0) { content }
                .background(
                    Group {
                        if isLiquidGlass {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.primary.opacity(0.035))
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.75)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Theme.screen)
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.black.opacity(0.7), lineWidth: 1))
                        }
                    }
                )
            if let footnote {
                Text(footnote)
                    .font(.system(size: 11))
                    .foregroundColor(isLiquidGlass ? .secondary : Theme.boneDim)
                    .padding(.leading, 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Label + optional explanation on the left, control on the right.
struct SettingsRow<Control: View>: View {
    let title: String
    var detail: String?
    var showDivider = true
    @ViewBuilder var control: Control
    @ObservedObject private var settings = SettingsStore.shared
    private var isLiquidGlass: Bool { settings.appTheme == .liquidGlass }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: isLiquidGlass ? .medium : .regular))
                        .foregroundColor(isLiquidGlass ? .primary : Theme.bone)
                    if let detail {
                        Text(detail)
                            .font(.system(size: 11))
                            .foregroundColor(isLiquidGlass ? .secondary : Theme.boneDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 12)
                control
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            if showDivider {
                Rectangle()
                    .fill(isLiquidGlass ? Color.primary.opacity(0.08) : Theme.hairline)
                    .frame(height: 1)
                    .padding(.leading, 14)
            }
        }
    }
}

// MARK: - Theme Preview Card

struct ThemePreviewCard: View {
    let theme: SettingsStore.AppTheme
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                // Mini preview container
                ZStack {
                    if theme == .tactileDesk {
                        tactileDeskMiniPreview
                    } else {
                        liquidGlassMiniPreview
                    }
                }
                .frame(height: 78)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isSelected
                                ? (theme == .tactileDesk ? Theme.orange : LiquidGlass.accent)
                                : (isHovered ? Color.white.opacity(0.3) : Color.white.opacity(0.12)),
                            lineWidth: isSelected ? 2 : 1
                        )
                )

                HStack(spacing: 8) {
                    // Radio indicator
                    ZStack {
                        Circle()
                            .strokeBorder(
                                isSelected
                                    ? (theme == .tactileDesk ? Theme.orange : LiquidGlass.accent)
                                    : Color.secondary.opacity(0.5),
                                lineWidth: 1.5
                            )
                            .frame(width: 15, height: 15)

                        if isSelected {
                            Circle()
                                .fill(theme == .tactileDesk ? Theme.orange : LiquidGlass.accent)
                                .frame(width: 7, height: 7)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(theme.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(theme == .tactileDesk ? "Physical desk instrument · thermal roll & tactile keys" : "Apple native material · translucent optical glass & specular rim")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? (theme == .tactileDesk ? Color.white.opacity(0.06) : LiquidGlass.accent.opacity(0.08)) : Color.primary.opacity(0.02))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .frame(maxWidth: .infinity)
    }

    private var tactileDeskMiniPreview: some View {
        ZStack {
            LinearGradient(colors: [Theme.chassisTop, Theme.chassis], startPoint: .top, endPoint: .bottom)

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Circle().fill(Theme.amber).frame(width: 5, height: 5).shadow(color: Theme.amber, radius: 2)
                    RoundedRectangle(cornerRadius: 3).fill(Theme.screen).frame(height: 12)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)

                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.paper)
                    .overlay(
                        VStack(alignment: .leading, spacing: 3) {
                            RoundedRectangle(cornerRadius: 1).fill(Theme.ink).frame(width: 48, height: 4)
                            RoundedRectangle(cornerRadius: 1).fill(Theme.inkFaded).frame(width: 32, height: 3)
                        }
                        .padding(.horizontal, 6),
                        alignment: .leading
                    )
                    .frame(height: 28)
                    .padding(.horizontal, 8)

                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x2E3135)).frame(width: 20, height: 10)
                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x2E3135)).frame(width: 20, height: 10)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            }
        }
    }

    private var liquidGlassMiniPreview: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.25), Color.purple.opacity(0.18), Color.cyan.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(LiquidGlass.specularRimSubtle, lineWidth: 0.75)
                )
                .padding(6)

            VStack(spacing: 5) {
                HStack(spacing: 6) {
                    Circle().fill(LiquidGlass.accent).frame(width: 5, height: 5).shadow(color: LiquidGlass.accent, radius: 2)
                    Capsule().fill(.thinMaterial).frame(height: 10)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)

                HStack(spacing: 4) {
                    Capsule().fill(LiquidGlass.accent).frame(width: 24, height: 8)
                    Capsule().fill(Color.primary.opacity(0.08)).frame(width: 20, height: 8)
                    Spacer()
                }
                .padding(.horizontal, 10)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                    .frame(height: 18)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
            }
        }
    }
}

/// Lets offscreen snapshot tools lay panes out without a ScrollView (ImageRenderer can't draw one).
struct StaticLayoutKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var staticLayout: Bool {
        get { self[StaticLayoutKey.self] }
        set { self[StaticLayoutKey.self] = newValue }
    }
}

struct PaneScroll<Content: View>: View {
    @Environment(\.staticLayout) private var staticLayout
    @ViewBuilder var content: Content

    var body: some View {
        if staticLayout {
            inner.frame(maxHeight: .infinity, alignment: .top)
        } else {
            ScrollView { inner }
        }
    }

    private var inner: some View {
        VStack(alignment: .leading, spacing: 22) { content }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
    }
}

private extension View {
    func settingsPicker(width: CGFloat = 220) -> some View {
        self.pickerStyle(.menu).labelsHidden().frame(width: width)
    }
    func settingsSwitch() -> some View {
        self.toggleStyle(.switch).labelsHidden().controlSize(.small)
    }
}

// MARK: - General

struct GeneralPane: View {
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var paste = PasteEngine.shared
    @State private var launchAtLogin = LoginItemManager.shared.isEnabled

    var body: some View {
        PaneScroll {
            SettingsSection(title: "Theme & Appearance", footnote: "Choose between the physical desk instrument or Apple's native optical glass material.") {
                HStack(spacing: 12) {
                    ThemePreviewCard(
                        theme: .tactileDesk,
                        isSelected: settings.appTheme == .tactileDesk,
                        onSelect: { settings.appTheme = .tactileDesk }
                    )

                    ThemePreviewCard(
                        theme: .liquidGlass,
                        isSelected: settings.appTheme == .liquidGlass,
                        onSelect: { settings.appTheme = .liquidGlass }
                    )
                }
                .padding(12)
            }

            SettingsSection(title: "Shortcut") {
                SettingsRow(title: "Open clipboard history",
                            detail: "Works in every app. Click the key, then press the new combination.",
                            showDivider: false) {
                    ShortcutRecorder()
                }
            }

            SettingsSection(title: "Startup & placement") {
                SettingsRow(title: "Open at login") {
                    Toggle("", isOn: $launchAtLogin)
                        .settingsSwitch()
                        .onChange(of: launchAtLogin) { on in
                            if !LoginItemManager.shared.setEnabled(on) {
                                launchAtLogin = LoginItemManager.shared.isEnabled
                            }
                            UserDefaults.standard.set(true, forKey: "didConfigureLoginItem")
                        }
                }
                SettingsRow(title: "Open the overlay on") {
                    Picker("", selection: $settings.overlayPlacement) {
                        ForEach(SettingsStore.OverlayPlacement.allCases) { Text($0.label).tag($0) }
                    }
                    .settingsPicker(width: 250)
                }
                SettingsRow(title: "Show icon in the menu bar",
                            detail: "When hidden, open ClipBoardUltra from Finder or Spotlight to get back to Settings.",
                            showDivider: false) {
                    Toggle("", isOn: $settings.showMenuBarIcon).settingsSwitch()
                }
            }

            SettingsSection(title: "Auto-paste") {
                SettingsRow(title: paste.isAccessibilityGranted ? "Auto-paste is on" : "Auto-paste is off",
                            detail: paste.isAccessibilityGranted
                                ? "ClipBoardUltra can type ⌘V into the app you were using."
                                : "Allow ClipBoardUltra in Privacy & Security › Accessibility. Until then, Return copies and you press ⌘V.",
                            showDivider: false) {
                    if paste.isAccessibilityGranted {
                        HStack(spacing: 6) {
                            Circle().fill(Theme.amber).frame(width: 7, height: 7)
                            Text("ON").font(Theme.mono(11, .bold)).foregroundColor(Theme.amber)
                        }
                    } else {
                        Button("Grant Access") { paste.requestAccessibilityPermission() }
                            .buttonStyle(KeycapStyle(tone: .orange, compact: true))
                    }
                }
            }

            Text("ClipBoardUltra \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") · history stays on this Mac")
                .font(Theme.mono(10))
                .foregroundColor(Theme.boneDim.opacity(0.8))
        }
        .onAppear { launchAtLogin = LoginItemManager.shared.isEnabled }
    }
}

/// Click, then press a key combination. Esc cancels.
struct ShortcutRecorder: View {
    @ObservedObject private var settings = SettingsStore.shared
    @State private var recording = false
    @State private var monitor: Any?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 8) {
                Button {
                    recording ? stop(restore: true) : start()
                } label: {
                    Text(recording ? "Press keys…  esc cancels" : settings.hotkeyDisplay)
                        .font(recording ? .system(size: 11.5, weight: .semibold) : Theme.mono(13, .bold))
                        .frame(minWidth: 90)
                }
                .buttonStyle(KeycapStyle(tone: recording ? .orange : .bone))
                .accessibilityLabel("Shortcut \(settings.hotkeyDisplay). Click to change.")

                if settings.hotkeyKeyCode != UInt32(kVK_ANSI_V) || settings.hotkeyModifiers != UInt32(cmdKey | optionKey) {
                    Button("Reset") { apply(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | optionKey)) }
                        .buttonStyle(KeycapStyle(tone: .graphite, compact: true))
                }
            }
            if let message {
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.orange)
            }
        }
        .onDisappear { if recording { stop(restore: true) } }
    }

    private func start() {
        message = nil
        recording = true
        HotkeyManager.shared.unregisterHotkey()   // so the current combo can be re-recorded
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stop(restore: true)
                return nil
            }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let mods = HotkeyFormatter.carbonModifiers(from: flags)
            let needsModifier = mods & UInt32(cmdKey | optionKey | controlKey) == 0
            let isFunctionKey = (kVK_F1...kVK_F12).contains(Int(event.keyCode))
            if needsModifier && !isFunctionKey {
                message = "Include ⌘, ⌥ or ⌃ in the shortcut."
                NSSound.beep()
                return nil
            }
            if mods == UInt32(cmdKey) && !isFunctionKey {
                message = "⌘ + a key belongs to apps (⌘V, ⌘C…). Add ⌥ or ⌃."
                NSSound.beep()
                return nil
            }
            apply(keyCode: UInt32(event.keyCode), modifiers: mods)
            stop(restore: false)
            return nil
        }
    }

    private func apply(keyCode: UInt32, modifiers: UInt32) {
        let status = HotkeyManager.shared.register(keyCode: keyCode, modifiers: modifiers)
        if status == noErr {
            settings.hotkeyKeyCode = keyCode
            settings.hotkeyModifiers = modifiers
            message = nil
        } else {
            message = "\(HotkeyFormatter.string(keyCode: keyCode, modifiers: modifiers)) is already used by another app."
            HotkeyManager.shared.registerDefaultHotkey()
        }
    }

    private func stop(restore: Bool) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        if restore { HotkeyManager.shared.registerDefaultHotkey() }
    }
}

// MARK: - History

struct HistoryPane: View {
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var clipboard = ClipboardManager.shared
    @State private var diskUsage: Int64 = 0
    @State private var confirmClear = false

    var body: some View {
        PaneScroll {
            SettingsSection(title: "Limits", footnote: "Pinned clips are never removed by these limits.") {
                SettingsRow(title: "Keep up to") {
                    Picker("", selection: $settings.maxItems) {
                        ForEach(SettingsStore.historyLimits, id: \.self) { Text("\($0) clips").tag($0) }
                    }
                    .settingsPicker(width: 140)
                }
                SettingsRow(title: "Keep clips for", showDivider: false) {
                    Picker("", selection: $settings.retention) {
                        ForEach(SettingsStore.Retention.allCases) { Text($0.label).tag($0) }
                    }
                    .settingsPicker(width: 140)
                }
            }

            SettingsSection(title: "What to save") {
                SettingsRow(title: "Text and code") { Toggle("", isOn: $settings.captureText).settingsSwitch() }
                SettingsRow(title: "Images") { Toggle("", isOn: $settings.captureImages).settingsSwitch() }
                SettingsRow(title: "Skip images larger than") {
                    Picker("", selection: $settings.maxImageMB) {
                        ForEach(SettingsStore.imageLimitsMB, id: \.self) { Text($0 == 0 ? "No limit" : "\($0) MB").tag($0) }
                    }
                    .settingsPicker(width: 140)
                    .disabled(!settings.captureImages)
                }
                SettingsRow(title: "Files copied in Finder") { Toggle("", isOn: $settings.captureFiles).settingsSwitch() }
                SettingsRow(title: "New screenshots", showDivider: false) {
                    Toggle("", isOn: $settings.captureScreenshots).settingsSwitch()
                }
            }

            SettingsSection(title: "Screenshot folder") {
                SettingsRow(title: settings.customScreenshotFolder == nil ? "Automatic" : "Custom folder",
                            detail: (ScreenshotManager.shared.screenshotDirectoryURL.path as NSString).abbreviatingWithTildeInPath,
                            showDivider: false) {
                    HStack(spacing: 6) {
                        if settings.customScreenshotFolder != nil {
                            Button("Use Automatic") { settings.customScreenshotFolder = nil }
                                .buttonStyle(KeycapStyle(tone: .graphite, compact: true))
                        }
                        Button("Choose…", action: chooseFolder)
                            .buttonStyle(KeycapStyle(tone: .graphite, compact: true))
                    }
                }
            }

            SettingsSection(title: "Storage") {
                SettingsRow(title: "\(clipboard.items.count) clips · \(ByteCountFormatter.string(fromByteCount: diskUsage, countStyle: .file)) on disk",
                            detail: "Stored in ~/Library/Application Support/ClipBoardUltra",
                            showDivider: false) {
                    Button(confirmClear ? "Clear unpinned?" : "Clear History") {
                        if confirmClear {
                            clipboard.clearAllUnpinned()
                            confirmClear = false
                            refreshUsage()
                        } else {
                            confirmClear = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { confirmClear = false }
                        }
                    }
                    .buttonStyle(KeycapStyle(tone: confirmClear ? .orange : .graphite, compact: true))
                }
            }
        }
        .onAppear(perform: refreshUsage)
        .onChange(of: clipboard.items.count) { _ in refreshUsage() }
    }

    private func refreshUsage() {
        DispatchQueue.global(qos: .utility).async {
            let bytes = StorageManager.shared.diskUsageBytes()
            DispatchQueue.main.async { diskUsage = bytes }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Use Folder"
        panel.directoryURL = ScreenshotManager.shared.screenshotDirectoryURL
        if panel.runModal() == .OK, let url = panel.url {
            settings.customScreenshotFolder = url.path
        }
    }
}

// MARK: - Paste

struct PastePane: View {
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        PaneScroll {
            SettingsSection(title: "Return key") {
                SettingsRow(title: "When I press Return",
                            detail: "⌘↩ always does the other one.",
                            showDivider: false) {
                    Picker("", selection: $settings.returnAction) {
                        ForEach(SettingsStore.ReturnAction.allCases) { Text($0.label).tag($0) }
                    }
                    .settingsPicker(width: 230)
                }
            }

            SettingsSection(title: "Formatting") {
                SettingsRow(title: "Paste as plain text by default",
                            detail: settings.pastePlainTextByDefault
                                ? "Fonts, colors and links are removed. ⇧↩ keeps the original formatting."
                                : "Text keeps its original formatting when it has any. ⇧↩ pastes plain text.") {
                    Toggle("", isOn: $settings.pastePlainTextByDefault).settingsSwitch()
                }
                SettingsRow(title: "Trim spaces and blank lines",
                            detail: "Removes whitespace at the start and end of text clips when pasting.",
                            showDivider: false) {
                    Toggle("", isOn: $settings.trimWhitespace).settingsSwitch()
                }
            }

            SettingsSection(title: "List") {
                SettingsRow(title: "Move a clip to the top after using it") {
                    Toggle("", isOn: $settings.promoteOnUse).settingsSwitch()
                }
                SettingsRow(title: "Show ⌘1–⌘9 keys on the first nine clips",
                            detail: "The shortcuts work either way.",
                            showDivider: false) {
                    Toggle("", isOn: $settings.showQuickIndexBadges).settingsSwitch()
                }
            }
        }
    }
}

// MARK: - Privacy

struct PrivacyPane: View {
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        PaneScroll {
            SettingsSection(title: "Recording") {
                SettingsRow(title: settings.isPaused ? (settings.pauseDescription ?? "Paused") : "Recording new copies",
                            detail: settings.isPaused ? "Nothing you copy is saved until recording resumes." : "Pause while you handle something sensitive.",
                            showDivider: false) {
                    if settings.isPaused {
                        Button("Resume") { settings.resume() }
                            .buttonStyle(KeycapStyle(tone: .orange, compact: true))
                    } else {
                        HStack(spacing: 6) {
                            Button("5 min") { settings.pause(for: 300) }
                            Button("1 hour") { settings.pause(for: 3600) }
                            Button("Until resumed") { settings.pause(for: nil) }
                        }
                        .buttonStyle(KeycapStyle(tone: .graphite, compact: true))
                    }
                }
            }

            SettingsSection(title: "Sensitive content",
                            footnote: "Copies that password managers mark as secret are always skipped.") {
                SettingsRow(title: "Skip passwords and API keys",
                            detail: "Ignores single words that look random (Tr0ub4dor&3), keys like sk-… or ghp_…, tokens and private keys.",
                            showDivider: false) {
                    Toggle("", isOn: $settings.ignoreSecrets).settingsSwitch()
                }
            }

            SettingsSection(title: "Ignored apps", footnote: "Nothing copied while one of these apps is in front is saved.") {
                if settings.ignoredApps.isEmpty {
                    SettingsRow(title: "No ignored apps", showDivider: false) { EmptyView() }
                }
                ForEach(Array(settings.ignoredApps.enumerated()), id: \.element) { index, bundleID in
                    IgnoredAppRow(bundleID: bundleID, isLast: index == settings.ignoredApps.count - 1) {
                        settings.ignoredApps.removeAll { $0 == bundleID }
                    }
                }
            }

            HStack {
                Spacer()
                Button {
                    addApp()
                } label: {
                    Label("Add App…", systemImage: "plus")
                }
                .buttonStyle(KeycapStyle(tone: .graphite, compact: true))
            }
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.prompt = "Ignore"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier, !settings.ignoredApps.contains(id) {
                settings.ignoredApps.append(id)
            }
        }
    }
}

struct IgnoredAppRow: View {
    let bundleID: String
    let isLast: Bool
    let onRemove: () -> Void

    private var appURL: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) }

    private static let knownNames: [String: String] = [
        "com.1password.1password": "1Password",
        "com.agilebits.onepassword7": "1Password 7",
        "com.bitwarden.desktop": "Bitwarden",
        "com.apple.keychainaccess": "Keychain Access",
        "com.apple.Passwords": "Passwords"
    ]

    private var displayName: String {
        if let url = appURL {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return Self.knownNames[bundleID] ?? bundleID
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let url = appURL {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable().frame(width: 22, height: 22)
                } else {
                    Image(systemName: "app.dashed").frame(width: 22, height: 22).foregroundColor(Theme.boneDim)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(displayName)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.bone)
                    Text(appURL == nil ? "Not installed · \(bundleID)" : bundleID)
                        .font(Theme.mono(10))
                        .foregroundColor(Theme.boneDim)
                }
                Spacer()
                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.boneDim)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("Stop ignoring")
                .accessibilityLabel("Stop ignoring \(bundleID)")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            if !isLast { Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 46) }
        }
    }
}

// MARK: - Snippets

struct SnippetsPane: View {
    @ObservedObject var navigation: SettingsNavigation
    @ObservedObject private var manager = SnippetManager.shared

    var body: some View {
        HStack(spacing: 0) {
            // List
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        if manager.snippets.isEmpty {
                            Text("Your snippets print here")
                                .font(.system(size: 11.5))
                                .foregroundColor(Theme.inkFaded)
                                .padding(.top, 24)
                        }
                        ForEach(manager.sorted) { snippet in
                            let selected = navigation.selectedSnippetId == snippet.id
                            Button {
                                navigation.selectedSnippetId = snippet.id
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(snippet.name.isEmpty ? "Untitled snippet" : snippet.name)
                                        .font(.system(size: 12.5, weight: .medium))
                                        .foregroundColor(selected ? Theme.paper : Theme.ink)
                                        .lineLimit(1)
                                    Text(snippet.keyword.isEmpty ? "\(snippet.useCount)× used" : "\(snippet.keyword) · \(snippet.useCount)× used")
                                        .font(Theme.mono(9.5))
                                        .foregroundColor(selected ? Theme.paper.opacity(0.7) : Theme.inkFaded)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(RoundedRectangle(cornerRadius: 4).fill(selected ? Theme.ink : Color.clear))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Perforation().padding(.horizontal, 8)
                        }
                    }
                    .padding(6)
                }
                .background(Theme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                Button {
                    let s = manager.add(name: "New snippet", content: "")
                    navigation.selectedSnippetId = s.id
                } label: {
                    Label("New Snippet", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(KeycapStyle(tone: .graphite, compact: true))
                .padding(.top, 10)
            }
            .frame(width: 220)
            .padding(.leading, 20)
            .padding(.vertical, 18)

            // Editor
            Group {
                if let id = navigation.selectedSnippetId, let snippet = manager.snippet(id: id) {
                    SnippetEditor(snippet: snippet, onDelete: {
                        manager.delete(id: id)
                        navigation.selectedSnippetId = manager.sorted.first?.id
                    })
                    .id(id)
                } else {
                    VStack(spacing: 8) {
                        Text(manager.snippets.isEmpty ? "No snippets yet" : "Select a snippet")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.bone)
                        Text("Snippets are text you reuse: signatures, addresses, replies, code.\nCreate one here, or select a text clip in the overlay and press ⌘S.")
                            .font(.system(size: 11.5))
                            .foregroundColor(Theme.boneDim)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(20)
        }
        .onAppear {
            if navigation.selectedSnippetId == nil { navigation.selectedSnippetId = manager.sorted.first?.id }
        }
    }
}

struct SnippetEditor: View {
    @State private var draft: Snippet
    @State private var confirmDelete = false
    let onDelete: () -> Void

    init(snippet: Snippet, onDelete: @escaping () -> Void) {
        _draft = State(initialValue: snippet)
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                field("Name", text: $draft.name, placeholder: "Email signature")
                field("Keyword", text: $draft.keyword, placeholder: "sig", width: 130)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("CONTENT").font(Theme.mono(9.5, .semibold)).foregroundColor(Theme.amber.opacity(0.85))
                TextEditor(text: $draft.content)
                    .font(Theme.mono(12))
                    .foregroundColor(Theme.bone)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Theme.screen)
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.black.opacity(0.7), lineWidth: 1))
                    )
                    .accessibilityLabel("Snippet content")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("INSERT A PLACEHOLDER").font(Theme.mono(9.5, .semibold)).foregroundColor(Theme.amber.opacity(0.85))
                FlowRow(spacing: 6) {
                    ForEach(SnippetManager.placeholders, id: \.token) { p in
                        Button(p.token) { draft.content += p.token }
                            .buttonStyle(KeycapStyle(tone: .graphite, compact: true))
                            .help(p.meaning)
                    }
                }
            }

            HStack {
                Text("Saved automatically · used \(draft.useCount)×")
                    .font(Theme.mono(10))
                    .foregroundColor(Theme.boneDim)
                Spacer()
                Button(confirmDelete ? "Delete snippet?" : "Delete") {
                    if confirmDelete { onDelete() } else {
                        confirmDelete = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { confirmDelete = false }
                    }
                }
                .buttonStyle(KeycapStyle(tone: confirmDelete ? .orange : .graphite, compact: true))
            }
        }
        .onChange(of: draft) { SnippetManager.shared.update($0) }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String, width: CGFloat? = nil) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(Theme.mono(9.5, .semibold)).foregroundColor(Theme.amber.opacity(0.85))
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(Theme.bone)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Theme.screen)
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.black.opacity(0.7), lineWidth: 1))
                )
                .accessibilityLabel(label)
        }
        .frame(width: width)
    }
}

/// Minimal wrapping HStack for macOS 13 (no Layout-based FlowLayout needed elsewhere).
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - About Pane

struct AboutPane: View {
    @Environment(\.openURL) var openURL

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "2"
        return "Version \(version) (Build \(build))"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                // Hero Header with new Logo
                HStack(spacing: 18) {
                    LogoMark(size: 72)
                        .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("ClipBoardUltra")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Theme.bone)

                        Text(appVersion)
                            .font(Theme.mono(11, .medium))
                            .foregroundColor(Theme.amber)

                        Text("A tactile, ultra-fast, keyboard-driven native clipboard manager for macOS.")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.boneDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)

                // Developer & Open Source Section
                SettingsSection(title: "Developer & Open Source", footnote: "ClipBoardUltra is 100% free and open source.") {
                    SettingsRow(title: "Developer", detail: "Sharooz — Creator & Lead Engineer") {
                        Button {
                            if let url = URL(string: "https://github.com/sharooz007") {
                                openURL(url)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "person.circle.fill")
                                Text("GitHub Profile")
                            }
                        }
                        .buttonStyle(KeycapStyle(tone: .bone, compact: true))
                    }

                    SettingsRow(title: "GitHub Repository", detail: "View source code, report issues, or star the project") {
                        Button {
                            if let url = URL(string: "https://github.com/sharooz007/ClipBoardUltra") {
                                openURL(url)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "link")
                                Text("GitHub Page")
                            }
                        }
                        .buttonStyle(KeycapStyle(tone: .orange, compact: true))
                    }

                    SettingsRow(title: "License", detail: "Open source under the permissive MIT License", showDivider: false) {
                        Text("MIT")
                            .font(Theme.mono(11, .semibold))
                            .foregroundColor(Theme.bone)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Theme.chassisLow)
                            )
                    }
                }

                // Architecture & Privacy
                SettingsSection(title: "Architecture & Privacy", footnote: "No copied text, images, or snippets ever leave your computer.") {
                    SettingsRow(title: "Network & Telemetry", detail: "100% On-Device · Zero Analytics · Zero External Calls") {
                        HStack(spacing: 6) {
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                            Text("Offline Only")
                                .font(Theme.mono(11, .semibold))
                                .foregroundColor(Theme.bone)
                        }
                    }

                    SettingsRow(title: "Local Database", detail: "History and rich snippets stored in Application Support", showDivider: false) {
                        Button {
                            let path = ("~/Library/Application Support/ClipBoardUltra" as NSString).expandingTildeInPath
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                        } label: {
                            Text("Reveal in Finder")
                        }
                        .buttonStyle(KeycapStyle(tone: .graphite, compact: true))
                    }
                }

                HStack {
                    Spacer()
                    Text("Crafted with care by Sharooz")
                        .font(Theme.mono(11, .medium))
                        .foregroundColor(Theme.boneDim.opacity(0.8))
                    Spacer()
                }
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
            .padding(24)
        }
    }
}

// MARK: - Drop Shelf Pane

struct DropShelfShortcutRecorder: View {
    @ObservedObject private var settings = SettingsStore.shared
    @State private var recording = false
    @State private var monitor: Any?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 8) {
                Button {
                    recording ? stop(restore: true) : start()
                } label: {
                    Text(recording ? "Press keys…  esc cancels" : settings.dropShelfHotkeyDisplay)
                        .font(recording ? .system(size: 11.5, weight: .semibold) : Theme.mono(13, .bold))
                        .frame(minWidth: 90)
                }
                .buttonStyle(KeycapStyle(tone: recording ? .orange : .bone))
                .accessibilityLabel("Drop shelf shortcut \(settings.dropShelfHotkeyDisplay). Click to change.")

                if settings.dropShelfHotkeyKeyCode != UInt32(kVK_ANSI_D) || settings.dropShelfHotkeyModifiers != UInt32(cmdKey | optionKey) {
                    Button("Reset") { apply(keyCode: UInt32(kVK_ANSI_D), modifiers: UInt32(cmdKey | optionKey)) }
                        .buttonStyle(KeycapStyle(tone: .graphite, compact: true))
                }
            }
            if let message {
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.orange)
            }
        }
        .onDisappear { if recording { stop(restore: true) } }
    }

    private func start() {
        message = nil
        recording = true
        HotkeyManager.shared.unregisterDropShelfHotkey()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stop(restore: true)
                return nil
            }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let mods = HotkeyFormatter.carbonModifiers(from: flags)
            let needsModifier = mods & UInt32(cmdKey | optionKey | controlKey) == 0
            let isFunctionKey = (kVK_F1...kVK_F12).contains(Int(event.keyCode))
            if needsModifier && !isFunctionKey {
                message = "Include ⌘, ⌥ or ⌃ in the shortcut."
                NSSound.beep()
                return nil
            }
            apply(keyCode: UInt32(event.keyCode), modifiers: mods)
            stop(restore: false)
            return nil
        }
    }

    private func apply(keyCode: UInt32, modifiers: UInt32) {
        let status = HotkeyManager.shared.registerDropShelf(keyCode: keyCode, modifiers: modifiers)
        if status == noErr {
            settings.dropShelfHotkeyKeyCode = keyCode
            settings.dropShelfHotkeyModifiers = modifiers
            message = nil
        } else {
            message = "\(HotkeyFormatter.string(keyCode: keyCode, modifiers: modifiers)) is already used by another app."
            HotkeyManager.shared.registerDefaultDropShelfHotkey()
        }
    }

    private func stop(restore: Bool) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        if restore { HotkeyManager.shared.registerDefaultDropShelfHotkey() }
    }
}

struct DropShelfPane: View {
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var manager = DropShelfManager.shared

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                // Activation & Gestures
                SettingsSection(title: "Activation & Gestures", footnote: "Hold and shake any file selection while dragging to spawn the drop zone near your cursor.") {
                    SettingsRow(title: "Enable Quick Drop Shelf", detail: "Temporary staging basket to gather files from multiple folders") {
                        Toggle("", isOn: $settings.dropShelfEnabled)
                            .labelsHidden()
                    }

                    SettingsRow(title: "Shake Cursor to Summon", detail: "Shake mouse quickly back and forth while dragging files in Finder") {
                        Toggle("", isOn: $settings.dropShelfShakeToSummon)
                            .labelsHidden()
                            .disabled(!settings.dropShelfEnabled)
                    }

                    SettingsRow(title: "Summon Shortcut", detail: "Global shortcut to open or hide the drop shelf anytime", showDivider: false) {
                        DropShelfShortcutRecorder()
                            .disabled(!settings.dropShelfEnabled)
                    }
                }

                // Behavior
                SettingsSection(title: "Shelf Behavior", footnote: "Dragged files follow standard macOS filesystem rules.") {
                    SettingsRow(title: "Auto-Dismiss When Emptied", detail: "Automatically fades away when all items are dragged out to destination") {
                        Toggle("", isOn: $settings.dropShelfAutoDismiss)
                            .labelsHidden()
                    }

                    SettingsRow(title: "Manual Control", detail: "Toggle the drop shelf right now to test", showDivider: false) {
                        Button {
                            manager.toggle()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: manager.isVisible ? "eye.slash" : "tray.and.arrow.down")
                                Text(manager.isVisible ? "Hide Drop Shelf" : "Show Drop Shelf")
                            }
                        }
                        .buttonStyle(KeycapStyle(tone: .orange, compact: true))
                    }
                }

                // How it works
                SettingsSection(title: "How It Works", footnote: "Collect files from multiple folders, then drag them all together in one move.") {
                    VStack(alignment: .leading, spacing: 10) {
                        guideStep(number: "1", text: "Select files in Finder, start dragging, and shake your cursor back and forth.")
                        guideStep(number: "2", text: "Drop files onto the shelf. Navigate to any other folder to add more files.")
                        guideStep(number: "3", text: "At your destination, drag all items out at once. The shelf automatically disappears!")
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(24)
        }
    }

    private func guideStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(Theme.mono(11, .bold))
                .foregroundColor(Theme.orange)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Theme.chassisLow))
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Theme.bone)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
