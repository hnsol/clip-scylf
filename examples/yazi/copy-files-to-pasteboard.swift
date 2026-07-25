#!/usr/bin/env swift

import AppKit
import Foundation

let paths = Array(CommandLine.arguments.dropFirst())

guard !paths.isEmpty else {
    fputs("No files specified\n", stderr)
    exit(1)
}

let urls = paths.map { NSURL(fileURLWithPath: $0) }
let pasteboard = NSPasteboard.general

pasteboard.clearContents()

if !pasteboard.writeObjects(urls) {
    fputs("Failed to write files to pasteboard\n", stderr)
    exit(1)
}
