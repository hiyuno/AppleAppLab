import Foundation

/// Pure, deterministic generation of quincena (biweekly period) date boundaries, entirely in
/// `CivilDate` (TRD "Decisiones de Swift" — Fechas). No SwiftData, no `Date` comparisons.
public enum PeriodDateEngine {
    /// Start/end civil dates (inclusive) covered by a given period coordinate.
    /// `.first` covers days 1–15 of the month; `.second` covers day 16 through the
    /// last calendar day of that month (28/29/30/31 depending on the month and,
    /// for February, leap-year status).
    public static func dateRange(for coordinate: PeriodCoordinate) -> (start: CivilDate, end: CivilDate) {
        switch coordinate.half {
        case .first:
            return (CivilDate(year: coordinate.year, month: coordinate.month, day: 1), CivilDate(year: coordinate.year, month: coordinate.month, day: 15))
        case .second:
            let lastDay = CivilDate.lastDay(year: coordinate.year, month: coordinate.month)
            return (CivilDate(year: coordinate.year, month: coordinate.month, day: 16), CivilDate(year: coordinate.year, month: coordinate.month, day: lastDay))
        }
    }

    /// The coordinate of the quincena that contains `date`. `date` must already be normalized
    /// to the user's local wall-clock day (`CivilDate.today()` at the UI boundary) — this
    /// function itself is pure day-of-month classification, no time zone involved anymore.
    public static func coordinate(containing date: CivilDate) -> PeriodCoordinate {
        PeriodCoordinate(year: date.year, month: date.month, half: date.day <= 15 ? .first : .second)
    }

    /// A concrete civil date for `day` within the month of `coordinate`, clamped to the last
    /// valid day of that month (e.g. day 31 in February resolves to the 28th/29th).
    public static func date(forDayOfMonth day: Int, in coordinate: PeriodCoordinate) -> CivilDate {
        CivilDate(year: coordinate.year, month: coordinate.month, day: day).clampedToValidDay
    }

    /// TRD "Límite de navegación hacia atrás" (2026-09-16): `months` civil months before
    /// `date` (same month arithmetic `LoanEngine` already uses for terms — `CivilDate.
    /// addingMonths`), always resolved to that month's `.first` half — "Historial visible"
    /// is a whole-month setting, never a partial quincena. Pure, no `ModelContext`; combining
    /// this with the first-materialized-period floor is `PeriodCoordinator.
    /// navigableLowerBound(context:monthsBack:)`.
    public static func monthsAgoCoordinate(from date: CivilDate, months: Int) -> PeriodCoordinate {
        let target = date.addingMonths(-months)
        return PeriodCoordinate(year: target.year, month: target.month, half: .first)
    }
}
