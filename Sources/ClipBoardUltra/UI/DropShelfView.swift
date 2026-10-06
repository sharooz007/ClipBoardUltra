import Cocoa
import SwiftUI

/// Main visual interface for the Quick Drop Shelf.
public struct DropShelfView: View {
    @ObservedObject private var manager = DropShelfManager.shared
    @State private var isHoveringClose = false

    public init() {}

    public var body: some View {
        ZStack {
            // Background Chassis with frosted glass effect
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

            VStack(spacing: 0) {
                // Header Bar
                headerView
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                Divider()
                    .background(Theme.chassisTop.opacity(0.6))

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
        HStack(spacing: 8) {
            // Glowing Indicator Dot
            Circle()
                .fill(manager.items.isEmpty ? Theme.amber : Theme.orange)
                .frame(width: 7, height: 7)
                .shadow(color: (manager.items.isEmpty ? Theme.amber : Theme.orange).opacity(0.6), radius: 4)

            Text("DROP SHELF")
                .font(Theme.mono(10, .bold))
                .foregroundColor(Theme.bone)
                .tracking(0.5)

            Spacer()

            if !manager.items.isEmpty {
                Text("\(manager.items.count) \(manager.items.count == 1 ? "FILE" : "FILES")")
                    .font(Theme.mono(9, .semibold))
                    .foregroundColor(Theme.amber)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Theme.chassisLow)
                    )
            }

            // Close / Dismiss Button
            Button {
                manager.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isHoveringClose ? Theme.bone : Theme.boneDim)
                    .frame(width: 18, height: 18)
                    .background(
                        Circle().fill(isHoveringClose ? Theme.chassisTop : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isHoveringClose = $0 }
        }
    }

    // MARK: - Empty State
    private var emptyDropZone: some View {
        VStack(spacing: 8) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        manager.isTargetHighlighted ? Theme.orange : Theme.boneDim.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(manager.isTargetHighlighted ? Theme.orange.opacity(0.08) : Theme.chassisLow.opacity(0.4))
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .padding(.horizontal, 12)

                VStack(spacing: 6) {
                    Image(systemName: manager.isTargetHighlighted ? "arrow.down.circle.fill" : "tray.and.arrow.down")
                        .font(.system(size: 24))
                        .foregroundColor(manager.isTargetHighlighted ? Theme.orange : Theme.amber)

                    Text(manager.isTargetHighlighted ? "Release to drop" : "Drop files here")
                        .font(Theme.mono(12, .semibold))
                        .foregroundColor(Theme.bone)

                    Text("Shake while dragging to summon")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.boneDim.opacity(0.7))
                }
            }

            Spacer()
        }
        .padding(.bottom, 6)
    }

    // MARK: - Filled State with Accumulated Items
    private var filledContent: some View {
        VStack(spacing: 8) {
            // Scrollable Items List
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

            Divider()
                .background(Theme.chassisTop.opacity(0.6))

            // Bottom Actions: Drag All Bar & Clear
            HStack(spacing: 8) {
                // Clear all button
                Button {
                    manager.clearAll()
                } label: {
                    Text("Clear")
                        .font(Theme.mono(10, .medium))
                        .foregroundColor(Theme.boneDim)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Theme.chassisLow)
                        )
                }
                .buttonStyle(.plain)

                // Drag All Keycap Button (AppKit Native Drag Source)
                DragAllSourceView(
                    urls: manager.items.map { $0.url },
                    title: "Drag All to Destination (\(manager.items.count))",
                    onSuccess: { droppedURLs in
                        manager.removeItems(matching: droppedURLs)
                    }
                )
                .frame(height: 28)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
    }

    private func itemRow(_ item: DropShelfItem) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: item.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.bone)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(item.formattedSize)
                    .font(Theme.mono(9, .regular))
                    .foregroundColor(Theme.boneDim)
            }

            Spacer()

            // Individual drag handle
            SingleItemDragSourceView(url: item.url) {
                manager.removeItem(id: item.id)
            }
            .frame(width: 22, height: 22)

            // Remove button
            Button {
                manager.removeItem(id: item.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Theme.boneDim.opacity(0.8))
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(Theme.chassisLow))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.chassisLow.opacity(0.7))
        )
    }
}

// MARK: - Native AppKit Drag Source for Dragging All Items Out
struct DragAllSourceView: NSViewRepresentable {
    var urls: [URL]
    var title: String
    var onSuccess: ([URL]) -> Void

    func makeNSView(context: Context) -> DragAllButtonNSView {
        let view = DragAllButtonNSView()
        view.urls = urls
        view.title = title
        view.onSuccess = onSuccess
        return view
    }

    func updateNSView(_ nsView: DragAllButtonNSView, context: Context) {
        nsView.urls = urls
        nsView.title = title
        nsView.onSuccess = onSuccess
        nsView.needsDisplay = true
    }
}

final class DragAllButtonNSView: NSView, NSDraggingSource {
    var urls: [URL] = []
    var title: String = ""
    var onSuccess: (([URL]) -> Void)?

    private var isHighlighted: Bool = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let cornerRadius: CGFloat = 6.0
        let bgPath = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)

        // Safety-orange background
        let baseColor = isHighlighted ? NSColor(red: 1.0, green: 0.45, blue: 0.1, alpha: 1.0) : NSColor(red: 0.95, green: 0.38, blue: 0.08, alpha: 1.0)
        baseColor.setFill()
        bgPath.fill()

        // Border
        NSColor(white: 1.0, alpha: 0.15).setStroke()
        bgPath.lineWidth = 1.0
        bgPath.stroke()

        // Text & Icon
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]

        let fullText = "⇥ \(title)"
        let str = NSAttributedString(string: fullText, attributes: attrs)
        let strSize = str.size()
        let textRect = NSRect(
            x: 0,
            y: (bounds.height - strSize.height) / 2 - 1,
            width: bounds.width,
            height: strSize.height
        )
        str.draw(in: textRect)
    }

    override func mouseDown(with event: NSEvent) {
        isHighlighted = true
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isHighlighted = false
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard !urls.isEmpty else { return }
        isHighlighted = false
        needsDisplay = true

        var draggingItems: [NSDraggingItem] = []
        for url in urls {
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            let iconRect = NSRect(x: bounds.midX - 16, y: bounds.midY - 16, width: 32, height: 32)
            item.setDraggingFrame(iconRect, contents: icon)
            draggingItems.append(item)
        }

        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return [.copy, .move, .generic]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if operation != [] {
            DispatchQueue.main.async {
                self.onSuccess?(self.urls)
            }
        }
    }
}

// MARK: - Native Drag Source for Individual Item
struct SingleItemDragSourceView: NSViewRepresentable {
    var url: URL
    var onSuccess: () -> Void

    func makeNSView(context: Context) -> SingleItemDragNSView {
        let view = SingleItemDragNSView()
        view.url = url
        view.onSuccess = onSuccess
        return view
    }

    func updateNSView(_ nsView: SingleItemDragNSView, context: Context) {
        nsView.url = url
        nsView.onSuccess = onSuccess
    }
}

final class SingleItemDragNSView: NSView, NSDraggingSource {
    var url: URL?
    var onSuccess: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw small grab handle icon (three horizontal dots or grip)
        let handleColor = NSColor(white: 0.6, alpha: 0.8)
        handleColor.setFill()

        let dotSize: CGFloat = 3.0
        let spacing: CGFloat = 2.5
        let startY = (bounds.height - (dotSize * 3 + spacing * 2)) / 2
        let startX = (bounds.width - dotSize) / 2

        for i in 0..<3 {
            let y = startY + CGFloat(i) * (dotSize + spacing)
            let rect = NSRect(x: startX, y: y, width: dotSize, height: dotSize)
            NSBezierPath(ovalIn: rect).fill()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let url = url else { return }

        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        let iconRect = NSRect(x: bounds.midX - 16, y: bounds.midY - 16, width: 32, height: 32)
        item.setDraggingFrame(iconRect, contents: icon)

        let session = beginDraggingSession(with: [item], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return [.copy, .move, .generic]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if operation != [] {
            DispatchQueue.main.async {
                self.onSuccess?()
            }
        }
    }
}
