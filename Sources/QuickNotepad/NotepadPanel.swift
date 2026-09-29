import AppKit

final class NotepadPanel: NSPanel {
    var onSave: ((String, SaveMode) -> Void)?

    private let scrollView = NSTextView.scrollableTextView()
    private var textView: NSTextView { scrollView.documentView as! NSTextView }
    private let errorLabel = NSTextField(labelWithString: "")
    private let newButton = NSButton(
        image: NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "New entry") ?? NSImage(),
        target: nil,
        action: nil
    )
    private let continueButton = NSButton(
        image: NSImage(systemSymbolName: "text.append", accessibilityDescription: "Continue last entry") ?? NSImage(),
        target: nil,
        action: nil
    )

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
        textView.isContinuousSpellCheckingEnabled = true
        textView.isGrammarCheckingEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.isAutomaticTextCompletionEnabled = true
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

        newButton.bezelStyle = .texturedRounded
        newButton.toolTip = "New entry (Cmd+Enter) — saves with a fresh timestamp"
        newButton.keyEquivalent = "\r"
        newButton.keyEquivalentModifierMask = [.command]
        newButton.target = self
        newButton.action = #selector(newButtonPressed)
        newButton.translatesAutoresizingMaskIntoConstraints = false

        continueButton.bezelStyle = .texturedRounded
        continueButton.toolTip = "Continue last entry — appends with no new timestamp"
        continueButton.target = self
        continueButton.action = #selector(continueButtonPressed)
        continueButton.translatesAutoresizingMaskIntoConstraints = false

        guard let container = contentView else { return }
        container.addSubview(scrollView)
        container.addSubview(errorLabel)
        container.addSubview(newButton)
        container.addSubview(continueButton)

        NSLayoutConstraint.activate([
            newButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            newButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),

            continueButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            continueButton.leadingAnchor.constraint(equalTo: newButton.trailingAnchor, constant: 6),

            scrollView.topAnchor.constraint(equalTo: newButton.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: errorLabel.topAnchor, constant: -4),

            errorLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            errorLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            errorLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
        ])
    }

    @objc private func newButtonPressed() {
        onSave?(textView.string, .newEntry)
    }

    @objc private func continueButtonPressed() {
        onSave?(textView.string, .continueEntry)
    }

    func showAndFocus() {
        errorLabel.isHidden = true
        updateTitleFromText()
        center()
        makeKeyAndOrderFront(nil)
        NSApp.activate()
        makeFirstResponder(textView)
    }

    func setText(_ text: String) {
        textView.string = text
        updateTitleFromText()
    }

    private func updateTitleFromText() {
        let firstLine = textView.string.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        title = trimmed.isEmpty ? "Quick Notepad" : trimmed
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
            onSave?(textView.string, .newEntry)
            return true
        }
        return false
    }

    func textDidChange(_ notification: Notification) {
        updateTitleFromText()
    }
}
