import Cocoa
import SwiftUI

/// Main visual interface for the Quick Drop Shelf.
public struct DropShelfView: View {
    @ObservedObject private var manager = DropShelfManager.shared
    @ObservedObject private var settings = SettingsStore.shared
    @State private var isHoveringClose = false

    private var isLiquidGlass: Bool { settings.appTheme == .liquidGlass }

    public init() {}

    public var body: some View {
        ZStack {
            // Background Chassis
            if isLiquidGlass {
                ZStack {
                    if SystemGlassObserver.shared.reduceTransparency {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(nsColor: .windowBackgroundColor))
                    } else {
                        NativeGlassBackdrop(cornerRadius: 16, style: .regular)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.18 + 0.60 * SystemGlassObserver.shared.glassTintAmount)
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.06 + 0.22 * SystemGlassObserver.shared.glassTintAmount))
                        VStack {
                            TopRoundedCorners(radius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.20 - 0.08 * SystemGlassObserver.shared.glassTintAmount),
                                            Color.white.opacity(0.04),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: 38)
                                .allowsHitTesting(false)
                            Spacer()
                        }
                    }
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            manager.isTargetHighlighted
                                ? LinearGradient(colors: [LiquidGlass.accent, LiquidGlass.accent], startPoint: .top, endPoint: .bottom)
                                : LiquidGlass.specularRim,
                            lineWidth: manager.isTargetHighlighted ? 2 : 1
                        )
                }
                .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 8)
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.chassis.opacity(0.88))
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                manager.isTargetHighlighted
                                    ? Theme.orange.opacity(0.9)
                                    : Theme.boneDim.opacity(0.25),
                                lineWidth: manager.isTargetHighlighted ? 2 : 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.45), radius: 14, x: 0, y: 6)
            }

            VStack(spacing: 0) {
                // Header Bar
                headerView
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                Divider()
                    .background(isLiquidGlass ? Color.primary.opacity(0.08) : Theme.chassisTop.opacity(0.6))

                // Content Area
                if manager.items.isEmpty {
                    emptyDropZone
                } else {
                    filledContent
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: manager.items.count)
        .animation(.easeInOut(duration: 0.15), value: manager.isTargetHighlighted)
    }

    // MARK: - Header
    private var headerView: some View {
        let accentColor: Color = isLiquidGlass
            ? (manager.items.isEmpty ? LiquidGlass.accent : Color.green)
            : (manager.items.isEmpty ? Theme.amber : Theme.orange)

        return HStack(spacing: 8) {
            // Glowing Indicator Dot
            Circle()
                .fill(accentColor)
                .frame(width: 7, height: 7)
                .shadow(color: accentColor.opacity(0.6), radius: 4)

            Text("DROP SHELF")
                .font(isLiquidGlass ? .system(size: 10, weight: .bold, design: .rounded) : Theme.mono(10, .bold))
                .foregroundColor(isLiquidGlass ? .primary : Theme.bone)
                .tracking(0.5)

            Spacer()

            if !manager.items.isEmpty {
                Text("\(manager.items.count) \(manager.items.count == 1 ? "FILE" : "FILES")")
                    .font(isLiquidGlass ? .system(size: 9.5, weight: .bold, design: .rounded) : Theme.mono(9, .semibold))
                    .foregroundColor(isLiquidGlass ? LiquidGlass.accent : Theme.amber)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isLiquidGlass ? Color.primary.opacity(0.06) : Theme.chassisLow)
                    )
            }

            // Close / Dismiss Button
            Button {
                manager.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isHoveringClose ? (isLiquidGlass ? .primary : Theme.bone) : (isLiquidGlass ? .secondary : Theme.boneDim))
                    .frame(width: 18, height: 18)
                    .background(
                        Circle().fill(isHoveringClose ? (isLiquidGlass ? Color.primary.opacity(0.1) : Theme.chassisTop) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isHoveringClose = $0 }
        }
    }

    // MARK: - Empty State
    private var emptyDropZone: some View {
        let highlightColor: Color = isLiquidGlass ? LiquidGlass.accent : Theme.orange
        let primaryColor: Color = isLiquidGlass ? LiquidGlass.accent : Theme.amber

        return VStack(spacing: 8) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        manager.isTargetHighlighted ? highlightColor : (isLiquidGlass ? Color.white.opacity(0.2) : Theme.boneDim.opacity(0.35)),
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(manager.isTargetHighlighted ? highlightColor.opacity(0.12) : (isLiquidGlass ? Color.primary.opacity(0.02) : Theme.chassisLow.opacity(0.4)))
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .padding(.horizontal, 12)

                VStack(spacing: 6) {
                    Image(systemName: manager.isTargetHighlighted ? "arrow.down.circle.fill" : "tray.and.arrow.down")
                        .font(.system(size: 24))
                        .foregroundColor(manager.isTargetHighlighted ? highlightColor : primaryColor)

                    Text(manager.isTargetHighlighted ? "Release to drop" : "Drop files here")
                        .font(isLiquidGlass ? .system(size: 12, weight: .semibold) : Theme.mono(12, .semibold))
                        .foregroundColor(isLiquidGlass ? .primary : Theme.bone)

                    Text("Shake while dragging to summon")
                        .font(.system(size: 10))
                        .foregroundColor(isLiquidGlass ? .secondary : Theme.boneDim.opacity(0.7))
                }
            }

            Spacer()
        }
        .padding(.bottom, 6)
    }

    // MARK: - Filled State with Accumulated Items
    private var filledContent: some View {
        VStack(spacing: 0) {
            // Scrollable Items List (Takes flexible height up to maximum when there are many items)
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 4) {
                    ForEach(manager.items) { item in
                        itemRow(item)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
            .frame(maxHeight: manager.items.count > 3 ? 140 : CGFloat(manager.items.count * 40 + 12))

            // Interactive Staging Space: fills all remaining space in the shelf
            ShelfSpaceDragView(
                items: manager.items,
                isLiquidGlass: isLiquidGlass,
                onSuccess: { droppedURLs in
                    manager.removeItems(matching: droppedURLs)
                }
            )
            .frame(minHeight: 40)
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider()
                .background(isLiquidGlass ? Color.primary.opacity(0.08) : Theme.chassisTop.opacity(0.6))

            // Clean Footer Bar
            HStack {
                if isLiquidGlass {
                    Button {
                        manager.clearAll()
                    } label: {
                        Text("Clear")
                    }
                    .buttonStyle(GlassPillStyle(tone: .destructive, compact: true))
                } else {
                    Button {
                        manager.clearAll()
                    } label: {
                        Text("Clear")
                            .font(Theme.mono(10, .medium))
                            .foregroundColor(Theme.boneDim)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Theme.chassisLow)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text("Drag card or space to drop")
                    .font(isLiquidGlass ? .system(size: 10, weight: .medium) : Theme.mono(9, .regular))
                    .foregroundColor(isLiquidGlass ? .secondary : Theme.boneDim.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Item Row with Full Card Drag & Isolated Dismiss
    private func itemRow(_ item: DropShelfItem) -> some View {
        HStack(spacing: 8) {
            // Draggable Card Body (NSViewRepresentable overlay strictly over content)
            ZStack {
                HStack(spacing: 8) {
                    Image(nsImage: item.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isLiquidGlass ? .primary : Theme.bone)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Text(item.formattedSize)
                            .font(isLiquidGlass ? .system(size: 9.5) : Theme.mono(9, .regular))
                            .foregroundColor(isLiquidGlass ? .secondary : Theme.boneDim)
                    }

                    Spacer()
                }

                // Native Drag Interceptor covering card content
                ItemCardDragSourceView(item: item) {
                    manager.removeItem(id: item.id)
                }
            }

            // Independent Dismiss Button (outside drag hit-testing bounds)
            Button {
                manager.removeItem(id: item.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(isLiquidGlass ? .secondary : Theme.boneDim.opacity(0.8))
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(isLiquidGlass ? Color.primary.opacity(0.08) : Theme.chassisLow))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isLiquidGlass ? Color.primary.opacity(0.035) : Theme.chassisLow.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isLiquidGlass ? Color.white.opacity(0.12) : Color.clear, lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Native AppKit Drag Source for Single Item
struct ItemCardDragSourceView: NSViewRepresentable {
    var item: DropShelfItem
    var onSuccess: () -> Void

    func makeNSView(context: Context) -> ItemCardDragNSView {
        let view = ItemCardDragNSView()
        view.item = item
        view.onSuccess = onSuccess
        return view
    }

    func updateNSView(_ nsView: ItemCardDragNSView, context: Context) {
        nsView.item = item
        nsView.onSuccess = onSuccess
    }
}

final class ItemCardDragNSView: NSView, NSDraggingSource {
    var item: DropShelfItem?
    var onSuccess: (() -> Void)?

    private var initialMouseDownLocation: NSPoint?
    private var isDragging = false

    // CRITICAL: Block window move hijacking
    override var mouseDownCanMoveWindow: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func mouseDown(with event: NSEvent) {
        initialMouseDownLocation = event.locationInWindow
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isDragging, let initial = initialMouseDownLocation, let item = item else { return }
        let current = event.locationInWindow
        guard hypot(current.x - initial.x, current.y - initial.y) >= 3.0 else { return }

        // Fast disk validation
        guard FileManager.default.fileExists(atPath: item.url.path) else {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            DropShelfManager.shared.removeItem(id: item.id)
            initialMouseDownLocation = nil
            return
        }

        isDragging = true
        DropShelfManager.shared.incrementDragSession()

        let dragItem = NSDraggingItem(pasteboardWriter: item.url as NSURL)
        let mouseInView = convert(event.locationInWindow, from: nil)
        let iconRect = NSRect(x: mouseInView.x - 12, y: mouseInView.y - 12, width: 24, height: 24)
        dragItem.setDraggingFrame(iconRect, contents: item.icon)

        let session = beginDraggingSession(with: [dragItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    override func mouseUp(with event: NSEvent) {
        // Double-click reveals file in Finder
        if !isDragging && event.clickCount == 2, let url = item?.url {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
        initialMouseDownLocation = nil
        isDragging = false
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        switch context {
        case .outsideApplication:
            return [.copy, .generic]
        case .withinApplication:
            return [] // Prevent self-drop deletion
        @unknown default:
            return [.copy]
        }
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        DropShelfManager.shared.decrementDragSession()
        if operation != [] {
            if Thread.isMainThread {
                self.onSuccess?()
            } else {
                DispatchQueue.main.async { self.onSuccess?() }
            }
        }
        isDragging = false
        initialMouseDownLocation = nil
    }
}

// MARK: - Native Staging Cradle Drag Source (Source Only, No Destination Conflict)
struct ShelfSpaceDragView: NSViewRepresentable {
    var items: [DropShelfItem]
    var isLiquidGlass: Bool
    var onSuccess: ([URL]) -> Void

    func makeNSView(context: Context) -> ShelfSpaceDragNSView {
        let view = ShelfSpaceDragNSView()
        view.configure(items: items, isLiquidGlass: isLiquidGlass, onSuccess: onSuccess)
        return view
    }

    func updateNSView(_ nsView: ShelfSpaceDragNSView, context: Context) {
        nsView.configure(items: items, isLiquidGlass: isLiquidGlass, onSuccess: onSuccess)
        nsView.needsDisplay = true
    }
}

final class ShelfSpaceDragNSView: NSView, NSDraggingSource {
    private var items: [DropShelfItem] = []
    private var activeDragURLs: [URL] = []
    private var isLiquidGlass: Bool = false
    private var onSuccess: (([URL]) -> Void)?
    private var isHighlighted: Bool = false
    private var mouseDownPoint: NSPoint?

    // CRITICAL: Block window move hijacking
    override var mouseDownCanMoveWindow: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    func configure(items: [DropShelfItem], isLiquidGlass: Bool, onSuccess: @escaping ([URL]) -> Void) {
        self.items = items
        self.isLiquidGlass = isLiquidGlass
        self.onSuccess = onSuccess
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !items.isEmpty else { return }

        let cornerRadius: CGFloat = isLiquidGlass ? 10.0 : 8.0
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: cornerRadius, yRadius: cornerRadius)
        let isTall = bounds.height >= 65.0

        if isLiquidGlass {
            let accent = NSColor.controlAccentColor
            let bg = isHighlighted ? accent.withAlphaComponent(0.18) : accent.withAlphaComponent(0.06)
            bg.setFill()
            path.fill()

            let strokeColor = isHighlighted ? accent : NSColor.white.withAlphaComponent(0.20)
            strokeColor.setStroke()
            let pattern: [CGFloat] = [4, 4]
            path.setLineDash(pattern, count: 2, phase: 0)
            path.lineWidth = 1.0
            path.stroke()

            if isTall {
                drawTallContent(
                    title: "Drag from space to move all (\(items.count))",
                    subtitle: "or drop more files here",
                    accent: accent,
                    isHighlighted: isHighlighted
                )
            } else {
                drawLabel("⇥  Drag space to move all (\(items.count))", color: isHighlighted ? .white : accent, font: .systemFont(ofSize: 10.5, weight: .semibold))
            }
        } else {
            let bg = isHighlighted ? NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.19, alpha: 1.0) : NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.10, alpha: 1.0)
            bg.setFill()
            path.fill()

            let strokeColor = isHighlighted ? NSColor(calibratedRed: 1.0, green: 0.71, blue: 0.28, alpha: 0.9) : NSColor.white.withAlphaComponent(0.12)
            strokeColor.setStroke()
            let pattern: [CGFloat] = [3, 3]
            path.setLineDash(pattern, count: 2, phase: 0)
            path.lineWidth = 1.0
            path.stroke()

            if isTall {
                drawTallContentTactile(
                    title: "DRAG FROM SPACE TO MOVE ALL (\(items.count))",
                    subtitle: "OR DROP MORE FILES HERE",
                    isHighlighted: isHighlighted
                )
            } else {
                let labelColor = isHighlighted ? NSColor(calibratedRed: 1.0, green: 0.71, blue: 0.28, alpha: 1.0) : NSColor(calibratedRed: 0.89, green: 0.88, blue: 0.84, alpha: 1.0)
                drawLabel("⇥ DRAG SPACE TO MOVE ALL (\(items.count))", color: labelColor, font: .monospacedSystemFont(ofSize: 9.5, weight: .bold))
            }
        }
    }

    private func drawTallContent(title: String, subtitle: String, accent: NSColor, isHighlighted: Bool) {
        let titlePara = NSMutableParagraphStyle()
        titlePara.alignment = .center

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: isHighlighted ? NSColor.white : accent,
            .paragraphStyle: titlePara
        ]
        let titleStr = NSAttributedString(string: title, attributes: titleAttrs)
        let titleSize = titleStr.size()

        let subPara = NSMutableParagraphStyle()
        subPara.alignment = .center
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9.5, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: subPara
        ]
        let subStr = NSAttributedString(string: subtitle, attributes: subAttrs)
        let subSize = subStr.size()

        let iconConfig = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let icon = NSImage(systemSymbolName: "hand.draw", accessibilityDescription: nil)?
            .withSymbolConfiguration(iconConfig)

        let iconHeight: CGFloat = 20
        let spacing: CGFloat = 5
        let totalContentHeight = iconHeight + spacing + titleSize.height + spacing + subSize.height

        var currentY = bounds.midY + totalContentHeight / 2 - iconHeight

        if let icon = icon {
            let iconWidth: CGFloat = 20
            let iconRect = NSRect(x: bounds.midX - iconWidth / 2, y: currentY, width: iconWidth, height: iconHeight)
            let tintColor = isHighlighted ? NSColor.white : accent
            tintColor.set()
            icon.draw(in: iconRect)
        }

        currentY -= (spacing + titleSize.height)
        let titleRect = NSRect(x: 8, y: currentY, width: bounds.width - 16, height: titleSize.height)
        titleStr.draw(in: titleRect)

        currentY -= (spacing + subSize.height)
        let subRect = NSRect(x: 8, y: currentY, width: bounds.width - 16, height: subSize.height)
        subStr.draw(in: subRect)
    }

    private func drawTallContentTactile(title: String, subtitle: String, isHighlighted: Bool) {
        let titlePara = NSMutableParagraphStyle()
        titlePara.alignment = .center

        let amber = NSColor(calibratedRed: 1.0, green: 0.71, blue: 0.28, alpha: 1.0)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .bold),
            .foregroundColor: isHighlighted ? amber : NSColor(calibratedRed: 0.89, green: 0.88, blue: 0.84, alpha: 1.0),
            .paragraphStyle: titlePara
        ]
        let titleStr = NSAttributedString(string: title, attributes: titleAttrs)
        let titleSize = titleStr.size()

        let subPara = NSMutableParagraphStyle()
        subPara.alignment = .center
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 8.5, weight: .regular),
            .foregroundColor: NSColor(calibratedRed: 0.55, green: 0.55, blue: 0.55, alpha: 1.0),
            .paragraphStyle: subPara
        ]
        let subStr = NSAttributedString(string: subtitle, attributes: subAttrs)
        let subSize = subStr.size()

        let iconConfig = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let icon = NSImage(systemSymbolName: "hand.draw", accessibilityDescription: nil)?
            .withSymbolConfiguration(iconConfig)

        let iconHeight: CGFloat = 18
        let spacing: CGFloat = 5
        let totalContentHeight = iconHeight + spacing + titleSize.height + spacing + subSize.height

        var currentY = bounds.midY + totalContentHeight / 2 - iconHeight

        if let icon = icon {
            let iconWidth: CGFloat = 18
            let iconRect = NSRect(x: bounds.midX - iconWidth / 2, y: currentY, width: iconWidth, height: iconHeight)
            let tintColor = isHighlighted ? amber : NSColor(calibratedRed: 0.7, green: 0.7, blue: 0.7, alpha: 1.0)
            tintColor.set()
            icon.draw(in: iconRect)
        }

        currentY -= (spacing + titleSize.height)
        let titleRect = NSRect(x: 8, y: currentY, width: bounds.width - 16, height: titleSize.height)
        titleStr.draw(in: titleRect)

        currentY -= (spacing + subSize.height)
        let subRect = NSRect(x: 8, y: currentY, width: bounds.width - 16, height: subSize.height)
        subStr.draw(in: subRect)
    }

    private func drawLabel(_ text: String, color: NSColor, font: NSFont) {
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        let str = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: para])
        let size = str.size()
        let rect = NSRect(x: 0, y: (bounds.height - size.height) / 2, width: bounds.width, height: size.height)
        str.draw(in: rect)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        isHighlighted = true
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownPoint = nil
        isHighlighted = false
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownPoint, !items.isEmpty else { return }
        let current = convert(event.locationInWindow, from: nil)
        guard hypot(current.x - start.x, current.y - start.y) >= 3.0 else { return }

        isHighlighted = false
        needsDisplay = true
        mouseDownPoint = nil

        // Freeze URLs to avoid deletion of files added mid-drag
        let validItems = items.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        guard !validItems.isEmpty else { return }
        self.activeDragURLs = validItems.map { $0.url }

        DropShelfManager.shared.incrementDragSession()

        let mouseInView = convert(event.locationInWindow, from: nil)
        var draggingItems: [NSDraggingItem] = []
        for (idx, item) in validItems.enumerated() {
            let dragItem = NSDraggingItem(pasteboardWriter: item.url as NSURL)
            // Stagger up to 4 items in compact stack
            let offset = CGFloat(min(idx, 4)) * 3.0
            let iconRect = NSRect(x: mouseInView.x - 16 + offset, y: mouseInView.y - 16 - offset, width: 32, height: 32)
            dragItem.setDraggingFrame(iconRect, contents: item.icon)
            draggingItems.append(dragItem)
        }

        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        switch context {
        case .outsideApplication:
            return [.copy, .generic]
        case .withinApplication:
            return [] // Disallow self-drop
        @unknown default:
            return [.copy]
        }
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        DropShelfManager.shared.decrementDragSession()
        guard operation != [] else { return }
        let dropped = self.activeDragURLs
        if Thread.isMainThread {
            self.onSuccess?(dropped)
        } else {
            DispatchQueue.main.async { self.onSuccess?(dropped) }
        }
    }
}
