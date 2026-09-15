import Testing
import Foundation
@testable import Fintrol

@Suite("PeriodDateEngine")
struct PeriodDateEngineTests {
    @Test("First half of month is days 1-15")
    func firstHalfRange() {
        let range = PeriodDateEngine.dateRange(for: PeriodCoordinate(year: 2026, month: 3, half: .first))
        #expect(range.start == CivilDate(year: 2026, month: 3, day: 1))
        #expect(range.end == CivilDate(year: 2026, month: 3, day: 15))
    }

    @Test("Second half ends on the last day of a 31-day month")
    func secondHalf31DayMonth() {
        let range = PeriodDateEngine.dateRange(for: PeriodCoordinate(year: 2026, month: 1, half: .second))
        #expect(range.start == CivilDate(year: 2026, month: 1, day: 16))
        #expect(range.end == CivilDate(year: 2026, month: 1, day: 31))
    }

    @Test("Second half ends on the 30th for a 30-day month")
    func secondHalf30DayMonth() {
        let range = PeriodDateEngine.dateRange(for: PeriodCoordinate(year: 2026, month: 4, half: .second))
        #expect(range.end == CivilDate(year: 2026, month: 4, day: 30))
    }

    @Test("February in a non-leap year ends on the 28th")
    func februaryNonLeapYear() {
        let range = PeriodDateEngine.dateRange(for: PeriodCoordinate(year: 2026, month: 2, half: .second))
        #expect(range.end == CivilDate(year: 2026, month: 2, day: 28))
    }

    @Test("February in a leap year ends on the 29th")
    func februaryLeapYear() {
        let range = PeriodDateEngine.dateRange(for: PeriodCoordinate(year: 2028, month: 2, half: .second))
        #expect(range.end == CivilDate(year: 2028, month: 2, day: 29))
    }

    @Test("Century year divisible by 100 but not 400 is not a leap year")
    func centuryNonLeapYear() {
        let range = PeriodDateEngine.dateRange(for: PeriodCoordinate(year: 2100, month: 2, half: .second))
        #expect(range.end == CivilDate(year: 2100, month: 2, day: 28))
    }

    @Test("coordinate(containing:) resolves day 15 to the first half and day 16 to the second")
    func coordinateBoundary() {
        let day15 = CivilDate(year: 2026, month: 6, day: 15)
        let day16 = CivilDate(year: 2026, month: 6, day: 16)

        #expect(PeriodDateEngine.coordinate(containing: day15).half == .first)
        #expect(PeriodDateEngine.coordinate(containing: day16).half == .second)
    }

    @Test("Coordinate.next crosses year boundary")
    func nextCrossesYear() {
        let december = PeriodCoordinate(year: 2026, month: 12, half: .second)
        #expect(december.next == PeriodCoordinate(year: 2027, month: 1, half: .first))
    }

    @Test("Coordinate.previous crosses year boundary backward")
    func previousCrossesYear() {
        let january = PeriodCoordinate(year: 2027, month: 1, half: .first)
        #expect(january.previous == PeriodCoordinate(year: 2026, month: 12, half: .second))
    }

    @Test("date(forDayOfMonth:) clamps day 31 in February")
    func clampsInvalidDay() {
        let date = PeriodDateEngine.date(forDayOfMonth: 31, in: PeriodCoordinate(year: 2026, month: 2, half: .second))
        #expect(date == CivilDate(year: 2026, month: 2, day: 28))
    }

    // MARK: - Bug (Avie, root cause): before CivilDate, `PeriodDateEngine`/`LoanEngine` built
    // date boundaries at UTC midnight while `RecurringItem`/`Subscription`/`Loan` dates came
    // from a `DatePicker` as LOCAL midnight, and comparisons mixed the two — in any UTC−N
    // zone the mismatch shifted classification by a day. `CivilDate` fixes this by removing
    // `Date`/`Calendar`/time zone from the comparison entirely: `CivilDate(from:calendar:)`
    // normalizes once, at the UI boundary, and everything downstream is pure year/month/day
    // math with no zone left to disagree about. These tests prove the fix by running the
    // exact same scenario under two different device time zones and requiring identical
    // results — the historical bug depended on the device's zone; CivilDate must not.
    @Test("Normalizing a DatePicker Date to CivilDate gives the same civil day regardless of device time zone", arguments: [
        TimeZone(identifier: "America/Mexico_City")!,
        TimeZone(identifier: "UTC")!,
    ])
    func civilDateNormalizationIsZoneIndependent(deviceZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = deviceZone

        // "Local midnight on the 16th" as the device would report it, in either zone.
        let localMidnightThe16th = calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 0, minute: 0, second: 0))!
        let civil = CivilDate(from: localMidnightThe16th, calendar: calendar)
        #expect(civil == CivilDate(year: 2026, month: 9, day: 16))
        #expect(PeriodDateEngine.coordinate(containing: civil).half == .second)

        let localEndOfThe15th = calendar.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 23, minute: 59, second: 59))!
        let civilEnd = CivilDate(from: localEndOfThe15th, calendar: calendar)
        #expect(civilEnd == CivilDate(year: 2026, month: 9, day: 15))
        #expect(PeriodDateEngine.coordinate(containing: civilEnd).half == .first)
    }
}
