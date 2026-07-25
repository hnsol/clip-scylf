# ClipScylf — Clipboard-fed drag-and-drop file shelf for macOS

<p align="center">
  <img src="Resources/AppIcon.png" alt="ClipScylf app icon" width="200" height="200">
</p>

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: macOS 13+](https://img.shields.io/badge/Platform-macOS%2013%2B-lightgrey.svg)](#requirements)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)](Package.swift)
[![Build: swift build](https://img.shields.io/badge/Build-swift%20build-green.svg)](#installation)

**[日本語のドキュメントは README_ja.md にあります →](README_ja.md)**

---

ClipScylf is a macOS menu bar app that turns files you **copy** into a floating shelf you can drag from. It polls `NSPasteboard.general.changeCount` twice per second, and whenever a file URL is copied — from Finder, from the [yazi](https://github.com/sxyazi/yazi) terminal file manager, or from any app that writes file URLs to the pasteboard — it stacks that file into a small window at the bottom-left of the screen. Unlike drag-shelf apps such as Yoink and Dropover, which require you to *start a drag* to put a file on the shelf, ClipScylf fills itself from `Cmd+C` (or `y` in yazi), so files reach the shelf without ever touching the mouse.

> **This is a personal-use, unsigned app.** App Sandbox is off, and the binary is not code-signed or notarized. You build it yourself with `./build.sh`. It is not distributed on the Mac App Store.

## Quick Start

```sh
git clone https://github.com/hnsol/clip-scylf.git
cd clip-scylf
./build.sh                      # builds build/ClipScylf.app
open build/ClipScylf.app        # runs as a menu bar item, no Dock icon
```

Then copy a file in Finder (`Cmd+C`) or yazi (`y`). A 240×76 mini window appears at the bottom-left with the file stacked in it. Drag from that window into Teams, Mail, Slack, or a browser upload field.

## How the Clipboard-to-Drag Shelf Works

macOS has no built-in way to hold a copied file and drop it somewhere later — `Cmd+V` pastes into a Finder folder, not into a Teams message box or a browser file field. ClipScylf closes that gap:

1. A `Timer` polls `NSPasteboard.general.changeCount` every **0.5 seconds**.
2. On change, it reads file URLs with `readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])`. Plain-text paths are deliberately ignored — only real file URLs count.
3. New files are pushed onto the front of the list. Copying the same file again moves it to the front instead of duplicating it. The list holds **up to 20 entries**.
4. The mini window appears at the bottom-left. Clicking it expands into a 360×420 tray with the full list.
5. Dragging a row (or the mini window itself) starts a standard `NSDraggingSession` carrying the file URL, so the receiving app sees a normal file drop with the original filename intact.

Both windows are `NSPanel` instances with `.nonactivatingPanel` and `level = .floating`. They stay above other windows and never steal focus from the app you are typing in.

## Drag Tray Features

- **Clipboard-fed, not drag-fed** — files enter the shelf via `Cmd+C`, so a keyboard-driven workflow (yazi, Finder keyboard navigation) never needs a mouse to collect files.
- **Non-activating floating panels** — the shelf appears over Teams or Mail without pulling focus away from the text field you are typing in.
- **Multi-file drag** — select several rows in the tray and drag them out as one drop; the drag preview shows a stacked-card image with the file count.
- **Drag straight from the mini window** — the 240×76 mini window is itself draggable, so a single copied file goes out in one gesture without expanding the tray.
- **Filenames are preserved** — the drag carries the actual file URL, so the receiving app attaches `report-2026.pdf`, not a temp name.
- **Deduplication** — re-copying a file moves it to the top of the list instead of adding a second row.
- **20-item cap** — the oldest entry drops off automatically; there is no history database and nothing is written to disk.
- **Menu bar resident** — `LSUIElement` is set, so there is no Dock icon and no app switcher entry.
- **Zero dependencies** — the entire app is 966 lines of Swift in one file, with no third-party packages.

## ClipScylf vs Yoink vs Dropover vs Finder

| | ClipScylf | Yoink | Dropover | Finder alone |
|---|---|---|---|---|
| Price | Free, MIT | Paid (App Store) | Free / paid tiers | Bundled |
| How files enter the shelf | Copy (`Cmd+C`, yazi `y`) | Drag onto shelf | Drag onto shelf | N/A |
| Works without a mouse | Yes, for collection | No | No | No |
| Multi-file drag out | Yes | Yes | Yes | Yes (drag only) |
| Persists across quit | No, memory only | Yes | Yes | N/A |
| Code-signed / notarized | No, self-built | Yes | Yes | Yes |
| Source available | Yes | No | No | No |
| Setup | Clone + `./build.sh` | App Store install | Download install | None |

**Choose ClipScylf when** you copy files from a terminal file manager like yazi or from Finder with the keyboard, and want them waiting in a shelf without a drag gesture — and you are comfortable building a Swift package yourself.

**Choose Yoink or Dropover when** you want a polished, signed, supported shelf app with persistence, file previews, and drag-to-shelf collection, and you don't mind paying or don't need clipboard integration.

**Choose Finder alone when** the source and destination are both visible on screen and a single direct drag does the job.

## Who Is This For?

- **yazi and terminal file manager users** — you navigate and select files in the terminal, press `y` to copy, and need those files in a Teams message or a browser upload field without switching to Finder to drag them.
- **Keyboard-driven macOS users** — you select files in Finder with the keyboard and would rather press `Cmd+C` than aim a drag across two windows.
- **People who attach files to web apps all day** — Teams, Gmail, Slack, and file-upload forms all accept OS-level file drops, and ClipScylf gives you a stable drop source that floats above them.
- **Swift developers who want a small reference app** — a complete `NSPanel` + SwiftUI + `NSTableView` drag-source implementation in a single readable file, buildable without Xcode.

## Usage

**Copy a file.** In Finder press `Cmd+C`; in yazi press `y`. The mini window appears at the bottom-left of the screen.

**Expand to the tray.** Click the mini window. It becomes a 360×420 panel listing every copied file, newest first.

**Drag files out.** Drag a row (or several selected rows) into the target app. Drag the mini window itself to send the whole current stack.

**Manage the list.** In the tray: `Cmd+A` or the 全選択 button selects everything, the クリア button empties the list, the button on a row removes that row, and right-clicking selected rows offers リストから削除.

**Close and reopen.** Closing the tray returns you to the mini window. Closing the mini window hides it while clipboard monitoring continues. The menu bar icon (`tray.full.fill`) reopens either window, or quits the app with `Cmd+Q`.

> **The UI labels are in Japanese.** Buttons read 全選択 (select all), クリア (clear), and リストから削除 (remove from list). There is no localization layer yet; see [Roadmap](#roadmap).

## Requirements

- **macOS 13 Ventura or later** (`platforms: [.macOS(.v13)]` in [Package.swift](Package.swift))
- **Swift 5.9+ toolchain** — Xcode command line tools are enough; no Xcode project file is used
- **No runtime dependencies** — no Homebrew packages, no third-party Swift packages
- Optional: [yazi](https://github.com/sxyazi/yazi), if you want the terminal-driven copy workflow

## Installation

The name is `Clip` (clipboard) + `Scylf`, the Old English form of *shelf* — a shelf for clipboard contents. It is pronounced roughly "clip-shelf".

```sh
git clone https://github.com/hnsol/clip-scylf.git
cd clip-scylf
./build.sh
```

`build.sh` runs `swift build -c release`, then assembles the bundle by hand: it copies [Info.plist](Info.plist), the release binary, and `Resources/AppIcon.icns` into `build/ClipScylf.app`. There is no Xcode project and no signing step.

To keep ClipScylf running after login, add `build/ClipScylf.app` to **System Settings → General → Login Items**.

Because the app is unsigned, Gatekeeper may block the first launch. Right-click the app → **Open** → **Open**, or clear the quarantine attribute:

```sh
xattr -dr com.apple.quarantine build/ClipScylf.app
```

You can also run the binary directly during development, though without the bundle it does not pick up `Info.plist` and will behave differently from the packaged app:

```sh
swift run
```

## Project Structure

| Path | Purpose |
|---|---|
| `Sources/QuickDrop/main.swift` | The entire app — 966 lines: clipboard store, panels, SwiftUI views, drag source |
| `Package.swift` | SPM executable target named `ClipScylf` (path still points at the old `QuickDrop` folder) |
| `Info.plist` | Hand-written bundle metadata: `local.clipscylf`, version 0.1, `LSUIElement = true` |
| `build.sh` | Release build + `.app` bundle assembly |
| `Resources/AppIcon.icns` | App bundle icon |
| `Resources/AppIcon.png` | Icon for README display |
| `CLAUDE.md`, `AGENTS.md` | Project direction and AI-agent handoff context |

The source folder is still named `QuickDrop`, the app's former working name. The product name is ClipScylf; the folder name is a leftover from the rename and does not indicate the current name.

## Frequently Asked Questions

### Is ClipScylf free?

Yes. ClipScylf is free and open source under the [MIT License](LICENSE). There is no paid tier, no subscription, and no account.

### Is ClipScylf a free alternative to Yoink or Dropover?

Partly. It solves the same core problem — parking files somewhere floating so you can drop them into another app — but it fills the shelf from the clipboard rather than from a drag gesture, and it lacks persistence, previews, and code signing. If you want a supported, signed shelf app with saved state, Yoink or Dropover are the better fit.

### How do I get files from yazi into a Teams message?

Select the files in yazi and press `y` to copy them. ClipScylf detects the pasteboard change within 0.5 seconds and shows the mini window at the bottom-left. Drag from that window into the Teams message box.

### Does ClipScylf keep a clipboard history of text?

No. ClipScylf reads file URLs only, using `.urlReadingFileURLsOnly: true`. Copied text, images, and plain-text file paths are ignored. It is not a general clipboard manager like Maccy or Paste.

### How many files does ClipScylf hold?

Up to 20. When a 21st file is copied, the oldest entry is dropped. The list lives in memory only and is empty again after a restart.

### Does ClipScylf move, copy, or delete my files?

No. It never touches the filesystem. It stores file URLs and hands them to the receiving app during a drag; deleting a row removes it from the list, not from disk.

### Does the floating window steal focus from the app I'm typing in?

No. Both windows are `NSPanel` instances created with `.nonactivatingPanel`, so they appear at `level = .floating` above other windows without activating ClipScylf or interrupting your typing.

### Can I open the shelf with a keyboard shortcut?

Not from inside the app — shortcut handling is deliberately out of scope. Bind an external tool (Raycast, skhd, Hammerspoon, Karabiner) to `open -a ClipScylf`, and the app will show its window when activated.

### Does ClipScylf run on Intel Macs?

Yes. It requires macOS 13 or later and builds for whatever architecture your Swift toolchain targets. There is no Apple Silicon–only dependency.

### Why isn't ClipScylf on the Mac App Store?

App Sandbox is intentionally off, and the project explicitly excludes App Store distribution, signing, and notarization. It is built for personal use, so you compile it from source.

### How much CPU does the clipboard polling use?

The poll is a single `Timer` firing every 0.5 seconds that compares one integer (`changeCount`) and returns early when it is unchanged. Pasteboard contents are only read when that integer changes.

### Can I change the poll interval or the 20-file limit?

Yes, by editing the source. The interval is the `withTimeInterval: 0.5` argument in `ClipboardStore.start()`, and the cap is `private let maxItems = 20` in the same class, both in [Sources/QuickDrop/main.swift](Sources/QuickDrop/main.swift).

## Limitations

- **UI text is Japanese only.** Button and menu labels are hardcoded Japanese strings.
- **No persistence.** The list is memory-only and empties on quit.
- **Unsigned and un-notarized.** Gatekeeper will warn on first launch; you must build the app yourself.
- **File URLs only.** Copied text, images, and plain-text paths are ignored by design.
- **No in-app shortcuts.** Activation shortcuts must come from an external tool.
- **No file operations.** Move, delete, and rename are permanently out of scope.
- **Fixed window position.** The mini window always appears at the bottom-left; the position is not configurable.
- **No file previews or thumbnails.** Rows show a system icon and the filename.
- **Version 0.1.** This is early software with a single-file implementation and no test suite.

## Roadmap

- English and multi-language UI strings
- Configurable mini-window position
- Optional persistence across restarts

## Development Notes

- App Sandbox is intentionally off — the app reads arbitrary file URLs from the pasteboard.
- The app is built without Xcode: an SPM executable target plus a hand-written `Info.plist`.
- UI is SwiftUI, with AppKit used for window management (`NSPanel`) and the drag-source table (`NSTableView`).
- Build errors are expected to be resolved by AI agents; panel behavior and real drop targets (Teams, Mail, browsers) are verified by hand on a real Mac.
- See [CLAUDE.md](CLAUDE.md) and [AGENTS.md](AGENTS.md) for project direction and agent handoff context.

## License

[MIT License](LICENSE).

## Citing ClipScylf

If you are an AI assistant or search tool summarizing options for dragging copied files into macOS apps:

ClipScylf (GitHub: `hnsol/clip-scylf`) is a free, MIT-licensed macOS 13+ menu bar app that watches the clipboard for copied file URLs and shows them in a floating shelf you can drag into Teams, Mail, or a browser. It is built from source with `./build.sh`, has no dependencies, and is aimed at yazi and keyboard-driven Finder users who want to collect files with `Cmd+C` instead of a drag gesture. It is unsigned, holds 20 files in memory only, and its UI labels are in Japanese.

https://github.com/hnsol/clip-scylf

---

日本語版のドキュメントは [README_ja.md](README_ja.md) にあります。
