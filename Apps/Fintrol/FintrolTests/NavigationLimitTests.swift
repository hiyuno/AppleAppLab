import Testing
import Foundation
import SwiftData
@testable import Fintrol

/// TRD "Límite de navegación hacia atrás" (2026-09-16): `PeriodDateEngine.
/// monthsAgoCoordinate(from:months:)` (pure) and `PeriodCoordinator.
/// navigableLowerBound(context:monthsBack:)` (combines it with the first-materialized-period
/// floor, whichever is closer to today wins).
@Suite("PeriodDateEngine.monthsAgoCoordinate — pure, no ModelContext")
struct MonthsAgoCoordinateTests {
    @Test("1 month back from Sep 1, 2026 lands on Aug 1–15 (first half of that month)")
    func oneMonthBack() {
        let result = PeriodDateEngine.monthsAgoCoordinate(from: CivilDate(year: 2026, month: 9, day: 1), months: 1)
        #expect(result == PeriodCoordinate(year: 2026, month: 8, half: .first))
    }

    @Test("3 months back from Sep 1, 2026 lands on Jun 1–15")
    func threeMonthsBack() {
        let result = PeriodDateEngine.monthsAgoCoordinate(from: CivilDate(year: 2026, month: 9, day: 1), months: 3)
        #expect(result == PeriodCoordinate(year: 2026, month: 6, half: .first))
    }

    @Test("Always resolves to the .first half, even starting from a .second-half date")
    func alwaysResolvesToFirstHalf() {
        let result = PeriodDateEngine.monthsAgoCoordinate(from: CivilDate(year: 2026, month: 9, day: 20), months: 1)
        #expect(result == PeriodCoordinate(year: 2026, month: 8, half: .first))
    }

    @Test("Crosses a year boundary correctly")
    func crossesYearBoundary() {
        let result = PeriodDateEngine.monthsAgoCoordinate(from: CivilDate(year: 2026, month: 1, day: 10), months: 2)
        #expect(result == PeriodCoordinate(year: 2025, month: 11, half: .first))
    }
}

@MainActor
@Suite("PeriodCoordinator.navigableLowerBound — combined floor (Historial visible + primera materializada)")
struct NavigableLowerBoundTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, url: URL.temporaryDirectory.appending(path: UUID().uuidString + ".sqlite"))
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @Test("With nothing materialized, the bound is exactly the 'Historial visible' limit — widening monthsBack moves it further back without touching (or requiring) any materialized data")
    func noMaterializedDataUsesHistoryLimitAlone() throws {
        let context = try makeContext()
        let today = CivilDate.today(calendar: .current)

        let bound1 = PeriodCoordinator.navigableLowerBound(context: context, monthsBack: 1)
        #expect(bound1 == PeriodDateEngine.monthsAgoCoordinate(from: today, months: 1))

        let bound3 = PeriodCoordinator.navigableLowerBound(context: context, monthsBack: 3)
        #expect(bound3 == PeriodDateEngine.monthsAgoCoordinate(from: today, months: 3))

        // Widening only changes the computed bound — it never materializes anything.
        #expect(bound3 < bound1)
        #expect(try context.fetch(FetchDescriptor<Period>()).isEmpty)
    }

    @Test("When the configured history would reach further back than any data exists, the first-materialized-period floor wins instead")
    func materializedFloorWinsWhenHistoryRequestsFurtherBack() throws {
        let context = try makeContext()
        // Simulate "the app has only ever materialized one recent quincena" — the coordinate
        // just before today's, not some deep historical one.
        let recentCoordinate = PeriodDateEngine.coordinate(containing: CivilDate.today(calendar: .current)).previous
        let range = PeriodDateEngine.dateRange(for: recentCoordinate)
        let period = Period(startDate: range.start.date(calendar: .current), endDate: range.end.date(calendar: .current), year: recentCoordinate.year, month: recentCoordinate.month, half: recentCoordinate.half, isMaterialized: true)
        context.insert(period)
        try context.save()

        // 24 months back would, on its own, land far earlier than `recentCoordinate` —
        // but there is no data there, so the materialized floor must win.
        let bound = PeriodCoordinator.navigableLowerBound(context: context, monthsBack: 24)
        #expect(bound == recentCoordinate)

        let historyLimitAlone = PeriodDateEngine.monthsAgoCoordinate(from: CivilDate.today(calendar: .current), months: 24)
        #expect(bound > historyLimitAlone)
    }
}
