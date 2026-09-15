import Testing
import Foundation
@testable import Fintrol

@Suite("PeriodCoordinate title formatting")
struct PeriodCoordinateTitleTests {
    @Test("dayRangeTitle uses the real last day of the month for the second half")
    func dayRangeUsesRealLastDay() {
        #expect(PeriodCoordinate(year: 2026, month: 1, half: .second).dayRangeTitle == "16 – 31")
        #expect(PeriodCoordinate(year: 2026, month: 4, half: .second).dayRangeTitle == "16 – 30")
        #expect(PeriodCoordinate(year: 2026, month: 2, half: .second).dayRangeTitle == "16 – 28")
        #expect(PeriodCoordinate(year: 2028, month: 2, half: .second).dayRangeTitle == "16 – 29")
    }

    @Test("First half is always 1 – 15")
    func firstHalfIsFixed() {
        #expect(PeriodCoordinate(year: 2026, month: 9, half: .first).dayRangeTitle == "1 – 15")
    }

    @Test("monthYearTitle never falls back to generic M09-style placeholders")
    func monthYearTitleIsNotGenericPlaceholder() {
        let title = PeriodCoordinate(year: 2026, month: 9, half: .first).monthYearTitle
        #expect(!title.hasPrefix("M09"))
        #expect(title.contains("2026"))
    }

    @Test("localizedMonthName never falls back to a generic M-prefixed placeholder")
    func localizedMonthNameIsNotGenericPlaceholder() {
        for month in 1...12 {
            let name = localizedMonthName(month)
            #expect(!name.hasPrefix("M\(String(format: "%02d", month))"))
        }
    }

    // MARK: - Bug (Avie): month names must not shift by a device's time zone.

    @Test("monthYearTitle for September never regresses to August due to a negative UTC offset")
    func monthYearTitleDoesNotShiftBackAMonth() {
        let title = PeriodCoordinate(year: 2026, month: 9, half: .first).monthYearTitle
        #expect(!title.lowercased().contains("agosto"))
        #expect(!title.lowercased().contains("august"))
    }

    @Test("Regression: a UTC-midnight Date on day 1 still formats to September under a negative-offset time zone (America/Los_Angeles) once .timeZone is pinned on the FormatStyle — a fixed es_MX locale makes the expected string deterministic across CI")
    func monthFormattingIsImmuneToNegativeUTCOffset() {
        // Same construction `monthYearTitle`/`localizedMonthName` use internally: midnight UTC
        // on day 1 of the month, via `Calendar.gregorianUTC`.
        let date = Calendar.gregorianUTC.date(from: DateComponents(year: 2026, month: 9, day: 1))!

        // Without pinning `.timeZone` on the FormatStyle, formatting this exact Date under
        // America/Los_Angeles (UTC−7 in September, DST) rolls it back to 31 Aug local time —
        // reproducing the original bug. Pinning `.timeZone(UTC)` on the FormatStyle itself
        // (the fix applied to `monthYearTitle`/`localizedMonthName`) keeps it September
        // regardless of what the ambient/device time zone is.
        let buggyStyle = Date.FormatStyle(timeZone: TimeZone(identifier: "America/Los_Angeles")!)
            .month(.wide).year()
            .locale(Locale(identifier: "es_MX"))
        let buggyIfUnpinned = date.formatted(buggyStyle)
        #expect(buggyIfUnpinned.lowercased().contains("agosto"), "sanity check: proves the bug is real without the .timeZone(UTC) pin")

        let fixedStyle = Date.FormatStyle(timeZone: TimeZone(identifier: "UTC")!)
            .month(.wide).year()
            .locale(Locale(identifier: "es_MX"))
        let fixed = date.formatted(fixedStyle)
        #expect(fixed.lowercased().contains("septiembre"))
        #expect(fixed.contains("2026"))
    }
}
