import Cocoa
import SwiftUI

/// Custom NSPanel hosting the Quick Drop Shelf.
public final class DropShelfPanel: NSPanel {
    public static let shared = DropShelfPanel()

    public static let emptySize = NSSize(width: 260, height: 200)
    public static let filledSize = NSSize(width: 300, height: 320)
    private var dropHostingView: DropShelfHostingView?

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

        setupView()
    }

    private func setupView() {
        let rootView = DropShelfView()
        let hostingView = DropShelfHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: Self.emptySize)
        hostingView.autoresizingMask = [.width, .height]
        self.dropHostingView = hostingView
        self.contentView = hostingView
    }

    public func updateSize(hasItems: Bool, animated: Bool = true) {
        let targetSize = hasItems ? Self.filledSize : Self.emptySize
        let currentOrigin = frame.origin
        let currentMaxY = frame.maxY
        let newOrigin = NSPoint(x: currentOrigin.x, y: currentMaxY - targetSize.height)
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

    public func show(near point: NSPoint? = nil) {
        let hasItems = !DropShelfManager.shared.items.isEmpty
        let panelSize = hasItems ? Self.filledSize : Self.emptySize

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
        DispatchQueue.main.async {
            DropShelfManager.shared.isTargetHighlighted = true
        }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let urls = extractURLs(from: sender), !urls.isEmpty else { return [] }
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        DispatchQueue.main.async {
            DropShelfManager.shared.isTargetHighlighted = false
        }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        DispatchQueue.main.async {
            DropShelfManager.shared.isTargetHighlighted = false
        }
        guard let urls = extractURLs(from: sender), !urls.isEmpty else { return false }
        DispatchQueue.main.async {
            DropShelfManager.shared.addFiles(urls)
        }
        return true
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
