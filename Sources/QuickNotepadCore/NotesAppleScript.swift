import Foundation

public enum NotesAppleScript {
    public static func saveScript(noteTitle: String, subheading: String, body: String) -> String {
        let htmlSubheading = htmlEscape(subheading)
        let htmlBody = body
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { line -> String in
                let escaped = htmlEscape(String(line))
                return escaped.isEmpty ? "<div><br></div>" : "<div>\(escaped)</div>"
            }
            .joined()

        let appendedBlock = "<div><br/></div><div><b>\(htmlSubheading)</b></div>\(htmlBody)"
        let appleScriptSafeBlock = appleScriptEscape(appendedBlock)
        let appleScriptSafeTitle = appleScriptEscape(noteTitle)

        return """
        tell application "Notes"
            set targetTitle to "\(appleScriptSafeTitle)"
            set foundNote to missing value
            repeat with n in notes of default account
                if name of n is targetTitle and (name of container of n) is not "Recently Deleted" then
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
