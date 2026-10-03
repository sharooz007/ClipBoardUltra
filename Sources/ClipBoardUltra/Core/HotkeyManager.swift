import Foundation
import Carbon
import Cocoa

/// System-wide hotkey via Carbon (works without Accessibility permission).
public final class HotkeyManager {
    public static let shared = HotkeyManager()

    public var onHotKeyPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeySignature: OSType = 0x43425531 // "CBU1"
    private let hotKeyIDNumber: UInt32 = 1

    private init() {}

    /// Registers the shortcut saved in Settings.
    public func registerDefaultHotkey() {
        let s = SettingsStore.shared
        let status = register(keyCode: s.hotkeyKeyCode, modifiers: s.hotkeyModifiers)
        if status != noErr {
            print("[Hotkey] Could not register \(s.hotkeyDisplay) (\(status))")
        }
    }

    /// Replaces the current hotkey. Returns `noErr` on success; `eventHotKeyExistsErr`
    /// when another app already owns the combination.
    @discardableResult
    public func register(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        unregisterHotkey()
        installHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: hotKeyIDNumber)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status == noErr {
            print("[Hotkey] Registered \(HotkeyFormatter.string(keyCode: keyCode, modifiers: modifiers))")
        } else {
            hotKeyRef = nil
        }
        return status
    }

    /// Temporarily releases the hotkey (used while recording a new one).
    public func unregisterHotkey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, theEvent, _ -> OSStatus in
            guard let theEvent else { return noErr }
            var hkID = EventHotKeyID()
            let status = GetEventParameter(theEvent, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            if status == noErr && hkID.id == 1 {
                DispatchQueue.main.async { HotkeyManager.shared.onHotKeyPressed?() }
            }
            return noErr
        }

        let status = InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandlerRef)
        if status != noErr { print("[Hotkey] Failed to install event handler: \(status)") }
    }

    public func teardown() {
        unregisterHotkey()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }
}
