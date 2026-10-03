import Cocoa
import SwiftUI
import Carbon

extension Notification.Name {
    static let overlayDidShow = Notification.Name("ClipBoardUltraOverlayDidShow")
}

/// Floating panel that takes keyboard focus *without* activating ClipBoardUltra, so the
/// app you were typing in stays frontmost and receives the paste.
public final class CustomPanel: NSPanel {
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }

    public override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, handleKey(event) { return }
        super.sendEvent(event)
    }

    /// Returns true when the key was consumed as a command instead of being typed into search.
    private func handleKey(_ event: NSEvent) -> Bool {
        let manager = ClipboardManager.shared
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let cmd = flags.contains(.command)
        let searchEmpty = manager.searchQuery.isEmpty

        switch Int(event.keyCode) {
        case kVK_Escape:
            if !searchEmpty { manager.searchQuery = "" } else { OverlayPanelManager.shared.hide() }
            return true

        case kVK_Return, kVK_ANSI_KeypadEnter:
            if let item = manager.getSelectedItem() {
                // ⇧ flips plain/formatted; ⌘ flips paste/copy relative to the Settings default.
                let settings = SettingsStore.shared
                let plain = flags.contains(.shift) ? !settings.pastePlainTextByDefault : settings.pastePlainTextByDefault
                let shouldPaste = (settings.returnAction == .paste) != cmd
                if shouldPaste {
                    OverlayPanelManager.shared.pasteItem(item, plainText: plain)
                } else {
                    OverlayPanelManager.shared.copyItem(item, plainText: plain)
                }
            }
            return true

        case kVK_DownArrow:
            manager.selectNext(); return true

        case kVK_UpArrow:
            manager.selectPrevious(); return true

        case kVK_RightArrow where cmd || searchEmpty:
            manager.selectCategoryNext(); return true

        case kVK_LeftArrow where cmd || searchEmpty:
            manager.selectCategoryPrevious(); return true

        case kVK_Tab:
            if flags.contains(.shift) { manager.selectCategoryPrevious() } else { manager.selectCategoryNext() }
            return true

        case kVK_Delete where cmd:
            // ⌘⌫ only: a plain ⌫ after clearing the search must never delete a clip by accident.
            // Snippets are edited and deleted in Settings, never from here.
            if let item = manager.getSelectedItem(), !item.isSnippet { manager.deleteItem(item) }
            return true

        case kVK_ANSI_P where cmd:
            if let item = manager.getSelectedItem(), !item.isSnippet { manager.togglePin(for: item) }
            return true

        case kVK_ANSI_S where cmd:
            if let item = manager.getSelectedItem() { OverlayPanelManager.shared.saveAsSnippet(item) }
            return true

        case kVK_ANSI_Comma where cmd:
            OverlayPanelManager.shared.hide()
            SettingsWindowController.shared.show()
            return true

        case kVK_ANSI_C where cmd:
            // Let ⌘C copy selected search text; otherwise copy the highlighted clip.
            if let editor = firstResponder as? NSTextView, editor.selectedRange().length > 0 { return false }
            if let item = manager.getSelectedItem() { OverlayPanelManager.shared.copyItem(item) }
            return true

        case kVK_ANSI_W where cmd:
            OverlayPanelManager.shared.hide(); return true

        default:
            break
        }

        // ⌘1 … ⌘9 quick paste. Plain digits are left alone so they can be searched for.
        let digitKeys: [Int] = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                                kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
        if cmd, let idx = digitKeys.firstIndex(of: Int(event.keyCode)) {
            if manager.filteredItems.indices.contains(idx) {
                OverlayPanelManager.shared.pasteItem(manager.filteredItems[idx])
            }
            return true
        }
        return false
    }
}

public final class OverlayPanelManager: NSObject, NSWindowDelegate {
    public static let shared = OverlayPanelManager()

    public private(set) var panel: CustomPanel?
    private var globalClickMonitor: Any?

    static let panelSize = NSSize(width: 800, height: 540)

    private override init() {
        super.init()
    }

    public func setupPanel() {
        guard panel == nil else { return }

        let customPanel = CustomPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        customPanel.isFloatingPanel = true
        customPanel.level = .popUpMenu
        customPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        customPanel.backgroundColor = .clear
        customPanel.isOpaque = false
        customPanel.hasShadow = true
        customPanel.isMovableByWindowBackground = true
        customPanel.hidesOnDeactivate = false
        customPanel.becomesKeyOnlyIfNeeded = false
        customPanel.appearance = NSAppearance(named: .darkAqua)
        customPanel.delegate = self

        let mainView = MainView(
            onPasteItem: { [weak self] item in self?.pasteItem(item) },
            onCopyItem: { [weak self] item in self?.copyItem(item) },
            onClose: { [weak self] in self?.hide() }
        )

        let hostingView = NSHostingView(rootView: mainView)
        hostingView.frame = NSRect(origin: .zero, size: Self.panelSize)
        customPanel.contentView = hostingView
        panel = customPanel
    }

    public func toggle() {
        if panel?.isVisible == true { hide() } else { show() }
    }

    public func show() {
        setupPanel()
        guard let panel else { return }

        PasteEngine.shared.recordActiveApplication()
        PasteEngine.shared.checkAccessibilityStatus()
        ClipboardManager.shared.resetForPresentation()

        // Center on the chosen screen, slightly above middle.
        if let screen = targetScreen() {
            let frame = screen.visibleFrame
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(
                x: frame.midX - size.width / 2,
                y: frame.midY - size.height / 2 + frame.height * 0.08
            ))
        } else {
            panel.center()
        }

        // No NSApp.activate: the panel becomes key while the user's app stays active.
        panel.alphaValue = 1
        panel.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .overlayDidShow, object: nil)
        setupGlobalClickMonitor()
    }

    public func hide() {
        removeGlobalClickMonitor()
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
    }

    public func pasteItem(_ item: ClipboardItem, plainText: Bool? = nil) {
        PasteEngine.shared.paste(item: item, plainText: plainText) { [weak self] in self?.hide() }
    }

    public func copyItem(_ item: ClipboardItem, plainText: Bool? = nil) {
        PasteEngine.shared.copyOnly(item: item, plainText: plainText) { [weak self] in self?.hide() }
    }

    /// Turns a text clip into a snippet and opens it in Settings for naming/editing.
    public func saveAsSnippet(_ item: ClipboardItem) {
        guard item.isTextual, !item.isSnippet, let text = item.fullText, !text.isEmpty else {
            NSSound.beep()
            return
        }
        let snippet = SnippetManager.shared.add(name: String(item.title.prefix(60)), content: text)
        hide()
        SettingsWindowController.shared.show(tab: .snippets, selectSnippet: snippet.id)
    }

    public func windowDidResignKey(_ notification: Notification) {
        // Another window took focus (e.g. ⌘Tab or a click elsewhere): get out of the way.
        hide()
    }

    /// Screen for the overlay, per Settings › General › "Open on".
    private func targetScreen() -> NSScreen? {
        let pointerScreen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
        guard SettingsStore.shared.overlayPlacement == .activeWindowScreen,
              let pid = PasteEngine.shared.previousApplication?.processIdentifier,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return pointerScreen ?? NSScreen.main }

        // Front-most normal window of the app you were using (window bounds need no permission).
        for info in windows {
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else { continue }
            // CG window coordinates are top-left based on the primary screen; convert to Cocoa.
            let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
            let center = NSPoint(x: bounds.midX, y: primaryHeight - bounds.midY)
            if let screen = NSScreen.screens.first(where: { NSMouseInRect(center, $0.frame, false) }) {
                return screen
            }
        }
        return pointerScreen ?? NSScreen.main
    }

    private func setupGlobalClickMonitor() {
        removeGlobalClickMonitor()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, let panel = self.panel, panel.isVisible else { return }
            if !NSMouseInRect(NSEvent.mouseLocation, panel.frame, false) {
                self.hide()
            }
        }
    }

    private func removeGlobalClickMonitor() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
}
