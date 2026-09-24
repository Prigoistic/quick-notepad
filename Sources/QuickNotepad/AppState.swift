import AppKit

final class AppState: NSObject, NSApplicationDelegate {
    private var panel: NotepadPanel!
    private var hotkeyManager: HotkeyManager!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = NotepadPanel()
        panel.onSave = { [weak self] text in
            self?.handleSave(text: text)
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "N"
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit Quick Notepad", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu

        NSApp.mainMenu = Self.buildMainMenu()

        do {
            hotkeyManager = try HotkeyManager { [weak self] in
                self?.togglePanel()
            }
        } catch {
            NSLog("QuickNotepad: failed to register global hotkey: \(error)")
            statusItem.button?.title = "N!"
        }
    }

    private func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.showAndFocus()
        }
    }

    private func handleSave(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            panel.orderOut(nil)
            return
        }
        NotesBridge.save(body: text) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    self.panel.setText("")
                    self.panel.orderOut(nil)
                case .failure(let error):
                    self.panel.showError(error.userMessage)
                }
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private static func buildMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu

        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        return mainMenu
    }
}
