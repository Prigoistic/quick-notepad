import Testing
import Foundation
@testable import QuickNotepadCore

@Suite struct NotesAppleScriptTests {
    @Test func scriptContainsEscapedNoteTitle() {
        let script = NotesAppleScript.saveScript(
            noteTitle: "Quick Capture",
            subheading: "Sep 24, 2026 · 3:41 PM",
            body: "hello"
        )
        #expect(script.contains("\"Quick Capture\""))
    }

    @Test func bodyHtmlEscapesSpecialCharacters() {
        let script = NotesAppleScript.saveScript(
            noteTitle: "Quick Capture",
            subheading: "Sep 24, 2026 · 3:41 PM",
            body: "Tom & Jerry <3"
        )
        #expect(script.contains("Tom &amp; Jerry &lt;3"))
        #expect(!script.contains("Tom & Jerry <3"))
    }

    @Test func bodyNewlinesBecomeSeparateDivs() {
        let script = NotesAppleScript.saveScript(
            noteTitle: "Quick Capture",
            subheading: "Sep 24, 2026 · 3:41 PM",
            body: "line one\nline two"
        )
        #expect(script.contains("<div>line one</div><div>line two</div>"))
    }

    @Test func embeddedQuoteIsEscapedForAppleScriptStringLiteral() {
        let script = NotesAppleScript.saveScript(
            noteTitle: "Quick Capture",
            subheading: "Sep 24, 2026 · 3:41 PM",
            body: "she said \"hi\""
        )
        #expect(script.contains("she said &quot;hi&quot;"))
    }

    @Test func titleWithQuoteIsEscapedAtAppleScriptLayer() {
        let script = NotesAppleScript.saveScript(
            noteTitle: "a\"b",
            subheading: "Sep 24, 2026 · 3:41 PM",
            body: "hello"
        )
        #expect(script.contains("\"a\\\"b\""))
    }

    @Test func backslashInBodyIsEscapedAtAppleScriptLayer() {
        let script = NotesAppleScript.saveScript(
            noteTitle: "Quick Capture",
            subheading: "Sep 24, 2026 · 3:41 PM",
            body: "C:\\path"
        )
        #expect(script.contains("C:\\\\path"))
    }

    @Test func generatedScriptCompilesForAdversarialInput() {
        let script = NotesAppleScript.saveScript(
            noteTitle: "Quick Capture",
            subheading: "Sep 24, 2026 · 3:41 PM",
            body: "\"quotes\" \\backslash & <tags>\nline two\n\nline four"
        )
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        let compiled = appleScript?.compileAndReturnError(&error) ?? false
        #expect(compiled)
        if !compiled {
            Issue.record("AppleScript failed to compile: \(String(describing: error))")
        }
    }
}
