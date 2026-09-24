import Foundation
import QuickNotepadCore

enum NotesBridge {
    static let noteTitle = "Quick Capture"

    private static let queue = DispatchQueue(label: "com.priyam.quicknotepad.notesbridge")

    static func save(body: String, completion: @escaping (Result<Void, SaveError>) -> Void) {
        queue.async {
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
}
