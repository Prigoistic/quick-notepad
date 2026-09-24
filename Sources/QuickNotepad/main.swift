import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let appState = AppState()
app.delegate = appState
app.run()
