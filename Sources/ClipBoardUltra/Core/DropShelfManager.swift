import Cocoa
import Combine

/// Manages multi-folder state and operations for the Quick Drop Shelf.
public final class DropShelfManager: ObservableObject {
    public static let shared = DropShelfManager()

    /// Maximum number of active folder stacks supported on the shelf.
    public static let maxFolders: Int = 4

    // Active dragging session counter (prevents shake summoning & premature dismissal)
    @Published public private(set) var activeDragSessionCount: Int = 0

    public func incrementDragSession() {
        runOnMain { self.activeDragSessionCount += 1 }
    }

    public func decrementDragSession() {
        runOnMain { self.activeDragSessionCount = max(0, self.activeDragSessionCount - 1) }
    }

    /// Active folder stacks (maximum 4).
    @Published public private(set) var folders: [DropShelfFolder] = [] {
        didSet {
            let hasFolders = !folders.isEmpty
            let hadFolders = !oldValue.isEmpty
            let willAutoDismiss = !hasFolders && SettingsStore.shared.dropShelfAutoDismiss

            if !willAutoDismiss && (folders.count != oldValue.count || hasFolders != hadFolders) {
                runOnMain {
                    DropShelfPanel.shared.updateSize(folderCount: self.folders.count)
                }
            }
        }
    }

    /// Backward-compatibility: flattened array of all items across all active folders.
    public var items: [DropShelfItem] {
        folders.flatMap { $0.items }
    }

    /// Tracks which folder column (or New Folder slot) is currently hovered during incoming drag.
    /// `0 ..< folders.count`: Existing folder index
    /// `folders.count`: "+ New Folder" slot
    /// `nil`: No column hovered
    @Published public var hoveredFolderIndex: Int? = nil

    /// Backward compatibility flag for overall drop shelf highlight
    @Published public var isTargetHighlighted: Bool = false

    @Published public private(set) var isVisible: Bool = false

    private init() {}

    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    /// Adds one or more file URLs to a specific folder index or a new folder. Ignores duplicates within the folder.
    public func addFiles(_ urls: [URL], toFolderIndex: Int? = nil) {
        let validURLs = urls.filter { $0.isFileURL && FileManager.default.fileExists(atPath: $0.path) }
        guard !validURLs.isEmpty else { return }

        runOnMain { [weak self] in
            guard let self = self else { return }
            var addedCount = 0

            // Determine target folder index
            let isNewFolderTarget = (toFolderIndex == self.folders.count) || (toFolderIndex == nil && self.folders.isEmpty)

            if isNewFolderTarget && self.folders.count < Self.maxFolders {
                // Create a new folder
                let folderNumber = self.folders.count + 1
                let folderName = "Folder \(folderNumber)"
                let newItems = validURLs.map { DropShelfItem(url: $0) }
                self.folders.append(DropShelfFolder(name: folderName, items: newItems))
                addedCount += newItems.count
            } else if !self.folders.isEmpty {
                let targetIdx = min(max(0, toFolderIndex ?? 0), self.folders.count - 1)
                for url in validURLs {
                    if !self.folders[targetIdx].items.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
                        self.folders[targetIdx].items.append(DropShelfItem(url: url))
                        addedCount += 1
                    }
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

    /// Renames a folder.
    public func renameFolder(id: UUID, newName: String) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            if let idx = self.folders.firstIndex(where: { $0.id == id }) {
                let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    self.folders[idx].name = trimmed
                }
            }
        }
    }

    /// Removes an item by UUID from a specific folder.
    public func removeItem(id: UUID, fromFolderId: UUID) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            if let folderIdx = self.folders.firstIndex(where: { $0.id == fromFolderId }) {
                self.folders[folderIdx].items.removeAll { $0.id == id }
                if self.folders[folderIdx].items.isEmpty {
                    self.folders.remove(at: folderIdx)
                }
            }
            self.checkAutoDismiss()
        }
    }

    /// Backward compatibility: removes an item by UUID across whichever folder contains it.
    public func removeItem(id: UUID) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            for folderIdx in self.folders.indices.reversed() {
                self.folders[folderIdx].items.removeAll { $0.id == id }
                if self.folders[folderIdx].items.isEmpty {
                    self.folders.remove(at: folderIdx)
                }
            }
            self.checkAutoDismiss()
        }
    }

    /// Removes items that were successfully dragged out of a folder.
    public func removeItems(matching urls: [URL], fromFolderId: UUID) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            let normalized = Set(urls.map { $0.standardizedFileURL.path })
            if let folderIdx = self.folders.firstIndex(where: { $0.id == fromFolderId }) {
                self.folders[folderIdx].items.removeAll { normalized.contains($0.url.standardizedFileURL.path) }
                if self.folders[folderIdx].items.isEmpty {
                    self.folders.remove(at: folderIdx)
                }
            }
            self.checkAutoDismiss()
        }
    }

    /// Backward compatibility: removes items across all folders matching URLs.
    public func removeItems(matching urls: [URL]) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            let normalized = Set(urls.map { $0.standardizedFileURL.path })
            for folderIdx in self.folders.indices.reversed() {
                self.folders[folderIdx].items.removeAll { normalized.contains($0.url.standardizedFileURL.path) }
                if self.folders[folderIdx].items.isEmpty {
                    self.folders.remove(at: folderIdx)
                }
            }
            self.checkAutoDismiss()
        }
    }

    /// Removes an entire folder by its UUID.
    public func removeFolder(id: UUID) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            self.folders.removeAll { $0.id == id }
            self.checkAutoDismiss()
        }
    }

    /// Clears all files in all folders.
    public func clearAll() {
        runOnMain { [weak self] in
            guard let self = self else { return }
            self.folders.removeAll()
            self.checkAutoDismiss()
        }
    }

    private func checkAutoDismiss() {
        if folders.isEmpty && SettingsStore.shared.dropShelfAutoDismiss {
            dismiss()
        }
    }

    public func show(near point: NSPoint? = nil) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            self.isVisible = true
            DropShelfPanel.shared.show(near: point)
        }
    }

    public func dismiss() {
        runOnMain { [weak self] in
            guard let self = self else { return }
            self.isVisible = false
            DropShelfPanel.shared.hide()
        }
    }

    public func toggle(near point: NSPoint? = nil) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            if self.isVisible {
                self.dismiss()
            } else {
                self.show(near: point)
            }
        }
    }
}
