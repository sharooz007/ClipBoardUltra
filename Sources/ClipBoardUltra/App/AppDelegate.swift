import Cocoa
import Darwin

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public static let toggleNotification = "com.ultra.ClipBoardUltra.toggle"
    private var cmdSource: DispatchSourceFileSystemObject?
    private var cmdFd: CInt = -1

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setbuf(stdout, nil)
        setbuf(stderr, nil)

        print("[AppDelegate] applicationDidFinishLaunching started")

        // Run as accessory app (lives in Menu Bar and Floating HUD, out of Dock)
        NSApp.setActivationPolicy(.accessory)

        // Preload core services
        _ = ClipboardManager.shared
        _ = ScreenshotManager.shared
        _ = PasteEngine.shared
        _ = SnippetManager.shared

        // Setup menu bar icon
        StatusBarController.shared.setupStatusBar()

        // Setup overlay window
        OverlayPanelManager.shared.setupPanel()

        // Register the global hotkey saved in Settings (default ⌥⌘V)
        HotkeyManager.shared.onHotKeyPressed = {
            print("[Hotkey] triggered")
            OverlayPanelManager.shared.toggle()
        }
        HotkeyManager.shared.registerDefaultHotkey()

        // Register the Drop Shelf hotkey (default ⌥⌘D) and start mouse shake monitor
        HotkeyManager.shared.onDropShelfHotKeyPressed = {
            print("[Hotkey] drop shelf triggered")
            DropShelfManager.shared.toggle()
        }
        HotkeyManager.shared.registerDefaultDropShelfHotkey()
        DragShakeMonitor.shared.start()

        // Start automatically at login (first launch only; user can turn it off in the menu)
        LoginItemManager.shared.enableOnFirstLaunch()

        // Setup File-based IPC monitor (/tmp/clipboardultra.cmd)
        setupCommandFileMonitor()

        print("[AppDelegate] ClipBoardUltra started successfully.")
    }

    private func setupCommandFileMonitor() {
        let path = "/tmp/clipboardultra.cmd"
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
        }

        cmdFd = open(path, O_EVTONLY)
        guard cmdFd >= 0 else {
            print("[Command] Failed to open command file descriptor at \(path)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: cmdFd,
            eventMask: [.write, .extend],
            queue: DispatchQueue.main
        )

        source.setEventHandler {
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
                OverlayPanelManager.shared.toggle()
                return
            }
            let lastLine = content.components(separatedBy: .newlines).filter { !$0.isEmpty }.last ?? ""
            print("[Command] Received command: '\(lastLine)'")

            if lastLine == "show" {
                OverlayPanelManager.shared.show()
            } else if lastLine == "hide" {
                OverlayPanelManager.shared.hide()
            } else if lastLine == "shelf" {
                DropShelfManager.shared.toggle()
            } else if lastLine.hasPrefix("shelf-add ") {
                let filePath = String(lastLine.dropFirst("shelf-add ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                let url = URL(fileURLWithPath: filePath)
                DropShelfManager.shared.addFiles([url])
            } else if lastLine == "shelf-clear" {
                DropShelfManager.shared.clearAll()
            } else if lastLine == "settings-shelf" {
                SettingsWindowController.shared.show(tab: .dropShelf)
            } else if lastLine == "settings" {
                SettingsWindowController.shared.show()
            } else if lastLine == "about" {
                SettingsWindowController.shared.show(tab: .about)
            } else {
                OverlayPanelManager.shared.toggle()
            }
        }

        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.cmdFd >= 0 {
                close(self.cmdFd)
                self.cmdFd = -1
            }
        }

        source.resume()
        self.cmdSource = source
        print("[Command] Monitor active on \(path)")
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Opening the app from Finder/Spotlight shows Settings — the way back when the
        // menu bar icon is hidden.
        SettingsWindowController.shared.show()
        return true
    }

    public func applicationWillTerminate(_ notification: Notification) {
        cmdSource?.cancel()
        HotkeyManager.shared.unregisterHotkey()
        ClipboardManager.shared.stopMonitoring()
        ScreenshotManager.shared.stopMonitoring()
    }
}
