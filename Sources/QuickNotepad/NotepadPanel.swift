import AppKit

final class NotepadPanel: NSPanel {
    var onSave: ((String) -> Void)?

    private let scrollView = NSTextView.scrollableTextView()
    private var textView: NSTextView { scrollView.documentView as! NSTextView }
    private let errorLabel = NSTextField(labelWithString: "")
    private let saveButton = NSButton(title: "Save", target: nil, action: nil)

    convenience init() {
        let contentRect = NSRect(x: 0, y: 0, width: 420, height: 260)
        self.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .resizable],
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
        isReleasedWhenClosed = false

        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.delegate = self
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 4, height: 6)

        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        errorLabel.textColor = .systemRed
        errorLabel.font = NSFont.systemFont(ofSize: 11)
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.keyEquivalentModifierMask = [.command]
        saveButton.target = self
        saveButton.action = #selector(saveButtonPressed)
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        guard let container = contentView else { return }
        container.addSubview(scrollView)
        container.addSubview(errorLabel)
        container.addSubview(saveButton)

        NSLayoutConstraint.activate([
            saveButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            saveButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),

            errorLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: saveButton.leadingAnchor, constant: -8),
            errorLabel.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -8),
        ])
    }

    @objc private func saveButtonPressed() {
        onSave?(textView.string)
    }

    func showAndFocus() {
        errorLabel.isHidden = true
        center()
        makeKeyAndOrderFront(nil)
        NSApp.activate()
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
