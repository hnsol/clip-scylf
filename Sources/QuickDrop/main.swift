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

    // nonactivating パネルはアプリをアクティブにしないため、
    // ⌘Q がメインメニューへ届かない。パネル側で処理する
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers == "q" {
            NSApp.terminate(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

struct FileItem: Identifiable {
    let url: URL
    let tags: [String]
    var id: URL { url }
    var name: String { url.lastPathComponent }
}

// Finder標準タグ名（日英）→ 色
func tagColor(_ name: String) -> Color {
    switch name {
    case "レッド", "Red": .red
    case "オレンジ", "Orange": .orange
    case "イエロー", "Yellow": .yellow
    case "グリーン", "Green": .green
    case "ブルー", "Blue": .blue
    case "パープル", "Purple": .purple
    case "グレイ", "Gray": .gray
    default: .secondary
    }
}

enum SidebarSelection: Hashable {
    case folder(URL)
    case tag(String)
}

// よく使うフォルダ。パスを UserDefaults に保存する
final class FolderStore: ObservableObject {
    private static let key = "favoriteFolders"

    @Published var folders: [URL] {
        didSet {
            UserDefaults.standard.set(folders.map(\.path), forKey: Self.key)
        }
    }
    @Published var selected: SidebarSelection?

    init() {
        let paths = UserDefaults.standard.stringArray(forKey: Self.key)
        let urls = paths?.map { URL(fileURLWithPath: $0) }
            ?? [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")]
        folders = urls
        selected = urls.first.map(SidebarSelection.folder)
    }

    func add(_ url: URL) {
        if !folders.contains(url) { folders.append(url) }
        selected = .folder(url)
    }

    func remove(_ url: URL) {
        folders.removeAll { $0 == url }
        if selected == .folder(url) { selected = folders.first.map(SidebarSelection.folder) }
    }
}

// Spotlight (mdfind) でタグ一覧とタグ付きファイルを取得する
final class TagStore: ObservableObject {
    @Published var allTags: [String] = []
    @Published var files: [FileItem] = []

    init() {
        collectTags()
    }

    // ファイル読み取り権限(TCC)に依存しないよう、タグは mdfind -attr の
    // 出力から取る。resourceValues だと Full Disk Access のない場所で失敗する
    private func mdfindWithTags(_ query: String) -> [(path: String, tags: [String])] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        p.arguments = ["-attr", "kMDItemUserTags", query]
        let pipe = Pipe()
        p.standardOutput = pipe
        try? p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()

        // 出力形式:
        //   /path/to/file   kMDItemUserTags = (
        //       "tag1",
        //       tag2
        //   )
        var results: [(String, [String])] = []
        var path: String?
        var tags: [String] = []
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            if let range = line.range(of: "   kMDItemUserTags = (") {
                path = String(line[..<range.lowerBound])
                tags = []
            } else if line == ")" {
                if let p = path { results.append((p, tags)) }
                path = nil
            } else if path != nil {
                var t = line.trimmingCharacters(in: .whitespaces)
                if t.hasSuffix(",") { t.removeLast() }
                if t.hasPrefix("\""), t.hasSuffix("\""), t.count >= 2 {
                    t = String(t.dropFirst().dropLast())
                }
                if !t.isEmpty { tags.append(Self.decodeUnicodeEscapes(t)) }
            }
        }
        return results
    }

    // mdfind は非ASCII文字を \Uxxxx 形式で出力するためデコードする
    private static func decodeUnicodeEscapes(_ s: String) -> String {
        guard s.contains("\\U") else { return s }
        var result = ""
        var rest = Substring(s)
        while let range = rest.range(of: "\\U") {
            result += rest[..<range.lowerBound]
            let hex = rest[range.upperBound...].prefix(4)
            if hex.count == 4, let code = UInt32(hex, radix: 16),
               let scalar = Unicode.Scalar(code) {
                result.unicodeScalars.append(scalar)
                rest = rest[range.upperBound...].dropFirst(4)
            } else {
                result += "\\U"
                rest = rest[range.upperBound...]
            }
        }
        result += rest
        return result
    }

    // Mac全体のタグ付きファイルからタグ名一覧を作る
    func collectTags() {
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            let results = self.mdfindWithTags("kMDItemUserTags == '*'")
            var tags = Set<String>()
            for (_, t) in results { tags.formUnion(t) }
            let sorted = tags.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            DispatchQueue.main.async { self.allTags = sorted }
        }
    }

    func selectTag(_ tag: String) {
        files = []
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            let escaped = tag.replacingOccurrences(of: "'", with: "\\'")
            let items = self.mdfindWithTags("kMDItemUserTags == '\(escaped)'")
                .map { FileItem(url: URL(fileURLWithPath: $0.path), tags: $0.tags) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            DispatchQueue.main.async { self.files = items }
        }
    }
}

struct SidebarView: View {
    @ObservedObject var store: FolderStore
    @ObservedObject var tagStore: TagStore

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $store.selected) {
                Section("フォルダ") {
                    ForEach(store.folders, id: \.self) { url in
                        Label(url.lastPathComponent, systemImage: "folder")
                            .tag(SidebarSelection.folder(url))
                            .contextMenu {
                                Button("サイドバーから削除") { store.remove(url) }
                            }
                    }
                }
                Section("タグ") {
                    ForEach(tagStore.allTags, id: \.self) { name in
                        HStack {
                            Circle()
                                .fill(tagColor(name))
                                .frame(width: 9, height: 9)
                            Text(name)
                        }
                        .tag(SidebarSelection.tag(name))
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
    @StateObject private var tagStore = TagStore()

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, tagStore: tagStore)
                .navigationSplitViewColumnWidth(min: 120, ideal: 140)
        } detail: {
            switch store.selected {
            case .folder(let folder):
                FileListView(items: loadItems(in: folder))
                    .id(folder) // フォルダ切替でリストを作り直す
            case .tag(let tag):
                FileListView(items: tagStore.files)
                    .onAppear { tagStore.selectTag(tag) }
                    .id(tag)
            case nil:
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
                Spacer()
                // Finderタグを色付きドットで表示
                HStack(spacing: 3) {
                    ForEach(item.tags, id: \.self) { tag in
                        Circle()
                            .fill(tagColor(tag))
                            .frame(width: 8, height: 8)
                            .help(tag)
                    }
                }
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
        includingPropertiesForKeys: [.tagNamesKey],
        options: [.skipsHiddenFiles]
    )) ?? []
    return urls
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        .map { url in
            let tags = (try? url.resourceValues(forKeys: [.tagNamesKey]).tagNames) ?? nil
            return FileItem(url: url, tags: tags ?? [])
        }
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
