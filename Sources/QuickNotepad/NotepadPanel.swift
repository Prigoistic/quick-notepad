import AppKit

final class NotepadPanel: NSPanel {
    var onSave: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    private let textView = NSTextView()
    private let errorLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()

    convenience init() {
        let contentRect = NSRect(x: 0, y: 0, width: 420, height: 260)
        self.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        configure()
    }

    private func configure() {
        title = "Quick Notepad"
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false

        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.delegate = self

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        errorLabel.textColor = .systemRed
        errorLabel.font = NSFont.systemFont(ofSize: 11)
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        guard let container = contentView else { return }
        container.addSubview(scrollView)
        container.addSubview(errorLabel)

        NSLayoutConstraint.activate([
            errorLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            errorLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            errorLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),

            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: errorLabel.topAnchor, constant: -4),
        ])
    }

    func showAndFocus(withText text: String) {
        textView.string = text
        errorLabel.isHidden = true
        center()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        makeFirstResponder(textView)
    }

    func setText(_ text: String) {
        textView.string = text
    }

    func currentText() -> String {
        textView.string
    }

    func showError(_ message: String) {
        errorLabel.stringValue = message
        errorLabel.isHidden = false
    }

    override func cancelOperation(_ sender: Any?) {
        onDismiss?()
        orderOut(nil)
    }
}

extension NotepadPanel: NSTextViewDelegate {
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)),
           NSApp.currentEvent?.modifierFlags.contains(.command) == true {
            onSave?(textView.string)
            return true
        }
        return false
    }
}
