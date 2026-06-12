import AppKit
import SwiftUI
import UniformTypeIdentifiers

// M1: 固定フォルダの一覧をフローティングパネルに表示し、ドラッグで外部アプリへ渡す

final class FloatingPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
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

// よく使うフォルダ。パスを UserDefaults に保存する
final class FolderStore: ObservableObject {
    private static let key = "favoriteFolders"

    @Published var folders: [URL] {
        didSet {
            UserDefaults.standard.set(folders.map(\.path), forKey: Self.key)
        }
    }
    @Published var selected: URL?

    init() {
        let paths = UserDefaults.standard.stringArray(forKey: Self.key)
        let urls = paths?.map { URL(fileURLWithPath: $0) }
            ?? [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")]
        folders = urls
        selected = urls.first
    }

    func add(_ url: URL) {
        guard !folders.contains(url) else { selected = url; return }
        folders.append(url)
        selected = url
    }

    func remove(_ url: URL) {
        folders.removeAll { $0 == url }
        if selected == url { selected = folders.first }
    }
}

struct SidebarView: View {
    @ObservedObject var store: FolderStore

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $store.selected) {
                ForEach(store.folders, id: \.self) { url in
                    Label(url.lastPathComponent, systemImage: "folder")
                        .tag(url)
                        .contextMenu {
                            Button("サイドバーから削除") { store.remove(url) }
                        }
                }
            }
            .listStyle(.sidebar)
            HStack {
                Button {
                    addFolder()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            .padding(6)
        }
    }

    private func addFolder() {
        let dialog = NSOpenPanel()
        dialog.canChooseDirectories = true
        dialog.canChooseFiles = false
        dialog.allowsMultipleSelection = false
        if dialog.runModal() == .OK, let url = dialog.url {
            store.add(url)
        }
    }
}

struct ContentView: View {
    @StateObject private var store = FolderStore()

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 120, ideal: 140)
        } detail: {
            if let folder = store.selected {
                FileListView(items: loadItems(in: folder))
                    .id(folder) // フォルダ切替でリストを作り直す
            } else {
                Text("フォルダを追加してください")
                    .foregroundStyle(.secondary)
            }
        }
    }
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
            .onDrag {
                // contentsOf: だとドロップ先でファイル名が再生成されるため、
                // file-url として渡して元の名前を保持する
                let provider = NSItemProvider(
                    item: item.url as NSURL,
                    typeIdentifier: UTType.fileURL.identifier
                )
                provider.suggestedName = item.name
                return provider
            }
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
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let view = NSHostingView(rootView: ContentView())
        panel = FloatingPanel(contentView: view)
        // 閉じてもプロセスは生かしてパネルを再利用する
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

        showPanel()
    }

    // 呼び出し元アプリのフォーカスを奪わずに前面表示する
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

    // 外部ツールからの activate（open -a 等）でパネルを出す
    func applicationDidBecomeActive(_ notification: Notification) {
        showPanel()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
