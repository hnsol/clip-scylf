import AppKit
import SwiftUI

// M1: 固定フォルダの一覧をフローティングパネルに表示し、ドラッグで外部アプリへ渡す

final class FloatingPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
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
}

struct FileItem: Identifiable {
    let url: URL
    var id: URL { url }
    var name: String { url.lastPathComponent }
}

struct FileListView: View {
    let items: [FileItem]

    var body: some View {
        List(items) { item in
            HStack {
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                    .resizable()
                    .frame(width: 20, height: 20)
                Text(item.name)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onDrag { NSItemProvider(contentsOf: item.url)! }
        }
        .listStyle(.inset)
    }
}

func loadItems(in folder: URL) -> [FileItem] {
    let urls = (try? FileManager.default.contentsOfDirectory(
        at: folder,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    )) ?? []
    return urls
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        .map(FileItem.init)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FloatingPanel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let folder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads")
        let view = NSHostingView(rootView: FileListView(items: loadItems(in: folder)))
        panel = FloatingPanel(contentView: view)
        panel.makeKeyAndOrderFront(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
