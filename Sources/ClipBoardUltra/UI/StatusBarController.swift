import Cocoa
import Combine

public final class StatusBarController: NSObject, NSMenuDelegate {
    public static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var observers: Set<AnyCancellable> = []

    private override init() {
        super.init()
    }

    public func setupStatusBar() {
        let settings = SettingsStore.shared

        settings.$showMenuBarIcon
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in visible ? self?.install() : self?.remove() }
            .store(in: &observers)

        settings.$pausedUntil
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshIcon() }
            .store(in: &observers)

        settings.$hotkeyKeyCode.combineLatest(settings.$hotkeyModifiers)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshIcon() }
            .store(in: &observers)
    }

    private func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = MenuBarGlyph.image()
        item.menu = menu
        menu.delegate = self
        statusItem = item
        refreshIcon()
    }

    private func remove() {
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        statusItem = nil
    }

    private func refreshIcon() {
        guard let button = statusItem?.button else { return }
        let settings = SettingsStore.shared
        // Dimmed icon = recording paused.
        button.appearsDisabled = settings.isPaused
        button.toolTip = settings.isPaused
            ? "ClipBoardUltra — \(settings.pauseDescription ?? "paused")"
            : "ClipBoardUltra — \(settings.hotkeyDisplay)"
    }

    public func menuWillOpen(_ menu: NSMenu) {
        PasteEngine.shared.checkAccessibilityStatus()
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        let settings = SettingsStore.shared

        let openItem = NSMenuItem(title: "Open Clipboard History", action: #selector(openOverlay), keyEquivalent: "")
        openItem.target = self
        openItem.toolTip = settings.hotkeyDisplay
        menu.addItem(openItem)

        let snippetsItem = NSMenuItem(title: "Snippets…", action: #selector(openSnippets), keyEquivalent: "")
        snippetsItem.target = self
        menu.addItem(snippetsItem)

        let shelfTitle = DropShelfManager.shared.isVisible ? "Hide Drop Shelf" : "Show Drop Shelf"
        let shelfItem = NSMenuItem(title: "\(shelfTitle) (\(settings.dropShelfHotkeyDisplay))", action: #selector(toggleDropShelf), keyEquivalent: "")
        shelfItem.target = self
        menu.addItem(shelfItem)

        menu.addItem(.separator())

        let statsItem = NSMenuItem(
            title: "\(ClipboardManager.shared.items.count) clips · \(SnippetManager.shared.snippets.count) snippets",
            action: nil, keyEquivalent: ""
        )
        statsItem.isEnabled = false
        menu.addItem(statsItem)

        let trusted = PasteEngine.shared.isAccessibilityGranted
        let accessItem = NSMenuItem(
            title: trusted ? "Auto-paste: On" : "Auto-paste: Off — Grant Accessibility…",
            action: trusted ? nil : #selector(handleAccessibilityClick),
            keyEquivalent: ""
        )
        accessItem.target = self
        accessItem.isEnabled = !trusted
        accessItem.state = trusted ? .on : .off
        menu.addItem(accessItem)

        // Pause / resume
        if settings.isPaused {
            let resume = NSMenuItem(title: "Resume Recording (\(settings.pauseDescription ?? "paused"))",
                                    action: #selector(resumeRecording), keyEquivalent: "")
            resume.target = self
            menu.addItem(resume)
        } else {
            let pause = NSMenuItem(title: "Pause Recording", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for (title, seconds) in [("For 5 Minutes", 300), ("For 1 Hour", 3600), ("Until I Resume", 0)] {
                let i = NSMenuItem(title: title, action: #selector(pauseRecording(_:)), keyEquivalent: "")
                i.target = self
                i.tag = seconds
                sub.addItem(i)
            }
            pause.submenu = sub
            menu.addItem(pause)
        }

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "About ClipBoardUltra…", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let clearItem = NSMenuItem(title: "Clear Unpinned Clips…", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit ClipBoardUltra", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func openOverlay() {
        // Let the menu finish closing so the previous app is frontmost again.
        DispatchQueue.main.async { OverlayPanelManager.shared.show() }
    }

    @objc private func openSnippets() {
        SettingsWindowController.shared.show(tab: .snippets)
    }

    @objc private func toggleDropShelf() {
        DropShelfManager.shared.toggle()
    }

    @objc private func openAbout() {
        SettingsWindowController.shared.show(tab: .about)
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func pauseRecording(_ sender: NSMenuItem) {
        SettingsStore.shared.pause(for: sender.tag == 0 ? nil : TimeInterval(sender.tag))
    }

    @objc private func resumeRecording() {
        SettingsStore.shared.resume()
    }

    @objc private func handleAccessibilityClick() {
        PasteEngine.shared.requestAccessibilityPermission()
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear unpinned clips?"
        alert.informativeText = "Pinned clips and snippets are kept. This can't be undone."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            ClipboardManager.shared.clearAllUnpinned()
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
