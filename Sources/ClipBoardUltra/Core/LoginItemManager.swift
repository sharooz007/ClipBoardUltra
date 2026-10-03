import Foundation
import ServiceManagement

/// Registers ClipBoardUltra as a login item (System Settings › General › Login Items).
public final class LoginItemManager {
    public static let shared = LoginItemManager()
    private let configuredKey = "didConfigureLoginItem"

    private init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// On first launch, turn "Open at Login" on. After that the user's choice is respected.
    public func enableOnFirstLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: configuredKey) else { return }
        if setEnabled(true) {
            defaults.set(true, forKey: configuredKey)
        }
    }

    @discardableResult
    public func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                try SMAppService.mainApp.unregister()
            }
            print("[LoginItem] Open at login = \(enabled) (status \(SMAppService.mainApp.status.rawValue))")
            return true
        } catch {
            print("[LoginItem] Could not change login item: \(error.localizedDescription)")
            return false
        }
    }
}
