import Foundation

/// A calendar date with no time-of-day or time zone — year/month/day only. The single
/// date representation for all of `Core/Engine` (TRD "Decisiones de Swift" — Fechas).
///
/// Real bug this fixes: `PeriodDateEngine`/`LoanEngine` built date boundaries at UTC
/// midnight (`Calendar.gregorianUTC`) while `RecurringItem`/`Subscription`/`Loan` dates came
/// from a `DatePicker` as **local** midnight, and `ProjectionEngine.isVigente` compared those
/// raw `Date` values directly. In any UTC−N zone the mismatch shifted classification by a day
/// — near a quincena boundary a recurring item could evaluate as vigente in two quincenas
/// (duplicated) or none (missing). `Date` now only exists at the UI boundary: a `DatePicker`
/// normalizes to `CivilDate` via `Calendar.current` the moment it's saved, and `CivilDate`
/// only turns back into a `Date` to feed a `DatePicker` or a display formatter — never for a
/// business-logic comparison.
public struct CivilDate: Codable, Hashable, Sendable, Comparable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Normalizes a `Date` (e.g. straight from a `DatePicker`) to its civil year/month/day
    /// using `calendar` — pass `.current` at the UI boundary, always.
    public init(from date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = components.year ?? 1970
        self.month = components.month ?? 1
        self.day = components.day ?? 1
    }

    /// "Today" as the device sees it right now — the one place `Date()` is allowed to enter
    /// `Core/Engine` logic, always through this normalization.
    public static func today(calendar: Calendar = .current) -> CivilDate {
        CivilDate(from: Date(), calendar: calendar)
    }

    /// Reconstructs a `Date` at local midnight for this civil date — only for feeding a
    /// `DatePicker` or a display formatter, never for a business-logic comparison.
    public func date(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    public static func < (lhs: CivilDate, rhs: CivilDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    // MARK: - Pure calendar arithmetic (no time zone involved — safe to route through a
    // fixed neutral calendar, unlike comparing/constructing a real `Date` moment in time).

    private static var arithmeticCalendar: Calendar { .gregorianUTC }

    private var asNeutralDate: Date {
        Self.arithmeticCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private static func civilDate(from date: Date) -> CivilDate {
        let c = arithmeticCalendar.dateComponents([.year, .month, .day], from: date)
        return CivilDate(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    /// The real last day of `self`'s month (28-31). Deliberately anchors to day 1 of the
    /// month, not `asNeutralDate` — an out-of-range `day` (e.g. 31 in February, exactly the
    /// case `clampedToValidDay` exists to handle) would otherwise let `Calendar.date(from:)`
    /// silently roll the overflow into the next month before `range(of:in:)` ever saw the
    /// right one, defeating the clamp entirely.
    public var daysInMonth: Int {
        let firstOfMonth = Self.arithmeticCalendar.date(from: DateComponents(year: year, month: month, day: 1))!
        return Self.arithmeticCalendar.range(of: .day, in: .month, for: firstOfMonth)!.count
    }

    /// This civil date with the day clamped to the last valid day of its month (e.g. day 31
    /// in a 30-day month clamps to 30).
    public var clampedToValidDay: CivilDate {
        CivilDate(year: year, month: month, day: min(day, daysInMonth))
    }

    /// Adds whole months, clamping the day to the target month's last valid day.
    public func addingMonths(_ months: Int) -> CivilDate {
        var comps = DateComponents(year: year, month: month + months, day: 1)
        let firstOfTarget = Self.arithmeticCalendar.date(from: comps)!
        let lastDay = Self.arithmeticCalendar.range(of: .day, in: .month, for: firstOfTarget)!.count
        comps.day = min(day, lastDay)
        return Self.civilDate(from: Self.arithmeticCalendar.date(from: comps)!)
    }

    public func addingDays(_ days: Int) -> CivilDate {
        Self.civilDate(from: Self.arithmeticCalendar.date(byAdding: .day, value: days, to: asNeutralDate)!)
    }

    /// Whole months from `self` to `other` (can be negative if `other` is earlier).
    public func wholeMonths(to other: CivilDate) -> Int {
        Self.arithmeticCalendar.dateComponents([.month], from: asNeutralDate, to: other.asNeutralDate).month ?? 0
    }

    public static func lastDay(year: Int, month: Int) -> Int {
        let first = arithmeticCalendar.date(from: DateComponents(year: year, month: month, day: 1))!
        return arithmeticCalendar.range(of: .day, in: .month, for: first)!.count
    }
}
