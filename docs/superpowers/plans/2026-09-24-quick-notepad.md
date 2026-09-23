# Quick Notepad Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Swift/AppKit background agent that opens a floating notepad over any app/Space via `Cmd+Shift+N` and appends what's typed into a single "Quick Capture" note in Apple Notes.

**Architecture:** A Swift Package with two source targets — `QuickNotepadCore` (pure, unit-testable logic: timestamp formatting, AppleScript source generation, error types) and `QuickNotepad` (the executable: Carbon global hotkey, the floating `NSPanel`, the `NSAppleScript` bridge to Notes, and the wiring between them). Packaged into a `.app` bundle with `LSUIElement = true` and installed as a LaunchAgent so it starts at login with no Dock icon.

**Tech Stack:** Swift 6.2 (Swift Package Manager, no Xcode project), AppKit, Carbon `RegisterEventHotKey`, `NSAppleScript`, XCTest.

## Global Constraints

- Global hotkey is `Cmd+Shift+N` (spec decision — deliberately not `Cmd+N` to avoid clashing with the frontmatter app's own "New" shortcut).
- Save target is always a single note titled exactly `Quick Capture` in the default Notes account — append-only, never overwrite/reorder existing content.
- Unsaved text must never be silently discarded: on `Escape` or on save failure, the panel keeps the typed text.
- No App Store / third-party app dependency — everything here is code in this repo, built locally.
- Repo root: `/Users/priyamghosh/Documents/GitHub/quick-notepad`. Do not add Claude/AI co-author lines to commits in this repo (per user instruction).

---

### Task 1: Package scaffolding

**Files:**
- Create: `Package.swift`
- Create: `Sources/QuickNotepadCore/DateFormatting.swift`
- Create: `Sources/QuickNotepad/main.swift`
- Create: `Tests/QuickNotepadCoreTests/DateFormattingTests.swift`

**Interfaces:**
- Produces: package targets `QuickNotepadCore` (library), `QuickNotepad` (executable, depends on `QuickNotepadCore`), `QuickNotepadCoreTests` (test target, depends on `QuickNotepadCore`).

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "QuickNotepad",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "QuickNotepadCore"
        ),
        .executableTarget(
            name: "QuickNotepad",
            dependencies: ["QuickNotepadCore"]
        ),
        .testTarget(
            name: "QuickNotepadCoreTests",
            dependencies: ["QuickNotepadCore"]
        ),
    ]
)
```

- [ ] **Step 2: Add placeholder source files so the package builds**

`Sources/QuickNotepadCore/DateFormatting.swift`:

```swift
import Foundation

enum DateFormatting {}
```

`Sources/QuickNotepad/main.swift`:

```swift
print("QuickNotepad starting…")
```

- [ ] **Step 3: Add a placeholder test file**

`Tests/QuickNotepadCoreTests/DateFormattingTests.swift`:

```swift
import XCTest
@testable import QuickNotepadCore

final class DateFormattingTests: XCTestCase {
    func testPlaceholder() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 4: Verify the package builds and tests run**

Run: `swift build`
Expected: `Build complete!` with no errors.

Run: `swift test`
Expected: `Test Suite 'All tests' passed` (1 test).

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "chore: scaffold Swift package structure"
```

---

### Task 2: Timestamp formatter for note subheadings

**Files:**
- Modify: `Sources/QuickNotepadCore/DateFormatting.swift`
- Modify: `Tests/QuickNotepadCoreTests/DateFormattingTests.swift`

**Interfaces:**
- Produces: `DateFormatting.subheading(for date: Date) -> String`, used by `NotesAppleScript.saveScript` (Task 3) and by `AppState` (Task 8).

- [ ] **Step 1: Write the failing test**

Replace the placeholder test in `Tests/QuickNotepadCoreTests/DateFormattingTests.swift`:

```swift
import XCTest
@testable import QuickNotepadCore

final class DateFormattingTests: XCTestCase {
    func testSubheadingFormatsDateAndTime() {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 24
        components.hour = 15
        components.minute = 41
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        let date = calendar.date(from: components)!

        let result = DateFormatting.subheading(for: date, timeZone: calendar.timeZone)

        XCTAssertEqual(result, "Sep 24, 2026 · 3:41 PM")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DateFormattingTests`
Expected: FAIL — `subheading(for:timeZone:)` does not exist on `DateFormatting`.

- [ ] **Step 3: Implement the formatter**

Replace `Sources/QuickNotepadCore/DateFormatting.swift`:

```swift
import Foundation

public enum DateFormatting {
    public static func subheading(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy · h:mm a"
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter DateFormattingTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickNotepadCore/DateFormatting.swift Tests/QuickNotepadCoreTests/DateFormattingTests.swift
git commit -m "feat: add date-time subheading formatter"
```

---

### Task 3: AppleScript source generator for saving into Notes

**Files:**
- Create: `Sources/QuickNotepadCore/NotesAppleScript.swift`
- Create: `Tests/QuickNotepadCoreTests/NotesAppleScriptTests.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks (pure string manipulation only; the caller passes an already-formatted subheading string, e.g. from `DateFormatting.subheading(for:)`).
- Produces: `NotesAppleScript.saveScript(noteTitle: String, subheading: String, body: String) -> String`, used by `NotesBridge` (Task 5).

Notes stores note bodies as HTML. This function must: (1) HTML-escape `subheading` and `body` so raw `&`/`<`/`>` in typed text can't break the note's markup, (2) turn each line of `body` into its own `<div>` (Notes represents paragraphs as divs; a raw `\n` does not render as a line break), and (3) escape the resulting HTML for embedding inside an AppleScript string literal (backslashes and double quotes — AppleScript string literals do support raw embedded newlines, so no newline escaping is needed at the AppleScript layer).

- [ ] **Step 1: Write the failing tests**

`Tests/QuickNotepadCoreTests/NotesAppleScriptTests.swift`:

```swift
import XCTest
@testable import QuickNotepadCore

final class NotesAppleScriptTests: XCTestCase {
    func testScriptContainsEscapedNoteTitle() {
        let script = NotesAppleScript.saveScript(
            noteTitle: "Quick Capture",
            subheading: "Sep 24, 2026 · 3:41 PM",
            body: "hello"
        )
        XCTAssertTrue(script.contains("\"Quick Capture\""))
    }

    func testBodyHtmlEscapesSpecialCharacters() {
        let script = NotesAppleScript.saveScript(
            noteTitle: "Quick Capture",
            subheading: "Sep 24, 2026 · 3:41 PM",
            body: "Tom & Jerry <3"
        )
        XCTAssertTrue(script.contains("Tom &amp; Jerry &lt;3"))
        XCTAssertFalse(script.contains("Tom & Jerry <3"))
    }

    func testBodyNewlinesBecomeSeparateDivs() {
        let script = NotesAppleScript.saveScript(
            noteTitle: "Quick Capture",
            subheading: "Sep 24, 2026 · 3:41 PM",
            body: "line one\nline two"
        )
        XCTAssertTrue(script.contains("<div>line one</div><div>line two</div>"))
    }

    func testEmbeddedQuoteIsEscapedForAppleScriptStringLiteral() {
        let script = NotesAppleScript.saveScript(
            noteTitle: "Quick Capture",
            subheading: "Sep 24, 2026 · 3:41 PM",
            body: "she said \"hi\""
        )
        XCTAssertTrue(script.contains("she said &quot;hi&quot;"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter NotesAppleScriptTests`
Expected: FAIL — `NotesAppleScript` does not exist.

- [ ] **Step 3: Implement the generator**

`Sources/QuickNotepadCore/NotesAppleScript.swift`:

```swift
import Foundation

public enum NotesAppleScript {
    public static func saveScript(noteTitle: String, subheading: String, body: String) -> String {
        let htmlSubheading = htmlEscape(subheading)
        let htmlBody = body
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "<div>\(htmlEscape(String($0)))</div>" }
            .joined()

        let appendedBlock = "<div><br/></div><div><b>\(htmlSubheading)</b></div>\(htmlBody)"
        let appleScriptSafeBlock = appleScriptEscape(appendedBlock)
        let appleScriptSafeTitle = appleScriptEscape(noteTitle)

        return """
        tell application "Notes"
            activate
            set targetTitle to "\(appleScriptSafeTitle)"
            set foundNote to missing value
            repeat with n in notes of default account
                if name of n is targetTitle then
                    set foundNote to n
                    exit repeat
                end if
            end repeat
            if foundNote is missing value then
                set foundNote to make new note at default account with properties {name:targetTitle, body:targetTitle}
            end if
            set body of foundNote to (body of foundNote) & "\(appleScriptSafeBlock)"
        end tell
        """
    }

    private static func htmlEscape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func appleScriptEscape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter NotesAppleScriptTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickNotepadCore/NotesAppleScript.swift Tests/QuickNotepadCoreTests/NotesAppleScriptTests.swift
git commit -m "feat: generate AppleScript source for appending into Notes"
```

---

### Task 4: Save error type and user-facing messages

**Files:**
- Create: `Sources/QuickNotepadCore/SaveError.swift`
- Create: `Tests/QuickNotepadCoreTests/SaveErrorTests.swift`

**Interfaces:**
- Produces: `enum SaveError: Error, Equatable { case appleScriptCompileFailed(String); case appleScriptRuntimeFailed(String) }` and `SaveError.userMessage: String`, used by `NotesBridge` (Task 5) and `NotepadPanel`/`AppState` (Tasks 7–8) to show the inline error.

- [ ] **Step 1: Write the failing test**

`Tests/QuickNotepadCoreTests/SaveErrorTests.swift`:

```swift
import XCTest
@testable import QuickNotepadCore

final class SaveErrorTests: XCTestCase {
    func testCompileFailureMessageIncludesReason() {
        let error = SaveError.appleScriptCompileFailed("syntax error")
        XCTAssertEqual(error.userMessage, "Couldn't save: syntax error")
    }

    func testRuntimeFailureMessageIncludesReason() {
        let error = SaveError.appleScriptRuntimeFailed("Notes got an error: Can't get note")
        XCTAssertEqual(error.userMessage, "Couldn't save: Notes got an error: Can't get note")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SaveErrorTests`
Expected: FAIL — `SaveError` does not exist.

- [ ] **Step 3: Implement the error type**

`Sources/QuickNotepadCore/SaveError.swift`:

```swift
import Foundation

public enum SaveError: Error, Equatable {
    case appleScriptCompileFailed(String)
    case appleScriptRuntimeFailed(String)

    public var userMessage: String {
        switch self {
        case .appleScriptCompileFailed(let reason), .appleScriptRuntimeFailed(let reason):
            return "Couldn't save: \(reason)"
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SaveErrorTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickNotepadCore/SaveError.swift Tests/QuickNotepadCoreTests/SaveErrorTests.swift
git commit -m "feat: add save error type with user-facing messages"
```

---

### Task 5: NotesBridge — execute the generated AppleScript against Notes

**Files:**
- Create: `Sources/QuickNotepad/NotesBridge.swift`

**Interfaces:**
- Consumes: `NotesAppleScript.saveScript(noteTitle:subheading:body:)` (Task 3), `SaveError` (Task 4), `DateFormatting.subheading(for:)` (Task 2).
- Produces: `NotesBridge.save(body: String, completion: @escaping (Result<Void, SaveError>) -> Void)`, used by `AppState` (Task 8).

This task drives the real Notes app via `NSAppleScript`, so it cannot be exercised by XCTest in CI-like isolation — the deliverable is verified manually against the real Notes app once wired into the running app in Task 8. No automated test step here; this task only adds the implementation.

- [ ] **Step 1: Implement `NotesBridge`**

`Sources/QuickNotepad/NotesBridge.swift`:

```swift
import Foundation
import QuickNotepadCore

enum NotesBridge {
    static let noteTitle = "Quick Capture"

    static func save(body: String, completion: @escaping (Result<Void, SaveError>) -> Void) {
        let subheading = DateFormatting.subheading(for: Date())
        let source = NotesAppleScript.saveScript(noteTitle: noteTitle, subheading: subheading, body: body)

        guard let script = NSAppleScript(source: source) else {
            completion(.failure(.appleScriptCompileFailed("could not parse generated script")))
            return
        }

        var compileError: NSDictionary?
        if !script.compileAndReturnError(&compileError) {
            let message = compileError?[NSAppleScript.errorMessage] as? String ?? "unknown compile error"
            completion(.failure(.appleScriptCompileFailed(message)))
            return
        }

        var runtimeError: NSDictionary?
        script.executeAndReturnError(&runtimeError)
        if let runtimeError {
            let message = runtimeError[NSAppleScript.errorMessage] as? String ?? "unknown runtime error"
            completion(.failure(.appleScriptRuntimeFailed(message)))
            return
        }

        completion(.success(()))
    }
}
```

- [ ] **Step 2: Verify the package still builds**

Run: `swift build`
Expected: `Build complete!` with no errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/QuickNotepad/NotesBridge.swift
git commit -m "feat: add NotesBridge to execute generated AppleScript"
```

---

### Task 6: HotkeyManager — global Cmd+Shift+N registration

**Files:**
- Create: `Sources/QuickNotepad/HotkeyManager.swift`

**Interfaces:**
- Produces: `final class HotkeyManager { init(onTrigger: @escaping () -> Void) throws; }`, used by `AppState` (Task 8). Throws `HotkeyError.registrationFailed(OSStatus)` if `RegisterEventHotKey` fails.

- [ ] **Step 1: Implement `HotkeyManager`**

`Sources/QuickNotepad/HotkeyManager.swift`:

```swift
import Carbon
import AppKit

enum HotkeyError: Error {
    case registrationFailed(OSStatus)
}

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let onTrigger: () -> Void

    private static let signature: OSType = 0x514E_5450 // 'QNTP'
    private static let hotKeyID: UInt32 = 1

    init(onTrigger: @escaping () -> Void) throws {
        self.onTrigger = onTrigger

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onTrigger()
            return noErr
        }, 1, &eventType, selfPointer, &eventHandler)

        var hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.hotKeyID)
        let cmdShiftMask = UInt32(cmdKey | shiftKey)
        let keyCodeForN: UInt32 = 45 // kVK_ANSI_N

        let status = RegisterEventHotKey(keyCodeForN, cmdShiftMask, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else {
            throw HotkeyError.registrationFailed(status)
        }
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}
```

- [ ] **Step 2: Verify the package builds**

Run: `swift build`
Expected: `Build complete!` with no errors.

- [ ] **Step 3: Manual verification (deferred to Task 8)**

Global hotkey firing can only be observed once wired to a visible action, so functional verification happens in Task 8's manual test. No standalone test here.

- [ ] **Step 4: Commit**

```bash
git add Sources/QuickNotepad/HotkeyManager.swift
git commit -m "feat: register global Cmd+Shift+N hotkey via Carbon"
```

---

### Task 7: NotepadPanel — floating text panel over any Space/fullscreen app

**Files:**
- Create: `Sources/QuickNotepad/NotepadPanel.swift`

**Interfaces:**
- Produces: `final class NotepadPanel: NSPanel { var onSave: ((String) -> Void)?; var onDismiss: (() -> Void)?; func showAndFocus(withText text: String); func setText(_ text: String); func currentText() -> String; func showError(_ message: String) }`, used by `AppState` (Task 8).

- [ ] **Step 1: Implement `NotepadPanel`**

`Sources/QuickNotepad/NotepadPanel.swift`:

```swift
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
```

- [ ] **Step 2: Verify the package builds**

Run: `swift build`
Expected: `Build complete!` with no errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/QuickNotepad/NotepadPanel.swift
git commit -m "feat: add floating notepad panel that joins all Spaces"
```

---

### Task 8: AppState — wire hotkey, panel, and save together; app entry point

**Files:**
- Create: `Sources/QuickNotepad/AppState.swift`
- Modify: `Sources/QuickNotepad/main.swift`

**Interfaces:**
- Consumes: `HotkeyManager` (Task 6), `NotepadPanel` (Task 7), `NotesBridge.save` (Task 5).
- Produces: `final class AppState: NSObject, NSApplicationDelegate`, instantiated once in `main.swift`.

- [ ] **Step 1: Implement `AppState`**

`Sources/QuickNotepad/AppState.swift`:

```swift
import AppKit

final class AppState: NSObject, NSApplicationDelegate {
    private var panel: NotepadPanel!
    private var hotkeyManager: HotkeyManager!
    private var statusItem: NSStatusItem!
    private var pendingText: String = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = NotepadPanel()
        panel.onSave = { [weak self] text in
            self?.handleSave(text: text)
        }
        panel.onDismiss = { [weak self] in
            self?.pendingText = self?.panel.currentText() ?? ""
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusBar.squareLength)
        statusItem.button?.title = "N"
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit Quick Notepad", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu

        do {
            hotkeyManager = try HotkeyManager { [weak self] in
                self?.togglePanel()
            }
        } catch {
            NSLog("QuickNotepad: failed to register global hotkey: \(error)")
        }
    }

    private func togglePanel() {
        panel.showAndFocus(withText: pendingText)
    }

    private func handleSave(text: String) {
        guard !text.isEmpty else {
            pendingText = ""
            panel.orderOut(nil)
            return
        }
        NotesBridge.save(body: text) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    self.pendingText = ""
                    self.panel.setText("")
                    self.panel.orderOut(nil)
                case .failure(let error):
                    self.pendingText = text
                    self.panel.showError(error.userMessage)
                }
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
```

- [ ] **Step 2: Wire it up in `main.swift`**

Replace `Sources/QuickNotepad/main.swift`:

```swift
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let appState = AppState()
app.delegate = appState
app.run()
```

- [ ] **Step 3: Verify the package builds**

Run: `swift build`
Expected: `Build complete!` with no errors.

- [ ] **Step 4: Manual functional test**

Run: `swift run QuickNotepad` (leave it running in a terminal)

- [ ] Press `Cmd+Shift+N` — the panel appears and is immediately focused for typing.
- [ ] Type some text, press `Cmd+Enter` — panel clears and hides; open Notes.app and confirm a "Quick Capture" note now has a bold date-time subheading followed by your text.
- [ ] Press `Cmd+Shift+N` again, type more text, press `Cmd+Enter` — confirm it appended below the first entry without altering it.
- [ ] Press `Cmd+Shift+N`, type text, press `Escape` — panel hides; press `Cmd+Shift+N` again and confirm the unsaved text is still there.
- [ ] Quit Notes.app entirely, then trigger a save from the panel — confirm Notes launches automatically and the save still succeeds.

Stop the running process with `Ctrl+C` when done.

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickNotepad/AppState.swift Sources/QuickNotepad/main.swift
git commit -m "feat: wire hotkey, panel, and Notes save into running app"
```

---

### Task 9: App bundle assembly (`build-app.sh`)

**Files:**
- Create: `Scripts/build-app.sh`

**Interfaces:**
- Consumes: the `QuickNotepad` executable produced by `swift build -c release`.
- Produces: `QuickNotepad.app` bundle at the repo root (git-ignored build artifact), used by `install.sh` (Task 10).

- [ ] **Step 1: Write the build script**

`Scripts/build-app.sh`:

```bash
#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="QuickNotepad"
APP_BUNDLE="$REPO_ROOT/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"

cd "$REPO_ROOT"
swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS"

cp ".build/release/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.priyam.quicknotepad</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
PLIST

echo "Built $APP_BUNDLE"
```

- [ ] **Step 2: Make it executable and run it**

Run: `chmod +x Scripts/build-app.sh && ./Scripts/build-app.sh`
Expected: ends with `Built /Users/priyamghosh/Documents/GitHub/quick-notepad/QuickNotepad.app`

- [ ] **Step 3: Manual verification**

Run: `open QuickNotepad.app`

- [ ] Confirm no Dock icon appears.
- [ ] Confirm `Cmd+Shift+N` still opens the panel and save still works, same as Task 8's manual test.
- [ ] Quit it via the menu bar item's "Quit Quick Notepad".

- [ ] **Step 4: Ignore build artifacts and commit the script**

Create/append `.gitignore` at repo root:

```
.build/
QuickNotepad.app/
```

```bash
git add Scripts/build-app.sh .gitignore
git commit -m "build: add script to assemble QuickNotepad.app bundle"
```

---

### Task 10: LaunchAgent install script (auto-start at login)

**Files:**
- Create: `LaunchAgent/com.priyam.quicknotepad.plist`
- Create: `Scripts/install.sh`

**Interfaces:**
- Consumes: `QuickNotepad.app` bundle produced by Task 9.
- Produces: a running LaunchAgent that survives logout/login.

- [ ] **Step 1: Write the LaunchAgent plist**

`LaunchAgent/com.priyam.quicknotepad.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.priyam.quicknotepad</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/priyamghosh/Applications/QuickNotepad.app/Contents/MacOS/QuickNotepad</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardErrorPath</key>
    <string>/Users/priyamghosh/Library/Logs/QuickNotepad.log</string>
    <key>StandardOutPath</key>
    <string>/Users/priyamghosh/Library/Logs/QuickNotepad.log</string>
</dict>
</plist>
```

- [ ] **Step 2: Write the install script**

`Scripts/install.sh`:

```bash
#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="QuickNotepad"
DEST_APPS="$HOME/Applications"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST_NAME="com.priyam.quicknotepad.plist"

mkdir -p "$DEST_APPS" "$LAUNCH_AGENTS"

rm -rf "$DEST_APPS/$APP_NAME.app"
cp -R "$REPO_ROOT/$APP_NAME.app" "$DEST_APPS/$APP_NAME.app"

cp "$REPO_ROOT/LaunchAgent/$PLIST_NAME" "$LAUNCH_AGENTS/$PLIST_NAME"

launchctl unload "$LAUNCH_AGENTS/$PLIST_NAME" 2>/dev/null || true
launchctl load "$LAUNCH_AGENTS/$PLIST_NAME"

echo "Installed to $DEST_APPS/$APP_NAME.app and loaded LaunchAgent."
```

- [ ] **Step 3: Run it**

Run: `chmod +x Scripts/install.sh && ./Scripts/install.sh`
Expected: `Installed to /Users/priyamghosh/Applications/QuickNotepad.app and loaded LaunchAgent.`

- [ ] **Step 4: Manual verification (full checklist from the spec)**

- [ ] `Cmd+Shift+N` opens the panel over a fullscreen browser window without switching Spaces.
- [ ] `Cmd+Shift+N` opens the panel while on a different Space (e.g. a fullscreen PDF/WhatsApp).
- [ ] Typing registers immediately on open, no click required.
- [ ] `Cmd+Enter` saves, appends correctly under a new date-time subheading, and does not alter prior note content.
- [ ] Deleting the "Quick Capture" note in Notes and then saving again recreates it correctly.
- [ ] Quitting Notes.app, then saving from the panel, launches Notes and still saves correctly.
- [ ] `Escape` hides the panel without saving, and reopening restores the unsaved text.
- [ ] Log out and back in — confirm the menu bar "N" item reappears without manually relaunching anything (check `~/Library/Logs/QuickNotepad.log` if it doesn't).

- [ ] **Step 5: Commit**

```bash
git add LaunchAgent/com.priyam.quicknotepad.plist Scripts/install.sh
git commit -m "build: add LaunchAgent install script for login auto-start"
```
