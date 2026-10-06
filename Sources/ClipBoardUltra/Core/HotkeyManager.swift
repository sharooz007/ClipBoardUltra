import Foundation
import Carbon
import Cocoa

/// System-wide hotkey via Carbon (works without Accessibility permission).
public final class HotkeyManager {
    public static let shared = HotkeyManager()

    public var onHotKeyPressed: (() -> Void)?
    public var onDropShelfHotKeyPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var dropShelfHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeySignature: OSType = 0x43425531 // "CBU1"
    private let hotKeyIDNumber: UInt32 = 1
    private let dropShelfHotKeyIDNumber: UInt32 = 2

    private init() {}

    /// Registers the shortcut saved in Settings for main overlay.
    public func registerDefaultHotkey() {
        let s = SettingsStore.shared
        let status = register(keyCode: s.hotkeyKeyCode, modifiers: s.hotkeyModifiers)
        if status != noErr {
            print("[Hotkey] Could not register \(s.hotkeyDisplay) (\(status))")
        }
    }

    /// Registers the shortcut saved in Settings for Drop Shelf.
    public func registerDefaultDropShelfHotkey() {
        let s = SettingsStore.shared
        guard s.dropShelfEnabled else { return }
        let status = registerDropShelf(keyCode: s.dropShelfHotkeyKeyCode, modifiers: s.dropShelfHotkeyModifiers)
        if status != noErr {
            print("[Hotkey] Could not register drop shelf hotkey \(s.dropShelfHotkeyDisplay) (\(status))")
        }
    }

    /// Replaces the current main overlay hotkey.
    @discardableResult
    public func register(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        unregisterHotkey()
        installHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: hotKeyIDNumber)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status == noErr {
            print("[Hotkey] Registered overlay \(HotkeyFormatter.string(keyCode: keyCode, modifiers: modifiers))")
        } else {
            hotKeyRef = nil
        }
        return status
    }

    /// Replaces the current drop shelf hotkey.
    @discardableResult
    public func registerDropShelf(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        unregisterDropShelfHotkey()
        installHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: dropShelfHotKeyIDNumber)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &dropShelfHotKeyRef)
        if status == noErr {
            print("[Hotkey] Registered drop shelf \(HotkeyFormatter.string(keyCode: keyCode, modifiers: modifiers))")
        } else {
            dropShelfHotKeyRef = nil
        }
        return status
    }

    /// Releases the main overlay hotkey.
    public func unregisterHotkey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    /// Releases the drop shelf hotkey.
    public func unregisterDropShelfHotkey() {
        if let dropShelfHotKeyRef {
            UnregisterEventHotKey(dropShelfHotKeyRef)
            self.dropShelfHotKeyRef = nil
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
            if status == noErr {
                if hkID.id == 1 {
                    DispatchQueue.main.async { HotkeyManager.shared.onHotKeyPressed?() }
                } else if hkID.id == 2 {
                    DispatchQueue.main.async { HotkeyManager.shared.onDropShelfHotKeyPressed?() }
                }
            }
            return noErr
        }

        let status = InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandlerRef)
        if status != noErr { print("[Hotkey] Failed to install event handler: \(status)") }
    }

    public func teardown() {
        unregisterHotkey()
        unregisterDropShelfHotkey()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }
}
