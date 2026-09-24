import Testing
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
}
