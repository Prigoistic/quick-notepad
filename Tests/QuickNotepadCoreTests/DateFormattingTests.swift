import Testing
import Foundation
@testable import QuickNotepadCore

@Suite struct DateFormattingTests {
    @Test func subheadingFormatsDateAndTime() {
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

        #expect(result == "Sep 24, 2026 · 3:41 PM")
    }
}
