import Cocoa
import SwiftUI
import Combine

/// Custom NSPanel hosting the Quick Drop Shelf.
public final class DropShelfPanel: NSPanel {
    public static let shared = DropShelfPanel()

    public static let panelHeight: CGFloat = 230.0

    public static func width(forFolderCount count: Int) -> CGFloat {
        switch count {
        case 0: return 240
        case 1: return 300
        case 2: return 490
        case 3: return 680
        default: return 770
        }
    }

    public static var emptySize: NSSize {
        NSSize(width: width(forFolderCount: 0), height: panelHeight)
    }

    public static var filledSize: NSSize {
        NSSize(width: width(forFolderCount: 1), height: panelHeight)
    }

    private var dropHostingView: DropShelfHostingView?
    private var themeCancellable: AnyCancellable?

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }

    private init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.emptySize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false

        updateAppearance(for: SettingsStore.shared.appTheme)
        themeCancellable = SettingsStore.shared.$appTheme
            .sink { [weak self] theme in
                self?.updateAppearance(for: theme)
            }

        setupView()
    }

    private func updateAppearance(for theme: SettingsStore.AppTheme) {
        switch theme {
        case .liquidGlass:
            self.appearance = nil
        case .tactileDesk:
            self.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func setupView() {
        let rootView = DropShelfView()
        let hostingView = DropShelfHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: Self.emptySize)
        hostingView.autoresizingMask = [.width, .height]
        self.dropHostingView = hostingView
        self.contentView = hostingView
    }

    public func updateSize(folderCount: Int, animated: Bool = true) {
        let targetWidth = Self.width(forFolderCount: folderCount)
        let targetSize = NSSize(width: targetWidth, height: Self.panelHeight)

        let currentOrigin = frame.origin
        let currentMaxY = frame.maxY

        // Screen visible boundary clamping
        let screen = NSScreen.screens.first { NSMouseInRect(currentOrigin, $0.frame, false) } ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        var newX = currentOrigin.x
        if newX + targetSize.width > screenFrame.maxX - 10 {
            newX = screenFrame.maxX - targetSize.width - 10
        }
        if newX < screenFrame.minX + 10 {
            newX = screenFrame.minX + 10
        }

        let newOrigin = NSPoint(x: newX, y: currentMaxY - targetSize.height)
        let newFrame = NSRect(origin: newOrigin, size: targetSize)

        if animated && isVisible {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(newFrame, display: true)
            }
        } else {
            setFrame(newFrame, display: true)
        }
    }

    public func updateSize(hasItems: Bool, animated: Bool = true) {
        updateSize(folderCount: DropShelfManager.shared.folders.count, animated: animated)
    }

    public func show(near point: NSPoint? = nil) {
        let folderCount = DropShelfManager.shared.folders.count
        let panelWidth = Self.width(forFolderCount: folderCount)
        let panelSize = NSSize(width: panelWidth, height: Self.panelHeight)

        let targetPoint = point ?? NSEvent.mouseLocation

        // Locate screen containing the target point
        let screen = NSScreen.screens.first { NSMouseInRect(targetPoint, $0.frame, false) } ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        // Offset slightly from cursor so it doesn't block immediate dragging
        var originX = targetPoint.x + 24
        var originY = targetPoint.y - panelSize.height + 24

        // Clamp inside screen bounds
        if originX + panelSize.width > screenFrame.maxX - 10 {
            originX = targetPoint.x - panelSize.width - 24
        }
        if originX < screenFrame.minX + 10 {
            originX = screenFrame.minX + 10
        }

        if originY < screenFrame.minY + 10 {
            originY = screenFrame.minY + 10
        }
        if originY + panelSize.height > screenFrame.maxY - 10 {
            originY = screenFrame.maxY - panelSize.height - 10
        }

        setFrame(NSRect(origin: NSPoint(x: originX, y: originY), size: panelSize), display: true)

        alphaValue = 1
        orderFrontRegardless()
    }

    public func hide() {
        guard isVisible else { return }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1
        })
    }
}

/// NSHostingView subclass that registers and handles incoming file drops from Finder.
final class DropShelfHostingView: NSHostingView<DropShelfView> {
    required init(rootView: DropShelfView) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL, NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let urls = extractURLs(from: sender), !urls.isEmpty else { return [] }
        updateHoverState(for: sender)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let urls = extractURLs(from: sender), !urls.isEmpty else { return [] }
        updateHoverState(for: sender)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        DispatchQueue.main.async {
            if DropShelfManager.shared.hoveredFolderIndex != nil {
                DropShelfManager.shared.hoveredFolderIndex = nil
            }
            if DropShelfManager.shared.isTargetHighlighted {
                DropShelfManager.shared.isTargetHighlighted = false
            }
        }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = extractURLs(from: sender), !urls.isEmpty else { return false }
        let targetIndex = DropShelfManager.shared.hoveredFolderIndex

        DropShelfManager.shared.hoveredFolderIndex = nil
        DropShelfManager.shared.isTargetHighlighted = false

        DropShelfManager.shared.addFiles(urls, toFolderIndex: targetIndex)
        return true
    }

    private func updateHoverState(for sender: NSDraggingInfo) {
        let localPoint = convert(sender.draggingLocation, from: nil)
        let folderCount = DropShelfManager.shared.folders.count

        var targetIndex: Int? = nil

        if folderCount == 0 {
            // Entire shelf is a single empty drop target
            targetIndex = nil
        } else if folderCount < DropShelfManager.maxFolders {
            // Folder columns + New Folder slot
            let padLeft: CGFloat = 14
            let padRight: CGFloat = 14
            let slotWidth: CGFloat = 85
            let gap: CGFloat = 10

            let slotLeft = bounds.width - padRight - slotWidth
            if localPoint.x >= slotLeft {
                targetIndex = folderCount // Targets "+ New Folder" slot
            } else {
                let folderAreaWidth = max(1, slotLeft - padLeft - gap)
                let colWidth = folderAreaWidth / CGFloat(folderCount)
                let rawIdx = Int((localPoint.x - padLeft) / colWidth)
                targetIndex = max(0, min(folderCount - 1, rawIdx))
            }
        } else {
            // Exactly 4 folders (no slot)
            let padLeft: CGFloat = 14
            let padRight: CGFloat = 14
            let contentWidth = max(1, bounds.width - padLeft - padRight)
            let colWidth = contentWidth / CGFloat(folderCount)
            let rawIdx = Int((localPoint.x - padLeft) / colWidth)
            targetIndex = max(0, min(folderCount - 1, rawIdx))
        }

        // Prevent 120Hz micro-redraw flood by assigning only on actual change
        if DropShelfManager.shared.hoveredFolderIndex != targetIndex {
            DropShelfManager.shared.hoveredFolderIndex = targetIndex
        }
        if !DropShelfManager.shared.isTargetHighlighted {
            DropShelfManager.shared.isTargetHighlighted = true
        }
    }

    private func extractURLs(from sender: NSDraggingInfo) -> [URL]? {
        let pboard = sender.draggingPasteboard
        if let items = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !items.isEmpty {
            return items.filter { $0.isFileURL }
        }
        if let filenames = pboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? [String] {
            return filenames.map { URL(fileURLWithPath: $0) }
        }
        return nil
    }
}
