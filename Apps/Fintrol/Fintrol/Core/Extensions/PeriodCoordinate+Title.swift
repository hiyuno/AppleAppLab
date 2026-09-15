import Foundation

/// Full localized month name (no year), e.g. "Septiembre" (es) / "September" (en). Uses
/// `Date.FormatStyle`, which resolves the current locale properly — unlike
/// `Calendar.monthSymbols`, which returns generic "M09"-style placeholders on a `Calendar`
/// with no explicit `.locale` set (as `Calendar.gregorianUTC` deliberately has, for
/// deterministic date-only math — see that type's docs).
/// The same UTC zone `Calendar.gregorianUTC` uses — every `Date.FormatStyle` in this file
/// must be constructed with this as its `timeZone`, not just chain symbol modifiers onto
/// `.dateTime` (whose `.timeZone(_:)` only controls which time-zone *symbol* the output
/// text shows, e.g. "GMT+2" — it does NOT change which zone the date's components are
/// computed in; that's set only via the `Date.FormatStyle(timeZone:)` initializer).
private let utcTimeZone = TimeZone(identifier: "UTC")!

func localizedMonthName(_ month: Int, year: Int = 2000) -> String {
    let date = Calendar.gregorianUTC.date(from: DateComponents(year: year, month: month, day: 1))!
    // Bug (Avie): the Date is midnight UTC on day 1, but formatting it without pinning the
    // FormatStyle's own `timeZone` let it fall back to the device's local time zone — in
    // any UTC−N zone that reads as the LAST day of the PREVIOUS month, shifting the shown
    // month back by one ("August" for September). The formatter must use the same UTC zone
    // as the Calendar that built the Date.
    let style = Date.FormatStyle(timeZone: utcTimeZone).month(.wide)
    let formatted = date.formatted(style)
    guard let first = formatted.first else { return formatted }
    return String(first).uppercased() + formatted.dropFirst()
}

extension PeriodCoordinate {
    /// "Septiembre 2026" / "September 2026" — capitalized, localized month name + year.
    var monthYearTitle: String {
        let date = Calendar.gregorianUTC.date(from: DateComponents(year: year, month: month, day: 1))!
        let style = Date.FormatStyle(timeZone: utcTimeZone).month(.wide).year()
        let formatted = date.formatted(style)
        guard let first = formatted.first else { return formatted }
        return String(first).uppercased() + formatted.dropFirst()
    }

    /// "1 – 15" or "16 – <last day>", using the month's real last day (28/29/30/31).
    var dayRangeTitle: String {
        switch half {
        case .first:
            return "1 – 15"
        case .second:
            let firstOfMonth = Calendar.gregorianUTC.date(from: DateComponents(year: year, month: month, day: 1))!
            let lastDay = Calendar.gregorianUTC.range(of: .day, in: .month, for: firstOfMonth)!.count
            return "16 – \(lastDay)"
        }
    }

    /// Single-line combined form, for accessibility labels and compact contexts.
    var accessibleTitle: String { "\(monthYearTitle), \(dayRangeTitle)" }
}
