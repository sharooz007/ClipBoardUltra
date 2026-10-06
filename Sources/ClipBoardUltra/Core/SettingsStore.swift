import Foundation
import Cocoa
import Carbon
import Combine

/// Every user preference, persisted in UserDefaults. Other components read from here
/// instead of hard-coding values.
public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()
    private let defaults = UserDefaults.standard

    // MARK: Enums

    public enum OverlayPlacement: String, CaseIterable, Identifiable {
        case pointerScreen, activeWindowScreen
        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .pointerScreen: return "Screen with the pointer"
            case .activeWindowScreen: return "Screen with the active window"
            }
        }
    }

    public enum Retention: String, CaseIterable, Identifiable {
        case day, week, month, forever
        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .day: return "1 day"
            case .week: return "1 week"
            case .month: return "1 month"
            case .forever: return "Forever"
            }
        }
        public var interval: TimeInterval? {
            switch self {
            case .day: return 86_400
            case .week: return 7 * 86_400
            case .month: return 30 * 86_400
            case .forever: return nil
            }
        }
    }

    public enum ReturnAction: String, CaseIterable, Identifiable {
        case paste, copy
        public var id: String { rawValue }
        public var label: String { self == .paste ? "Paste into the previous app" : "Copy to the clipboard only" }
    }

    public static let historyLimits = [100, 300, 1000, 5000]
    public static let imageLimitsMB = [5, 20, 50, 0]   // 0 = no limit

    // MARK: General

    @Published public var hotkeyKeyCode: UInt32 { didSet { defaults.set(Int(hotkeyKeyCode), forKey: "hotkeyKeyCode") } }
    @Published public var hotkeyModifiers: UInt32 { didSet { defaults.set(Int(hotkeyModifiers), forKey: "hotkeyModifiers") } }
    @Published public var overlayPlacement: OverlayPlacement { didSet { defaults.set(overlayPlacement.rawValue, forKey: "overlayPlacement") } }
    @Published public var showMenuBarIcon: Bool { didSet { defaults.set(showMenuBarIcon, forKey: "showMenuBarIcon") } }

    // MARK: Drop Shelf

    @Published public var dropShelfEnabled: Bool { didSet { defaults.set(dropShelfEnabled, forKey: "dropShelfEnabled") } }
    @Published public var dropShelfShakeToSummon: Bool { didSet { defaults.set(dropShelfShakeToSummon, forKey: "dropShelfShakeToSummon"); DragShakeMonitor.shared.restartIfNeeded() } }
    @Published public var dropShelfHotkeyKeyCode: UInt32 { didSet { defaults.set(Int(dropShelfHotkeyKeyCode), forKey: "dropShelfHotkeyKeyCode") } }
    @Published public var dropShelfHotkeyModifiers: UInt32 { didSet { defaults.set(Int(dropShelfHotkeyModifiers), forKey: "dropShelfHotkeyModifiers") } }
    @Published public var dropShelfAutoDismiss: Bool { didSet { defaults.set(dropShelfAutoDismiss, forKey: "dropShelfAutoDismiss") } }

    // MARK: History

    @Published public var maxItems: Int { didSet { defaults.set(maxItems, forKey: "maxItems") } }
    @Published public var retention: Retention { didSet { defaults.set(retention.rawValue, forKey: "retention") } }
    @Published public var captureText: Bool { didSet { defaults.set(captureText, forKey: "captureText") } }
    @Published public var captureImages: Bool { didSet { defaults.set(captureImages, forKey: "captureImages") } }
    @Published public var captureFiles: Bool { didSet { defaults.set(captureFiles, forKey: "captureFiles") } }
    @Published public var captureScreenshots: Bool { didSet { defaults.set(captureScreenshots, forKey: "captureScreenshots") } }
    @Published public var maxImageMB: Int { didSet { defaults.set(maxImageMB, forKey: "maxImageMB") } }

    // MARK: Paste

    @Published public var returnAction: ReturnAction { didSet { defaults.set(returnAction.rawValue, forKey: "returnAction") } }
    @Published public var pastePlainTextByDefault: Bool { didSet { defaults.set(pastePlainTextByDefault, forKey: "pastePlainTextByDefault") } }
    @Published public var trimWhitespace: Bool { didSet { defaults.set(trimWhitespace, forKey: "trimWhitespace") } }
    @Published public var promoteOnUse: Bool { didSet { defaults.set(promoteOnUse, forKey: "promoteOnUse") } }
    @Published public var showQuickIndexBadges: Bool { didSet { defaults.set(showQuickIndexBadges, forKey: "showQuickIndexBadges") } }

    // MARK: Privacy

    /// Bundle identifiers whose copies are never recorded.
    @Published public var ignoredApps: [String] { didSet { defaults.set(ignoredApps, forKey: "ignoredApps") } }
    @Published public var ignoreSecrets: Bool { didSet { defaults.set(ignoreSecrets, forKey: "ignoreSecrets") } }
    /// Recording is paused while this is in the future. `.distantFuture` = until resumed.
    @Published public var pausedUntil: Date? { didSet { defaults.set(pausedUntil, forKey: "pausedUntil") } }
    /// nil = follow the macOS screenshot location automatically.
    @Published public var customScreenshotFolder: String? { didSet { defaults.set(customScreenshotFolder, forKey: "customScreenshotFolder") } }

    private var pauseTimer: Timer?

    private init() {
        defaults.register(defaults: [
            "hotkeyKeyCode": kVK_ANSI_V,
            "hotkeyModifiers": cmdKey | optionKey,
            "overlayPlacement": OverlayPlacement.pointerScreen.rawValue,
            "showMenuBarIcon": true,
            "maxItems": 300,
            "retention": Retention.forever.rawValue,
            "captureText": true,
            "captureImages": true,
            "captureFiles": true,
            "captureScreenshots": true,
            "maxImageMB": 20,
            "returnAction": ReturnAction.paste.rawValue,
            "pastePlainTextByDefault": false,
            "trimWhitespace": false,
            "promoteOnUse": true,
            "showQuickIndexBadges": true,
            "ignoredApps": [
                "com.1password.1password", "com.agilebits.onepassword7", "com.bitwarden.desktop",
                "com.apple.keychainaccess", "com.apple.Passwords"
            ],
            "ignoreSecrets": true,
            "dropShelfEnabled": true,
            "dropShelfShakeToSummon": true,
            "dropShelfHotkeyKeyCode": kVK_ANSI_D,
            "dropShelfHotkeyModifiers": cmdKey | optionKey,
            "dropShelfAutoDismiss": true
        ])

        hotkeyKeyCode = UInt32(defaults.integer(forKey: "hotkeyKeyCode"))
        hotkeyModifiers = UInt32(defaults.integer(forKey: "hotkeyModifiers"))
        dropShelfEnabled = defaults.bool(forKey: "dropShelfEnabled")
        dropShelfShakeToSummon = defaults.bool(forKey: "dropShelfShakeToSummon")
        dropShelfHotkeyKeyCode = UInt32(defaults.integer(forKey: "dropShelfHotkeyKeyCode"))
        dropShelfHotkeyModifiers = UInt32(defaults.integer(forKey: "dropShelfHotkeyModifiers"))
        dropShelfAutoDismiss = defaults.bool(forKey: "dropShelfAutoDismiss")
        overlayPlacement = OverlayPlacement(rawValue: defaults.string(forKey: "overlayPlacement") ?? "") ?? .pointerScreen
        showMenuBarIcon = defaults.bool(forKey: "showMenuBarIcon")
        maxItems = defaults.integer(forKey: "maxItems")
        retention = Retention(rawValue: defaults.string(forKey: "retention") ?? "") ?? .forever
        captureText = defaults.bool(forKey: "captureText")
        captureImages = defaults.bool(forKey: "captureImages")
        captureFiles = defaults.bool(forKey: "captureFiles")
        captureScreenshots = defaults.bool(forKey: "captureScreenshots")
        maxImageMB = defaults.integer(forKey: "maxImageMB")
        returnAction = ReturnAction(rawValue: defaults.string(forKey: "returnAction") ?? "") ?? .paste
        pastePlainTextByDefault = defaults.bool(forKey: "pastePlainTextByDefault")
        trimWhitespace = defaults.bool(forKey: "trimWhitespace")
        promoteOnUse = defaults.bool(forKey: "promoteOnUse")
        showQuickIndexBadges = defaults.bool(forKey: "showQuickIndexBadges")
        ignoredApps = defaults.stringArray(forKey: "ignoredApps") ?? []
        ignoreSecrets = defaults.bool(forKey: "ignoreSecrets")
        pausedUntil = defaults.object(forKey: "pausedUntil") as? Date
        customScreenshotFolder = defaults.string(forKey: "customScreenshotFolder")

        if let until = pausedUntil, until <= Date() { pausedUntil = nil }
        schedulePauseExpiry()
    }

    // MARK: Pause

    public var isPaused: Bool {
        guard let until = pausedUntil else { return false }
        return until > Date()
    }

    public func pause(for interval: TimeInterval?) {
        pausedUntil = interval.map { Date().addingTimeInterval($0) } ?? .distantFuture
        schedulePauseExpiry()
    }

    public func resume() {
        pausedUntil = nil
        pauseTimer?.invalidate()
    }

    public var pauseDescription: String? {
        guard isPaused, let until = pausedUntil else { return nil }
        if until == .distantFuture { return "Paused until you resume" }
        let f = DateFormatter()
        f.timeStyle = .short
        return "Paused until \(f.string(from: until))"
    }

    private func schedulePauseExpiry() {
        pauseTimer?.invalidate()
        guard let until = pausedUntil, until != .distantFuture else { return }
        let t = Timer(fire: until, interval: 0, repeats: false) { [weak self] _ in
            self?.pausedUntil = nil
        }
        RunLoop.main.add(t, forMode: .common)
        pauseTimer = t
    }

    // MARK: Helpers

    public var maxImageBytes: Int64? {
        maxImageMB > 0 ? Int64(maxImageMB) * 1_048_576 : nil
    }

    public var hotkeyDisplay: String {
        HotkeyFormatter.string(keyCode: hotkeyKeyCode, modifiers: hotkeyModifiers)
    }

    public var dropShelfHotkeyDisplay: String {
        HotkeyFormatter.string(keyCode: dropShelfHotkeyKeyCode, modifiers: dropShelfHotkeyModifiers)
    }

    public func isIgnored(bundleID: String?) -> Bool {
        guard let id = bundleID else { return false }
        return ignoredApps.contains(id)
    }
}

/// Turns Carbon key codes/modifiers into "⌥⌘V" style labels using the current keyboard layout.
public enum HotkeyFormatter {
    public static func string(keyCode: UInt32, modifiers: UInt32) -> String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + keyName(keyCode)
    }

    static func keyName(_ keyCode: UInt32) -> String {
        let special: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_Escape: "esc",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12"
        ]
        if let name = special[Int(keyCode)] { return name }
        return KeyboardLayout.character(for: CGKeyCode(keyCode))?.uppercased() ?? "#\(keyCode)"
    }

    /// Converts NSEvent modifier flags to Carbon modifier bits.
    public static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }
}

/// Recognises copied passwords, API keys and private keys so they are not stored.
enum SecretDetector {
    private static let prefixes = [
        "sk-", "sk_live_", "sk_test_", "pk_live_", "rk_live_", "ghp_", "gho_", "ghu_", "ghs_", "github_pat_",
        "glpat-", "xoxb-", "xoxp-", "xoxa-", "AKIA", "ASIA", "AIza", "ya29.", "SG.", "npm_", "pypi-", "hf_"
    ]

    static func looksSecret(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.contains("-----BEGIN") && t.contains("PRIVATE KEY") { return true }
        // Secrets are single tokens.
        guard !t.isEmpty, t.count <= 200, !t.contains(where: { $0.isWhitespace }) else { return false }
        if t.hasPrefix("http://") || t.hasPrefix("https://") || t.contains("/") && t.contains(".") { return false }
        if prefixes.contains(where: { t.hasPrefix($0) }) && t.count >= 16 { return true }
        // JWT
        if t.hasPrefix("eyJ") && t.split(separator: ".").count == 3 && t.count > 40 { return true }

        // Password-like: 10–64 chars, mixes at least 3 character classes, no dictionary shape.
        guard (10...64).contains(t.count) else { return false }
        let hasLower = t.contains(where: { $0.isLowercase })
        let hasUpper = t.contains(where: { $0.isUppercase })
        let hasDigit = t.contains(where: { $0.isNumber })
        let hasSymbol = t.contains(where: { !$0.isLetter && !$0.isNumber })
        let classes = [hasLower, hasUpper, hasDigit, hasSymbol].filter { $0 }.count
        guard classes >= 3 else { return false }
        if t.contains("@") && t.contains(".") && !t.contains(where: { "!#$%^&*".contains($0) }) { return false } // email

        // Random-looking strings switch between letters, digits and symbols often
        // (Tr0ub4dor&3, a8F3kD9x…); words and versions (iPhone15Pro, v2.3.1-beta) don't.
        func cls(_ c: Character) -> Int { c.isLetter ? 0 : c.isNumber ? 1 : 2 }
        let chars = Array(t)
        var transitions = 0
        for i in 1..<chars.count where cls(chars[i]) != cls(chars[i - 1]) { transitions += 1 }
        let onlyPunctuation = t.filter { !$0.isLetter && !$0.isNumber }.allSatisfy { "._-".contains($0) }
        // With only . _ - as symbols (identifiers, versions, file names) insist on mixed case too.
        if onlyPunctuation && !(hasLower && hasUpper && hasDigit) { return false }
        return Double(transitions) >= Double(chars.count) / 3.0
    }
}
