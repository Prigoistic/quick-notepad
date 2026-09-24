import Testing
@testable import QuickNotepadCore

@Suite struct SaveErrorTests {
    @Test func compileFailureMessageIncludesReason() {
        let error = SaveError.appleScriptCompileFailed("syntax error")
        #expect(error.userMessage == "Couldn't save: syntax error")
    }

    @Test func runtimeFailureMessageIncludesReason() {
        let error = SaveError.appleScriptRuntimeFailed("Notes got an error: Can't get note")
        #expect(error.userMessage == "Couldn't save: Notes got an error: Can't get note")
    }
}
