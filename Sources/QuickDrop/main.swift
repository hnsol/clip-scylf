import AppKit
import Combine
import QuartzCore
import SwiftUI
import UniformTypeIdentifiers

final class FloatingPanel: NSPanel {
    var onClose: (() -> Void)?
    var onSelectAll: (() -> Void)?

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        title = "ClipScylf"
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        self.contentView = contentView
        center()
    }

    override var canBecomeKey: Bool { true }

    override func close() {
        onClose?()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers == "q" {
            NSApp.terminate(nil)
            return true
        }
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers == "a" {
            onSelectAll?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

final class MiniPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 190, height: 58),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        self.contentView = contentView
    }

    override var canBecomeKey: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers == "q" {
            NSApp.terminate(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

struct ClipItem: Identifiable, Equatable {
    let url: URL

    var id: URL { normalizedURL }
    var name: String { url.lastPathComponent }
    var normalizedURL: URL { url.standardizedFileURL }
}

final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipItem] = []
    var onNewItems: (() -> Void)?

    private let pasteboard: NSPasteboard
    private var lastChangeCount: Int
    private var timer: Timer?
    private let maxItems = 20

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        lastChangeCount = pasteboard.changeCount
    }

    deinit {
        stop()
    }

    func start() {
        readPasteboard(notify: false)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func clear() {
        items = []
    }

    func remove(_ item: ClipItem) {
        items.removeAll { $0.normalizedURL == item.normalizedURL }
    }

    private func poll() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current
        readPasteboard(notify: true)
    }

    private func readPasteboard(notify: Bool) {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        guard let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: options
        ), !objects.isEmpty else {
            return
        }
        let urls = objects.compactMap { object -> URL? in
            if let url = object as? URL { return url }
            if let url = object as? NSURL { return url as URL }
            return nil
        }
        guard !urls.isEmpty else { return }

        let newItems = urls.map { ClipItem(url: $0) }
        let newIDs = Set(newItems.map(\.normalizedURL))
        let oldItems = items.filter { !newIDs.contains($0.normalizedURL) }
        items = Array((newItems + oldItems).prefix(maxItems))
        if notify {
            onNewItems?()
        }
    }
}

struct ClipTrayView: View {
    @ObservedObject var store: ClipboardStore
    let onSelectAll: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(store.items.count)件")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("全選択") {
                    onSelectAll()
                }
                .disabled(store.items.isEmpty)
                Button("クリア") {
                    store.clear()
                }
                .disabled(store.items.isEmpty)
            }
            .padding(8)

            Divider()

            if store.items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("ファイルをコピーしてください")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ClipTableView(items: store.items) { item in
                    store.remove(item)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct ClipMiniView: View {
    @ObservedObject var store: ClipboardStore
    let onExpand: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 10) {
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(store.items.count)件")
                        .font(.system(size: 12, weight: .bold))
                    Text(store.items.first?.name ?? "ファイルなし")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Color.clear.frame(width: 18)
            }
            .padding(.horizontal, 12)
            .frame(width: 190, height: 58)
            .background(Rectangle().fill(Color.white.opacity(0.001)))
            .contentShape(Rectangle())
            .overlay(MiniDragSource(items: store.items, onClick: onExpand))

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)
            .help("閉じる")
        }
        .frame(width: 190, height: 58)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct MiniDragSource: NSViewRepresentable {
    let items: [ClipItem]
    let onClick: () -> Void

    func makeNSView(context: Context) -> DragSourceView {
        DragSourceView(items: items, onClick: onClick)
    }

    func updateNSView(_ nsView: DragSourceView, context: Context) {
        nsView.items = items
        nsView.onClick = onClick
    }

    final class DragSourceView: NSView, NSDraggingSource {
        var items: [ClipItem]
        var onClick: () -> Void
        private var mouseDownEvent: NSEvent?
        private var isDragging = false

        init(items: [ClipItem], onClick: @escaping () -> Void) {
            self.items = items
            self.onClick = onClick
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            items = []
            onClick = {}
            super.init(coder: coder)
        }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            true
        }

        override func mouseDown(with event: NSEvent) {
            mouseDownEvent = event
            isDragging = false
        }

        override func mouseDragged(with event: NSEvent) {
            guard !isDragging,
                  let mouseDownEvent,
                  dragDistance(from: mouseDownEvent, to: event) >= 4,
                  !items.isEmpty else {
                return
            }
            isDragging = true
            beginDraggingSession(
                with: draggingItems(for: items, event: event),
                event: event,
                source: self
            )
        }

        override func mouseUp(with event: NSEvent) {
            if !isDragging {
                onClick()
            }
            mouseDownEvent = nil
            isDragging = false
        }

        func draggingSession(
            _ session: NSDraggingSession,
            sourceOperationMaskFor context: NSDraggingContext
        ) -> NSDragOperation {
            .copy
        }

        private func dragDistance(from start: NSEvent, to current: NSEvent) -> CGFloat {
            let dx = current.locationInWindow.x - start.locationInWindow.x
            let dy = current.locationInWindow.y - start.locationInWindow.y
            return sqrt(dx * dx + dy * dy)
        }

        private func draggingItems(for items: [ClipItem], event: NSEvent) -> [NSDraggingItem] {
            let origin = convert(event.locationInWindow, from: nil)
            let previewSize = NSSize(width: 154, height: 54)
            let previewImage = dragPreviewImage(for: items, size: previewSize)
            let clearImage = NSImage(size: NSSize(width: 1, height: 1))

            return items.enumerated().map { index, item in
                let draggingItem = NSDraggingItem(pasteboardWriter: item.url as NSURL)
                if index == 0 {
                    let frame = NSRect(
                        x: origin.x + 10,
                        y: origin.y - previewSize.height - 10,
                        width: previewSize.width,
                        height: previewSize.height
                    )
                    draggingItem.setDraggingFrame(frame, contents: previewImage)
                } else {
                    draggingItem.setDraggingFrame(
                        NSRect(x: origin.x, y: origin.y, width: 1, height: 1),
                        contents: clearImage
                    )
                }
                return draggingItem
            }
        }

        private func dragPreviewImage(for items: [ClipItem], size: NSSize) -> NSImage {
            let image = NSImage(size: size)
            image.lockFocus()

            NSGraphicsContext.current?.imageInterpolation = .high
            drawStackShadow(in: NSRect(origin: .zero, size: size), count: items.count)

            let cardRect = NSRect(x: 0, y: 4, width: size.width - 6, height: size.height - 8)
            let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 12, yRadius: 12)
            NSColor.windowBackgroundColor.withAlphaComponent(0.96).setFill()
            cardPath.fill()
            NSColor.separatorColor.withAlphaComponent(0.45).setStroke()
            cardPath.lineWidth = 1
            cardPath.stroke()

            if let first = items.first {
                let iconConfig = NSImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
                let archiveIcon = NSImage(
                    systemSymbolName: "archivebox.fill",
                    accessibilityDescription: "ClipScylf"
                )?.withSymbolConfiguration(iconConfig)
                archiveIcon?.draw(in: NSRect(x: 14, y: 15, width: 24, height: 24))
                drawFileName(first.name, in: NSRect(x: 48, y: 16, width: 76, height: 18))
            }

            if items.count > 1 {
                drawCountBadge(items.count, in: NSRect(x: size.width - 34, y: size.height - 24, width: 28, height: 18))
            }

            image.unlockFocus()
            return image
        }

        private func drawStackShadow(in rect: NSRect, count: Int) {
            guard count > 1 else { return }
            for offset in [6, 3] {
                let shadowRect = NSRect(
                    x: CGFloat(offset),
                    y: 4 - CGFloat(offset) / 2,
                    width: rect.width - 6,
                    height: rect.height - 8
                )
                let path = NSBezierPath(roundedRect: shadowRect, xRadius: 12, yRadius: 12)
                NSColor.windowBackgroundColor.withAlphaComponent(offset == 6 ? 0.28 : 0.45).setFill()
                path.fill()
            }
        }

        private func drawFileName(_ name: String, in rect: NSRect) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byTruncatingMiddle
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ]
            (name as NSString).draw(in: rect, withAttributes: attributes)
        }

        private func drawCountBadge(_ count: Int, in rect: NSRect) {
            let path = NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9)
            NSColor.controlAccentColor.setFill()
            path.fill()

            let text = "\(count)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let textSize = (text as NSString).size(withAttributes: attributes)
            let textRect = NSRect(
                x: rect.midX - textSize.width / 2,
                y: rect.midY - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            (text as NSString).draw(in: textRect, withAttributes: attributes)
        }
    }
}

struct ClipTableView: NSViewRepresentable {
    let items: [ClipItem]
    let onRemove: (ClipItem) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(items: items, onRemove: onRemove)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        let tableView = NSTableView()
        tableView.frame = scrollView.bounds
        tableView.autoresizingMask = [.width, .height]
        tableView.headerView = nil
        tableView.rowHeight = 32
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        tableView.selectionHighlightStyle = .regular
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.target = context.coordinator
        tableView.doubleAction = nil
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
        DispatchQueue.main.async {
            tableView.window?.makeFirstResponder(tableView)
        }

        let column = NSTableColumn(identifier: .clipItemColumn)
        column.width = 360
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        scrollView.documentView = tableView
        context.coordinator.tableView = tableView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.items = items
        context.coordinator.onRemove = onRemove
        if let tableView = scrollView.documentView as? NSTableView {
            if let column = tableView.tableColumns.first {
                column.width = scrollView.contentView.bounds.width
            }
            tableView.reloadData()
        }
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var items: [ClipItem]
        var onRemove: (ClipItem) -> Void
        weak var tableView: NSTableView?

        init(items: [ClipItem], onRemove: @escaping (ClipItem) -> Void) {
            self.items = items
            self.onRemove = onRemove
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            items.count
        }

        func tableView(
            _ tableView: NSTableView,
            viewFor tableColumn: NSTableColumn?,
            row: Int
        ) -> NSView? {
            guard items.indices.contains(row) else { return nil }

            let cell = tableView.makeView(
                withIdentifier: .clipItemCell,
                owner: self
            ) as? ClipItemCell ?? ClipItemCell()
            cell.identifier = .clipItemCell
            cell.configure(with: items[row], row: row, target: self)
            return cell
        }

        func tableView(
            _ tableView: NSTableView,
            pasteboardWriterForRow row: Int
        ) -> NSPasteboardWriting? {
            guard items.indices.contains(row) else { return nil }
            return items[row].url as NSURL
        }

        func tableView(
            _ tableView: NSTableView,
            menuForRows rows: IndexSet
        ) -> NSMenu? {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(
                title: "リストから削除",
                action: #selector(removeMenuItems(_:)),
                keyEquivalent: ""
            ))
            menu.items.first?.target = self
            return menu
        }

        @objc func removeButtonClicked(_ sender: NSButton) {
            let row = sender.tag
            guard items.indices.contains(row) else { return }
            onRemove(items[row])
        }

        @objc func removeMenuItems(_ sender: NSMenuItem) {
            guard let tableView else { return }
            let selectedItems = tableView.selectedRowIndexes.compactMap { row in
                items.indices.contains(row) ? items[row] : nil
            }
            selectedItems.forEach(onRemove)
        }
    }
}

final class ClipItemCell: NSTableCellView {
    private let iconView = NSImageView()
    private let nameField = NSTextField(labelWithString: "")
    private let removeButton = NSButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(with item: ClipItem, row: Int, target: AnyObject) {
        iconView.image = NSWorkspace.shared.icon(forFile: item.url.path)
        nameField.stringValue = item.name
        removeButton.tag = row
        removeButton.target = target
        removeButton.action = #selector(ClipTableView.Coordinator.removeButtonClicked(_:))
        toolTip = item.url.path
    }

    private func setup() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown

        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.lineBreakMode = .byTruncatingMiddle

        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.image = NSImage(
            systemSymbolName: "xmark.circle.fill",
            accessibilityDescription: "削除"
        )
        removeButton.title = ""
        removeButton.isBordered = false
        removeButton.contentTintColor = .secondaryLabelColor
        removeButton.toolTip = "リストから削除"

        addSubview(iconView)
        addSubview(nameField)
        addSubview(removeButton)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            nameField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            nameField.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameField.trailingAnchor.constraint(equalTo: removeButton.leadingAnchor, constant: -8),

            removeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            removeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: 20),
            removeButton.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
}

private extension NSUserInterfaceItemIdentifier {
    static let clipItemColumn = NSUserInterfaceItemIdentifier("clipItemColumn")
    static let clipItemCell = NSUserInterfaceItemIdentifier("clipItemCell")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    enum DisplayState {
        case hiddenMonitoring
        case mini
        case full
    }

    var fullPanel: FloatingPanel!
    var miniPanel: MiniPanel!
    var statusItem: NSStatusItem!
    let clipboardStore = ClipboardStore()
    var displayState: DisplayState = .hiddenMonitoring
    private var miniAnimationID = 0
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        fullPanel = FloatingPanel(contentView: NSHostingView(rootView: EmptyView()))
        fullPanel.isReleasedWhenClosed = false
        fullPanel.onClose = { [weak self] in
            self?.handlePanelClose()
        }
        fullPanel.onSelectAll = { [weak self] in
            self?.selectAllInFullPanel()
        }
        miniPanel = MiniPanel(contentView: NSHostingView(rootView: EmptyView()))
        miniPanel.isReleasedWhenClosed = false

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "archivebox.fill",
            accessibilityDescription: "ClipScylf"
        )
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "通常ウィンドウを開く", action: #selector(openFullPanel), keyEquivalent: ""
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "ClipScylfを終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
        ))
        statusItem.menu = menu

        clipboardStore.onNewItems = { [weak self] in
            guard let self, self.displayState == .hiddenMonitoring else { return }
            self.showMini()
        }
        clipboardStore.$items
            .sink { [weak self] items in
                guard let self, items.isEmpty, self.displayState == .mini else { return }
                self.hideMini()
            }
            .store(in: &cancellables)
        clipboardStore.start()
    }

    func showMini() {
        guard !clipboardStore.items.isEmpty else {
            hideMini()
            return
        }
        displayState = .mini
        let size = NSSize(width: 190, height: 58)
        let view = NSHostingView(rootView: ClipMiniView(
            store: clipboardStore,
            onExpand: { [weak self] in self?.showFull() },
            onClose: { [weak self] in self?.hideMini() }
        ))
        view.frame = NSRect(origin: .zero, size: size)
        view.autoresizingMask = [.width, .height]
        fullPanel.orderOut(nil)
        miniPanel.contentView = view
        miniPanel.setContentSize(size)
        miniAnimationID += 1
        let finalOrigin = bottomLeftOrigin(for: miniPanel.frame.size)
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            miniPanel.alphaValue = 1
            miniPanel.setFrameOrigin(finalOrigin)
            miniPanel.orderFrontRegardless()
            return
        }
        let startOrigin = NSPoint(
            x: finalOrigin.x - miniPanel.frame.size.width - 18,
            y: finalOrigin.y
        )
        miniPanel.alphaValue = 0.85
        miniPanel.setFrame(NSRect(origin: startOrigin, size: miniPanel.frame.size), display: true)
        miniPanel.orderFrontRegardless()
        miniPanel.display()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 1.0
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.12, 0.9, 0.2, 1)
            miniPanel.animator().setFrame(NSRect(origin: finalOrigin, size: miniPanel.frame.size), display: true)
            miniPanel.animator().alphaValue = 1
        } completionHandler: { [weak self] in
            guard let self else { return }
            self.miniPanel.setFrameOrigin(finalOrigin)
            self.miniPanel.alphaValue = 1
        }
    }

    func showFull() {
        displayState = .full
        let size = NSSize(width: 360, height: 420)
        let view = NSHostingView(rootView: ClipTrayView(
            store: clipboardStore,
            onSelectAll: { [weak self] in
                self?.selectAllInFullPanel()
            }
        ).frame(width: size.width, height: size.height))
        view.frame = NSRect(origin: .zero, size: size)
        view.autoresizingMask = [.width, .height]
        miniPanel.orderOut(nil)
        fullPanel.contentView = view
        fullPanel.setContentSize(size)
        fullPanel.orderFrontRegardless()
        positionPanelAtCenter(fullPanel)
        fullPanel.makeKey()
    }

    func hideMini() {
        displayState = .hiddenMonitoring
        miniAnimationID += 1
        let animationID = miniAnimationID
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            miniPanel.orderOut(nil)
            miniPanel.alphaValue = 1
            return
        }
        let endOrigin = NSPoint(
            x: miniPanel.frame.origin.x - miniPanel.frame.size.width - 18,
            y: miniPanel.frame.origin.y
        )
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 1.5
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.12, 0.9, 0.2, 1)
            miniPanel.animator().setFrame(NSRect(origin: endOrigin, size: miniPanel.frame.size), display: true)
            miniPanel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self, self.miniAnimationID == animationID else { return }
            self.miniPanel.orderOut(nil)
            self.miniPanel.alphaValue = 1
        }
    }

    func handlePanelClose() {
        switch displayState {
        case .hiddenMonitoring:
            fullPanel.orderOut(nil)
            miniPanel.orderOut(nil)
        case .mini:
            hideMini()
        case .full:
            if clipboardStore.items.isEmpty {
                displayState = .hiddenMonitoring
                fullPanel.orderOut(nil)
            } else {
                showMini()
            }
        }
    }

    func positionPanelAtBottomLeft(_ panel: NSPanel, size: NSSize) {
        guard NSScreen.main ?? NSScreen.screens.first != nil else {
            panel.center()
            return
        }
        panel.setFrameOrigin(bottomLeftOrigin(for: size))
    }

    func bottomLeftOrigin(for size: NSSize) -> NSPoint {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return .zero
        }
        let visibleFrame = screen.visibleFrame
        let margin: CGFloat = 18
        return NSPoint(
            x: visibleFrame.minX + margin,
            y: visibleFrame.minY + margin
        )
    }

    func positionPanelAtCenter(_ panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            panel.center()
            return
        }
        let visibleFrame = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2
        )
        panel.setFrameOrigin(origin)
    }

    @objc func openFullPanel() {
        showFull()
    }

    func selectAllInFullPanel() {
        guard displayState == .full,
              let tableView = findTableView(in: fullPanel.contentView) else {
            return
        }
        fullPanel.makeFirstResponder(tableView)
        tableView.selectAll(nil)
    }

    func findTableView(in view: NSView?) -> NSTableView? {
        guard let view else { return nil }
        if let tableView = view as? NSTableView {
            return tableView
        }
        for subview in view.subviews {
            if let tableView = findTableView(in: subview) {
                return tableView
            }
        }
        return nil
    }

}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
