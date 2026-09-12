import AppKit

// Entry point — must be main.swift for AppKit apps without @main
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
