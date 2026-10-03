import Foundation
import Cocoa
import Carbon

/// Puts a clip on the pasteboard and types ⌘V into the app the user was working in.
///
/// Flow: the overlay is a non-activating panel, so the user's app stays frontmost the
/// whole time. On paste we write the pasteboard, close the panel (key focus returns to
/// the user's window), confirm the target app is frontmost, then post exactly one ⌘V.
public final class PasteEngine: ObservableObject {
    public static let shared = PasteEngine()

    @Published public private(set) var isAccessibilityGranted: Bool = AXIsProcessTrusted()
    public private(set) var previousApplication: NSRunningApplication?

    private var permissionTimer: Timer?
    private var hasPromptedThisSession = false

    private init() {
        startPermissionPolling()
    }

    // MARK: - Accessibility

    public func checkAccessibilityStatus() {
        let trusted = AXIsProcessTrusted()
        if trusted != isAccessibilityGranted {
            isAccessibilityGranted = trusted
            print("[PasteEngine] Accessibility trusted = \(trusted)")
        }
    }

    /// Polls so the UI updates as soon as the user flips the switch in System Settings.
    private func startPermissionPolling() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.checkAccessibilityStatus()
        }
    }

    public func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openAccessibilitySettings()
    }

    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Target app

    public func recordActiveApplication() {
        guard let current = NSWorkspace.shared.frontmostApplication else { return }
        let myPID = ProcessInfo.processInfo.processIdentifier
        if current.processIdentifier != myPID, current.bundleIdentifier != "com.apple.loginwindow" {
            previousApplication = current
            print("[PasteEngine] Target app: \(current.localizedName ?? "?") (\(current.bundleIdentifier ?? ""))")
        }
    }

    // MARK: - Paste / Copy

    /// Pastes `item` into the previous app.
    /// - Parameter plainText: force plain (true) or formatted (false); nil follows Settings.
    public func paste(item: ClipboardItem, plainText: Bool? = nil, hideOverlay: () -> Void) {
        let cursorOffset = write(item, plainText: plainText ?? SettingsStore.shared.pastePlainTextByDefault)
        recordUse(of: item)
        hideOverlay()

        checkAccessibilityStatus()
        guard isAccessibilityGranted else {
            // Without permission macOS silently drops synthetic keystrokes. The clip is
            // already on the clipboard, so the user can still press ⌘V themselves.
            print("[PasteEngine] Accessibility not granted — clip copied, auto-paste skipped.")
            if !hasPromptedThisSession {
                hasPromptedThisSession = true
                requestAccessibilityPermission()
            }
            return
        }

        let target = previousApplication
        let myPID = ProcessInfo.processInfo.processIdentifier

        // If something (e.g. a click inside the panel) made us frontmost, hand focus back.
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == myPID {
            NSApp.hide(nil)
        }
        if let target, !target.isTerminated, NSWorkspace.shared.frontmostApplication?.processIdentifier != target.processIdentifier {
            target.activate(options: [.activateIgnoringOtherApps])
        }

        waitForFrontmost(target: target, deadline: Date().addingTimeInterval(0.8)) { [weak self] in
            self?.postCommandV()
            if let offset = cursorOffset, offset > 0 {
                // Give the app a moment to insert the text, then walk the caret back to {cursor}.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    self?.postLeftArrow(times: offset)
                }
            }
        }
    }

    public func copyOnly(item: ClipboardItem, plainText: Bool? = nil, hideOverlay: () -> Void) {
        _ = write(item, plainText: plainText ?? SettingsStore.shared.pastePlainTextByDefault)
        recordUse(of: item)
        hideOverlay()
    }

    private func recordUse(of item: ClipboardItem) {
        if item.isSnippet {
            SnippetManager.shared.markUsed(id: item.id)
        } else {
            ClipboardManager.shared.promote(item)
        }
    }

    /// Waits until the target app is frontmost and our panel is gone, then gives the
    /// window server a short beat to restore key focus before firing.
    private func waitForFrontmost(target: NSRunningApplication?, deadline: Date, then action: @escaping () -> Void) {
        let myPID = ProcessInfo.processInfo.processIdentifier
        let front = NSWorkspace.shared.frontmostApplication
        let ready: Bool
        if let target {
            ready = front?.processIdentifier == target.processIdentifier
        } else {
            ready = front?.processIdentifier != myPID
        }

        if ready || Date() >= deadline {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: action)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
                self?.waitForFrontmost(target: target, deadline: deadline, then: action)
            }
        }
    }

    /// Backwards-compatible entry point: writes the item using the default formatting setting.
    public func copyToPasteboard(item: ClipboardItem) {
        _ = write(item, plainText: SettingsStore.shared.pastePlainTextByDefault)
    }

    /// Puts the item on the pasteboard. Returns a caret offset for snippets containing {cursor}.
    @discardableResult
    private func write(_ item: ClipboardItem, plainText: Bool) -> Int? {
        let settings = SettingsStore.shared
        var cursorOffset: Int?

        // Expand snippets before clearing, so {clipboard} still sees the current contents.
        var snippetText: String?
        if item.isSnippet {
            let expansion = SnippetManager.expand(item.fullText ?? item.previewText)
            snippetText = expansion.text
            cursorOffset = expansion.cursorOffsetFromEnd
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .text, .code, .snippet:
            var text = snippetText ?? item.fullText ?? item.previewText
            if settings.trimWhitespace && !item.isSnippet {
                text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            // Formatted data is only reused when the text is unchanged, otherwise the
            // rich and plain versions would disagree.
            let unchanged = text == item.fullText
            if !plainText, unchanged, let name = item.richRelativePath,
               let rich = StorageManager.shared.loadRichData(named: name), !rich.isEmpty {
                let types = [NSPasteboard.PasteboardType.string] + rich.keys.map { NSPasteboard.PasteboardType($0) }
                pasteboard.declareTypes(types, owner: nil)
                pasteboard.setString(text, forType: .string)
                for (type, data) in rich {
                    pasteboard.setData(data, forType: NSPasteboard.PasteboardType(type))
                }
            } else {
                pasteboard.setString(text, forType: .string)
            }

        case .image, .screenshot:
            var image: NSImage?
            if let relPath = item.imageRelativePath {
                image = StorageManager.shared.loadImage(named: relPath)
            } else if let filePath = item.filePath {
                image = NSImage(contentsOfFile: filePath)
            }
            if let img = image {
                pasteboard.writeObjects([img])
            } else if let path = item.filePath {
                pasteboard.setString(path, forType: .string)
            }

        case .file(let path):
            // Writing the URL alone lets Finder paste the file and text fields paste the path.
            pasteboard.writeObjects([URL(fileURLWithPath: path) as NSURL])
        }

        // Tell the monitor this change is ours so it is not recorded as a new clip.
        ClipboardManager.shared.acknowledgeInternalChange(pasteboard.changeCount)
        return cursorOffset
    }

    // MARK: - Keystroke

    private func postLeftArrow(times: Int) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for _ in 0..<min(times, 2000) {
            for down in [true, false] {
                let e = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_LeftArrow), keyDown: down)
                e?.flags = []   // ignore physically held ⌘/⌥ so this is a plain ←
                e?.post(tap: .cgSessionEventTap)
            }
        }
    }

    /// Posts a single ⌘V. Uses the key code that produces "v" on the current keyboard
    /// layout, so Dvorak/AZERTY etc. also work.
    private func postCommandV() {
        let vKey = KeyboardLayout.keyCode(for: "v") ?? CGKeyCode(kVK_ANSI_V)
        let source = CGEventSource(stateID: .combinedSessionState)
        // Keep physically-held keys (e.g. ⌘ from ⌘1–9) from leaking into our event.
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        guard let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) else {
            print("[PasteEngine] Could not create key events")
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
        print("[PasteEngine] Posted ⌘V to \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "?")")
    }
}

/// Resolves which virtual key code types a given character on the active keyboard layout.
enum KeyboardLayout {
    /// The character a key produces on the current layout (no modifiers), e.g. 9 → "v".
    static func character(for keyCode: CGKeyCode) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let dataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(dataPtr).takeUnretainedValue() as Data
        return layoutData.withUnsafeBytes { raw -> String? in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            var deadKeys: UInt32 = 0
            var length = 0
            var chars = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                                        UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                        &deadKeys, chars.count, &length, &chars)
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: chars, count: length)
        }
    }

    static func keyCode(for character: Character) -> CGKeyCode? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let dataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(dataPtr).takeUnretainedValue() as Data
        let target = String(character).lowercased()

        return layoutData.withUnsafeBytes { raw -> CGKeyCode? in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            for code in 0..<128 {
                var deadKeys: UInt32 = 0
                var length = 0
                var chars = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(
                    layout, UInt16(code), UInt16(kUCKeyActionDown), 0,
                    UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                    &deadKeys, chars.count, &length, &chars
                )
                if status == noErr, length > 0,
                   String(utf16CodeUnits: chars, count: length).lowercased() == target {
                    return CGKeyCode(code)
                }
            }
            return nil
        }
    }
}
