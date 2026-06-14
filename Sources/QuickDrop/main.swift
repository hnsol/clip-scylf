import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

final class FloatingPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        title = "QuickDrop"
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        self.contentView = contentView
        center()
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
        readPasteboard()
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
        readPasteboard()
    }

    private func readPasteboard() {
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
    }
}

struct ClipTrayView: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        VStack(spacing: 0) {
            if store.items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("yazi/Finderでファイルをコピーしてください")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.items) { item in
                    ClipRow(item: item)
                        .contextMenu {
                            Button("リストから削除") {
                                store.remove(item)
                            }
                        }
                }
                .listStyle(.inset)
            }

            Divider()
            HStack {
                Text("\(store.items.count)件")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("クリア") {
                    store.clear()
                }
                .disabled(store.items.isEmpty)
            }
            .padding(8)
        }
    }
}

struct ClipRow: View {
    let item: ClipItem

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 22, height: 22)
            Text(item.name)
                .lineLimit(1)
            Spacer()
        }
        .contentShape(Rectangle())
        .onDrag {
            let provider = NSItemProvider(
                item: item.url as NSURL,
                typeIdentifier: UTType.fileURL.identifier
            )
            provider.suggestedName = item.name
            return provider
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FloatingPanel!
    var statusItem: NSStatusItem!
    let clipboardStore = ClipboardStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let view = NSHostingView(rootView: ClipTrayView(store: clipboardStore))
        panel = FloatingPanel(contentView: view)
        panel.isReleasedWhenClosed = false

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "tray.and.arrow.up",
            accessibilityDescription: "QuickDrop"
        )
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "パネルを表示/非表示", action: #selector(togglePanel), keyEquivalent: ""
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "QuickDropを終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
        ))
        statusItem.menu = menu

        clipboardStore.start()
        showPanel()
    }

    func showPanel() {
        panel.orderFrontRegardless()
    }

    @objc func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            showPanel()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        showPanel()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
