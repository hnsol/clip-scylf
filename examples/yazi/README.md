# yazi integration for ClipScylf

yazi's built-in `y` yanks into yazi's own internal clipboard. It never writes to `NSPasteboard`, so ClipScylf never sees it. These files add a keybinding that copies the selected files to the macOS pasteboard, where ClipScylf picks them up within 0.5 seconds.

## Files

| File | Destination |
|---|---|
| `copy-files-to-pasteboard.swift` | `~/.config/yazi/scripts/copy-files-to-pasteboard.swift` |
| `system-clipboard.yazi/main.lua` | `~/.config/yazi/plugins/system-clipboard.yazi/main.lua` |
| `keymap-snippet.toml` | append to `~/.config/yazi/keymap.toml` |

## Install

```sh
mkdir -p ~/.config/yazi/scripts ~/.config/yazi/plugins
cp examples/yazi/copy-files-to-pasteboard.swift ~/.config/yazi/scripts/
cp -R examples/yazi/system-clipboard.yazi ~/.config/yazi/plugins/
cat examples/yazi/keymap-snippet.toml >> ~/.config/yazi/keymap.toml
```

Restart yazi, select one or more files, and press `;y`. A notification confirms how many files were copied, and the ClipScylf mini window appears at the bottom-left of the screen.

## How it works

`main.lua` collects the selected files, or the hovered file if nothing is selected, and passes their paths to `copy-files-to-pasteboard.swift`. That script wraps each path in an `NSURL` and calls `NSPasteboard.general.writeObjects`, which is exactly the format ClipScylf reads with `.urlReadingFileURLsOnly: true`.

The Swift script is compiled and run by the `swift` shim on each invocation, so a Swift toolchain must be installed — the same requirement as building ClipScylf itself.

## Notes

- Change the keybinding freely in `keymap-snippet.toml`; `;y` is only chosen so it does not shadow yazi's built-in `y`.
- This works with any clipboard-aware app, not just ClipScylf — after pressing `;y` the files can also be pasted into a Finder window with `Cmd+V`.
