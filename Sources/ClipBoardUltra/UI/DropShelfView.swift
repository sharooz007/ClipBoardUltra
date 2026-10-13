import Cocoa
import SwiftUI

/// Main visual interface for the Quick Drop Shelf supporting Multi-Folder Stacks.
public struct DropShelfView: View {
    @ObservedObject private var manager = DropShelfManager.shared
    @ObservedObject private var settings = SettingsStore.shared
    @State private var isHoveringClose = false

    private var isLiquidGlass: Bool { settings.appTheme == .liquidGlass }

    public init() {}

    public var body: some View {
        ZStack {
            // Background Chassis
            chassisBackground

            VStack(spacing: 0) {
                // Header Bar (Permits Window Dragging)
                headerView
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 7)

                Divider()
                    .background(isLiquidGlass ? Color.primary.opacity(0.08) : Theme.chassisTop.opacity(0.6))

                // Content Area: Multi-Folder Columns or Empty Drop Zone
                if manager.folders.isEmpty {
                    emptyDropZone
                } else {
                    multiFolderContent
                }

                Divider()
                    .background(isLiquidGlass ? Color.primary.opacity(0.08) : Theme.chassisTop.opacity(0.6))

                // Clean Footer Bar
                footerView
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: manager.folders.count)
        .animation(.easeInOut(duration: 0.15), value: manager.hoveredFolderIndex)
    }

    // MARK: - Chassis Background
    @ViewBuilder
    private var chassisBackground: some View {
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
    }

    // MARK: - Header View
    private var headerView: some View {
        let accentColor: Color = isLiquidGlass
            ? (manager.folders.isEmpty ? LiquidGlass.accent : Color.green)
            : (manager.folders.isEmpty ? Theme.amber : Theme.orange)

        let totalFiles = manager.items.count

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

            if !manager.folders.isEmpty {
                Text("\(totalFiles) \(totalFiles == 1 ? "FILE" : "FILES") · \(manager.folders.count) \(manager.folders.count == 1 ? "FOLDER" : "FOLDERS")")
                    .font(isLiquidGlass ? .system(size: 9, weight: .bold, design: .rounded) : Theme.mono(8.5, .semibold))
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

    // MARK: - Empty Drop Zone
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
                    .frame(height: 124)
                    .padding(.horizontal, 12)

                VStack(spacing: 6) {
                    Image(systemName: manager.isTargetHighlighted ? "arrow.down.circle.fill" : "tray.and.arrow.down")
                        .font(.system(size: 26))
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

    // MARK: - Multi-Folder Content
    private var multiFolderContent: some View {
        HStack(alignment: .center, spacing: 10) {
            // Render active folder columns
            ForEach(Array(manager.folders.enumerated()), id: \.element.id) { index, folder in
                FolderColumnView(
                    folder: folder,
                    index: index,
                    isLiquidGlass: isLiquidGlass
                )
            }

            // Render rightmost "+ New Folder" slot if under max (4)
            if manager.folders.count < DropShelfManager.maxFolders {
                NewFolderSlotView(
                    isHighlighted: manager.hoveredFolderIndex == manager.folders.count,
                    isLiquidGlass: isLiquidGlass
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Footer View
    private var footerView: some View {
        HStack {
            if isLiquidGlass {
                Button {
                    manager.clearAll()
                } label: {
                    Text("Clear All")
                }
                .buttonStyle(GlassPillStyle(tone: .destructive, compact: true))
            } else {
                Button {
                    manager.clearAll()
                } label: {
                    Text("Clear All")
                        .font(Theme.mono(9.5, .medium))
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

            Text(manager.folders.count < DropShelfManager.maxFolders ? "Drag stack to move · Drop on + for new folder" : "Drag stack to move all")
                .font(isLiquidGlass ? .system(size: 9.5, weight: .medium) : Theme.mono(8.5, .regular))
                .foregroundColor(isLiquidGlass ? .secondary : Theme.boneDim.opacity(0.7))
        }
    }
}

// MARK: - Folder Column View
struct FolderColumnView: View {
    let folder: DropShelfFolder
    let index: Int
    let isLiquidGlass: Bool

    @ObservedObject private var manager = DropShelfManager.shared
    @State private var showingInspector = false
    @State private var isHoveringFolderClose = false

    private var isColumnHovered: Bool {
        manager.hoveredFolderIndex == index
    }

    var body: some View {
        VStack(spacing: 5) {
            // Column Header
            HStack(spacing: 4) {
                Text(folder.name)
                    .font(isLiquidGlass ? .system(size: 10, weight: .semibold, design: .rounded) : Theme.mono(9.5, .bold))
                    .foregroundColor(isLiquidGlass ? .primary : Theme.bone)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 2)

                // Inspect / Popover Trigger Pill
                Button {
                    showingInspector.toggle()
                } label: {
                    HStack(spacing: 2) {
                        Text("\(folder.items.count)")
                            .font(.system(size: 8.5, weight: .bold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .bold))
                    }
                    .foregroundColor(isLiquidGlass ? LiquidGlass.accent : Theme.amber)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isLiquidGlass ? Color.primary.opacity(0.08) : Theme.chassisLow)
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingInspector, arrowEdge: .bottom) {
                    FolderItemsInspectorView(folder: folder, isLiquidGlass: isLiquidGlass)
                }

                // Close / Delete Folder [x]
                Button {
                    manager.removeFolder(id: folder.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(isHoveringFolderClose ? (isLiquidGlass ? .primary : Theme.bone) : (isLiquidGlass ? .secondary : Theme.boneDim))
                        .frame(width: 14, height: 14)
                        .background(Circle().fill(isHoveringFolderClose ? (isLiquidGlass ? Color.primary.opacity(0.12) : Theme.chassisTop) : Color.clear))
                }
                .buttonStyle(.plain)
                .onHover { isHoveringFolderClose = $0 }
            }
            .frame(height: 18)

            // Layered Stack View
            ZStack {
                FolderStackLayeredCardsView(
                    folder: folder,
                    isColumnHovered: isColumnHovered,
                    isLiquidGlass: isLiquidGlass
                )

                // Native Drag Interceptor covering the entire stack
                FolderStackDragSourceView(
                    folder: folder,
                    onSuccess: { droppedURLs in
                        manager.removeItems(matching: droppedURLs, fromFolderId: folder.id)
                    },
                    onInspect: {
                        showingInspector.toggle()
                    }
                )
            }
            .frame(width: 160, height: 120)
        }
        .frame(width: 160)
    }
}

// MARK: - Layered Cards Fan Visual
struct FolderStackLayeredCardsView: View {
    let folder: DropShelfFolder
    let isColumnHovered: Bool
    let isLiquidGlass: Bool

    var body: some View {
        ZStack {
            // Underneath fan card 2 (for >= 3 items)
            if folder.items.count >= 3 {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isLiquidGlass ? Color.primary.opacity(0.04) : Theme.chassisLow.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isLiquidGlass ? Color.white.opacity(0.1) : Theme.chassisTop, lineWidth: 0.5)
                    )
                    .scaleEffect(0.92)
                    .offset(x: -3, y: -8)
                    .rotationEffect(.degrees(-3))
            }

            // Underneath fan card 1 (for >= 2 items)
            if folder.items.count >= 2 {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isLiquidGlass ? Color.primary.opacity(0.06) : Theme.chassisLow.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isLiquidGlass ? Color.white.opacity(0.15) : Theme.chassisTop, lineWidth: 0.5)
                    )
                    .scaleEffect(0.96)
                    .offset(x: 2, y: -4)
                    .rotationEffect(.degrees(2))
            }

            // Top Card
            topCard
        }
    }

    private var topCard: some View {
        let highlightBorderColor: Color = isLiquidGlass ? LiquidGlass.accent : Theme.orange
        let standardBorderColor: Color = isLiquidGlass ? Color.white.opacity(0.18) : Theme.boneDim.opacity(0.2)

        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isLiquidGlass ? Color.primary.opacity(0.08) : Theme.chassisLow)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isColumnHovered ? highlightBorderColor : standardBorderColor,
                            lineWidth: isColumnHovered ? 2 : 0.75
                        )
                )
                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)

            VStack(spacing: 6) {
                if let topItem = folder.items.first {
                    Image(nsImage: topItem.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 38, height: 38)
                        .shadow(color: Color.black.opacity(0.2), radius: 3, y: 1)

                    VStack(spacing: 2) {
                        Text(topItem.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(isLiquidGlass ? .primary : Theme.bone)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 6)

                        if folder.items.count > 1 {
                            Text("+ \(folder.items.count - 1) other \(folder.items.count - 1 == 1 ? "file" : "files")")
                                .font(isLiquidGlass ? .system(size: 9, weight: .medium) : Theme.mono(8.5, .regular))
                                .foregroundColor(isLiquidGlass ? LiquidGlass.accent : Theme.amber)
                        } else {
                            Text(topItem.formattedSize)
                                .font(isLiquidGlass ? .system(size: 9) : Theme.mono(8.5, .regular))
                                .foregroundColor(isLiquidGlass ? .secondary : Theme.boneDim)
                        }
                    }
                } else {
                    Image(systemName: "folder")
                        .font(.system(size: 32))
                        .foregroundColor(isLiquidGlass ? .secondary : Theme.boneDim)
                    Text("Empty")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)

            // Top-right count pill badge
            if folder.items.count > 1 {
                VStack {
                    HStack {
                        Spacer()
                        Text("\(folder.items.count)")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isLiquidGlass ? LiquidGlass.accent : Theme.orange)
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)
                            .padding(6)
                    }
                    Spacer()
                }
            }
        }
    }
}

// MARK: - New Folder Slot View
struct NewFolderSlotView: View {
    let isHighlighted: Bool
    let isLiquidGlass: Bool

    var body: some View {
        let highlightColor: Color = isLiquidGlass ? LiquidGlass.accent : Theme.orange

        VStack(spacing: 5) {
            // Header spacer placeholder
            Text("+ New")
                .font(isLiquidGlass ? .system(size: 10, weight: .medium) : Theme.mono(9, .regular))
                .foregroundColor(.clear)
                .frame(height: 18)

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isHighlighted ? highlightColor : (isLiquidGlass ? Color.white.opacity(0.2) : Theme.boneDim.opacity(0.35)),
                        style: StrokeStyle(lineWidth: isHighlighted ? 2 : 1.2, dash: [4, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isHighlighted ? highlightColor.opacity(0.12) : (isLiquidGlass ? Color.primary.opacity(0.02) : Theme.chassisLow.opacity(0.3)))
                    )

                VStack(spacing: 5) {
                    Image(systemName: isHighlighted ? "plus.circle.fill" : "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isHighlighted ? highlightColor : (isLiquidGlass ? .secondary : Theme.boneDim))

                    Text("New Folder")
                        .font(isLiquidGlass ? .system(size: 10, weight: .semibold) : Theme.mono(9.5, .semibold))
                        .foregroundColor(isHighlighted ? highlightColor : (isLiquidGlass ? .primary : Theme.bone))

                    Text("Drop to create")
                        .font(.system(size: 8.5))
                        .foregroundColor(isLiquidGlass ? .secondary : Theme.boneDim.opacity(0.7))
                }
                .padding(6)
            }
            .frame(width: 85, height: 120)
        }
        .frame(width: 85)
    }
}

// MARK: - Popover File Inspector View
struct FolderItemsInspectorView: View {
    let folder: DropShelfFolder
    let isLiquidGlass: Bool

    @ObservedObject private var manager = DropShelfManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(folder.name)
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text("\(folder.items.count) files")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 2)

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 4) {
                    ForEach(folder.items) { item in
                        HStack(spacing: 6) {
                            Image(nsImage: item.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18, height: 18)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(item.formattedSize)
                                    .font(.system(size: 8.5))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([item.url])
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                                    .frame(width: 16, height: 16)
                            }
                            .buttonStyle(.plain)
                            .help("Reveal in Finder")

                            Button {
                                manager.removeItem(id: item.id, fromFolderId: folder.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 16, height: 16)
                            }
                            .buttonStyle(.plain)
                            .help("Remove file")
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                    }
                }
            }
            .frame(maxHeight: 180)
        }
        .padding(10)
        .frame(width: 220)
    }
}

// MARK: - Native AppKit Drag Source for Entire Folder Stack
struct FolderStackDragSourceView: NSViewRepresentable {
    var folder: DropShelfFolder
    var onSuccess: ([URL]) -> Void
    var onInspect: () -> Void

    func makeNSView(context: Context) -> FolderStackDragNSView {
        let view = FolderStackDragNSView()
        view.configure(folder: folder, onSuccess: onSuccess, onInspect: onInspect)
        return view
    }

    func updateNSView(_ nsView: FolderStackDragNSView, context: Context) {
        nsView.configure(folder: folder, onSuccess: onSuccess, onInspect: onInspect)
    }
}

final class FolderStackDragNSView: NSView, NSDraggingSource {
    private var folder: DropShelfFolder?
    private var activeDragURLs: [URL] = []
    private var onSuccess: (([URL]) -> Void)?
    private var onInspect: (() -> Void)?

    private var initialMouseDownLocation: NSPoint?
    private var isDragging = false

    // CRITICAL: Block window move hijacking when clicking/dragging the card stack
    override var mouseDownCanMoveWindow: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    func configure(folder: DropShelfFolder, onSuccess: @escaping ([URL]) -> Void, onInspect: @escaping () -> Void) {
        self.folder = folder
        self.onSuccess = onSuccess
        self.onInspect = onInspect
    }

    override func mouseDown(with event: NSEvent) {
        initialMouseDownLocation = event.locationInWindow
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isDragging, let initial = initialMouseDownLocation, let folder = folder, !folder.items.isEmpty else { return }
        let current = event.locationInWindow
        guard hypot(current.x - initial.x, current.y - initial.y) >= 3.0 else { return }

        // Fast disk validation: prune missing files
        let validItems = folder.items.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        guard !validItems.isEmpty else {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            DropShelfManager.shared.removeFolder(id: folder.id)
            initialMouseDownLocation = nil
            return
        }

        isDragging = true
        activeDragURLs = validItems.map { $0.url }
        DropShelfManager.shared.incrementDragSession()

        let mouseInView = convert(event.locationInWindow, from: nil)
        var draggingItems: [NSDraggingItem] = []

        for (idx, item) in validItems.enumerated() {
            let dragItem = NSDraggingItem(pasteboardWriter: item.url as NSURL)
            // Stagger up to 4 cards visually for stack fan effect
            let offset = CGFloat(min(idx, 4)) * 3.0
            let iconRect = NSRect(x: mouseInView.x - 16 + offset, y: mouseInView.y - 16 - offset, width: 32, height: 32)
            dragItem.setDraggingFrame(iconRect, contents: item.icon)
            draggingItems.append(dragItem)
        }

        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    override func mouseUp(with event: NSEvent) {
        if !isDragging {
            if event.clickCount == 2, let urls = folder?.items.map(\.url), !urls.isEmpty {
                // Double-click reveals files in Finder
                NSWorkspace.shared.activateFileViewerSelecting(urls)
            } else if event.clickCount == 1 {
                // Single-click toggles inspector popover
                onInspect?()
            }
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
        guard operation != [] else {
            isDragging = false
            initialMouseDownLocation = nil
            activeDragURLs.removeAll()
            return
        }

        let dropped = activeDragURLs
        if Thread.isMainThread {
            self.onSuccess?(dropped)
        } else {
            DispatchQueue.main.async { self.onSuccess?(dropped) }
        }

        isDragging = false
        initialMouseDownLocation = nil
        activeDragURLs.removeAll()
    }
}
