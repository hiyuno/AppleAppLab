import Foundation

extension Calendar {
    /// Gregorian calendar pinned to UTC so date-only math (quincena boundaries) is
    /// deterministic regardless of the device's local time zone or DST transitions.
    public static var gregorianUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
}
