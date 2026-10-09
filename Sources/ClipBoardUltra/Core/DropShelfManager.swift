import Cocoa
import Combine

/// Manages the state and operations for the Quick Drop Shelf.
public final class DropShelfManager: ObservableObject {
    public static let shared = DropShelfManager()

    // Active dragging session counter (prevents shake summoning & premature dismissal)
    @Published public private(set) var activeDragSessionCount: Int = 0

    public func incrementDragSession() {
        if Thread.isMainThread {
            activeDragSessionCount += 1
        } else {
            DispatchQueue.main.async { self.activeDragSessionCount += 1 }
        }
    }

    public func decrementDragSession() {
        if Thread.isMainThread {
            activeDragSessionCount = max(0, activeDragSessionCount - 1)
        } else {
            DispatchQueue.main.async { self.activeDragSessionCount = max(0, self.activeDragSessionCount - 1) }
        }
    }

    @Published public private(set) var items: [DropShelfItem] = [] {
        didSet {
            let hasItems = !items.isEmpty
            if hasItems != (!oldValue.isEmpty) {
                // If items became empty and autoDismiss is enabled, skip updateSize resize animation
                // to prevent collision with DropShelfPanel.hide()
                let willAutoDismiss = !hasItems && SettingsStore.shared.dropShelfAutoDismiss
                if !willAutoDismiss {
                    if Thread.isMainThread {
                        DropShelfPanel.shared.updateSize(hasItems: hasItems)
                    } else {
                        DispatchQueue.main.async {
                            DropShelfPanel.shared.updateSize(hasItems: hasItems)
                        }
                    }
                }
            }
        }
    }
    @Published public var isTargetHighlighted: Bool = false
    @Published public private(set) var isVisible: Bool = false

    private init() {}

    /// Adds one or more file URLs to the shelf. Ignores duplicates.
    public func addFiles(_ urls: [URL]) {
        let validURLs = urls.filter { $0.isFileURL && FileManager.default.fileExists(atPath: $0.path) }
        guard !validURLs.isEmpty else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var addedCount = 0
            for url in validURLs {
                if !self.items.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
                    self.items.append(DropShelfItem(url: url))
                    addedCount += 1
                }
            }

            if addedCount > 0 {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                if !self.isVisible {
                    self.show()
                }
            }
        }
    }

    /// Removes an item by its UUID.
    public func removeItem(id: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.items.removeAll { $0.id == id }
            self.checkAutoDismiss()
        }
    }

    /// Removes items that were successfully dragged out to another destination.
    public func removeItems(matching urls: [URL]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let normalized = Set(urls.map { $0.standardizedFileURL.path })
            self.items.removeAll { normalized.contains($0.url.standardizedFileURL.path) }
            self.checkAutoDismiss()
        }
    }

    /// Clears all files in the shelf and dismisses if configured.
    public func clearAll() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.items.removeAll()
            self.checkAutoDismiss()
        }
    }

    private func checkAutoDismiss() {
        if items.isEmpty && SettingsStore.shared.dropShelfAutoDismiss {
            dismiss()
        }
    }

    public func show(near point: NSPoint? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isVisible = true
            DropShelfPanel.shared.show(near: point)
        }
    }

    public func dismiss() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isVisible = false
            DropShelfPanel.shared.hide()
        }
    }

    public func toggle(near point: NSPoint? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isVisible {
                self.dismiss()
            } else {
                self.show(near: point)
            }
        }
    }
}
