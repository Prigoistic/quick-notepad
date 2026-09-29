import Foundation

public enum NotesAppleScript {
    /// - Parameter subheading: a bold timestamp heading to insert before the body
    ///   (a fresh "New" entry), or `nil` to append the body directly after the
    ///   last entry with no new heading (a "Continue" entry).
    public static func saveScript(noteTitle: String, subheading: String?, body: String) -> String {
        let htmlBody = body
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { line -> String in
                let escaped = htmlEscape(String(line))
                return escaped.isEmpty ? "<div><br></div>" : "<div>\(escaped)</div>"
            }
            .joined()

        let headingBlock = subheading.map { "<div><b>\(htmlEscape($0))</b></div>" } ?? ""
        let appendedBlock = "<div><br/></div>\(headingBlock)\(htmlBody)"
        let appleScriptSafeBlock = appleScriptEscape(appendedBlock)
        let appleScriptSafeTitle = appleScriptEscape(noteTitle)

        return """
        tell application "Notes"
            set targetTitle to "\(appleScriptSafeTitle)"
            set foundNote to missing value
            set allNotes to notes of default account
            repeat with i from 1 to count of allNotes
                set thisNote to item i of allNotes
                if name of thisNote is targetTitle then
                    set containerName to ""
                    try
                        set containerName to name of container of thisNote
                    end try
                    if containerName is not "Recently Deleted" then
                        set foundNote to thisNote
                        exit repeat
                    end if
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
