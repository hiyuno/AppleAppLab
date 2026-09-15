import Testing
import Foundation
import SwiftData
@testable import Fintrol

/// Integration-level reproduction of the three projection bugs Bertrand hit in the simulator
/// (TEST_PLAN.md flows 1–3). These deliberately drive the *same sequence the UI drives*:
/// `PeriodView.loadPeriod()` → `materializeIfNeeded`, then the `save()` of the
/// Recurring/Services/Loans forms → `reproject…`, then `.onAppear` → `loadPeriod()` again.
///
/// Every test here is expected to FAIL against today's HEAD. They are the executable proof
/// handed to Woz; do not weaken the assertions to make them pass.
@MainActor
@Suite("Projection regressions — Bertrand simulator repro")
struct ProjectionRegressionTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private let sep1 = PeriodCoordinate(year: 2026, month: 9, half: .first)
    private var sep16: PeriodCoordinate { sep1.next }
    private let rate: Decimal = 18

    /// Mirrors `PeriodView.loadPeriod()` exactly.
    @discardableResult
    private func loadPeriod(_ coordinate: PeriodCoordinate, context: ModelContext) -> Period {
        let recurring = ((try? context.fetch(FetchDescriptor<RecurringItem>())) ?? []).map {
            RecurringItemSnapshot(id: $0.id, kind: $0.kind, title: $0.title, amount: $0.amount, currency: $0.currency, frequency: $0.frequency, startDate: $0.civilStartDate, endDate: $0.civilEndDate, isActive: $0.isActive)
        }
        let subs = ((try? context.fetch(FetchDescriptor<Subscription>())) ?? []).map {
            SubscriptionSnapshot(id: $0.id, name: $0.name, price: $0.price, currency: $0.currency, paymentDay: $0.paymentDay, startDate: $0.civilStartDate, endDate: $0.civilEndDate, kind: $0.kind)
        }
        let loans = ((try? context.fetch(FetchDescriptor<Loan>())) ?? []).map {
            LoanSnapshot(id: $0.id, name: $0.name, direction: $0.direction, principal: $0.principal, currency: $0.currency, apr: $0.apr, startDate: $0.civilStartDate, termMonths: $0.termMonths, frequency: $0.frequency, paymentOverride: $0.paymentOverride, isActive: $0.isActive)
        }
        let period = PeriodCoordinator.materializeIfNeeded(
            coordinate: coordinate, context: context,
            recurringItems: recurring, subscriptions: subs, loans: loans, exchangeRate: rate
        )
        try? context.save()
        return period
    }

    private func lines(_ coordinate: PeriodCoordinate, context: ModelContext, titled title: String) -> [LineItem] {
        let period = PeriodCoordinator.fetchPeriod(coordinate: coordinate, context: context)
        return (period?.lineItems ?? []).filter { $0.title == title }
    }

    private func lines(_ coordinate: PeriodCoordinate, context: ModelContext, origin: LineOrigin) -> [LineItem] {
        let period = PeriodCoordinator.fetchPeriod(coordinate: coordinate, context: context)
        return (period?.lineItems ?? []).filter { $0.origin == origin }
    }

    // MARK: - Bug 1 — WALO

    @Test("BUG 1a — WALO (biweekly, start Sep 1) appears exactly once in the already-materialized Sep 1–15")
    func waloAppearsOnceInCurrentHalf() throws {
        let context = try makeContext()
        // The user has been using the app: both halves of September are already materialized.
        loadPeriod(sep1, context: context)
        loadPeriod(sep16, context: context)

        // Hub → Ingresos recurrentes → "WALO" $2,750, cada quincena, inicio 1 sep 2026.
        let walo = RecurringItem(
            kind: .income, title: "WALO", amount: 2750, currency: .usd, frequency: .biweekly,
            startDate: CivilDate(year: 2026, month: 9, day: 1).date(calendar: .current), endDate: nil
        )
        context.insert(walo)
        try context.save()
        PeriodCoordinator.reprojectRecurring(item: walo, context: context, exchangeRate: rate)

        // Back to the Quincena tab → `.onAppear` → loadPeriod().
        loadPeriod(sep1, context: context)
        loadPeriod(sep16, context: context)

        #expect(lines(sep1, context: context, titled: "WALO").count == 1, "Sep 1–15 must contain exactly one WALO line")
        #expect(lines(sep16, context: context, titled: "WALO").count == 1, "Sep 16–30 must contain exactly one WALO line")
    }

    @Test("BUG 1b — deleting and recreating WALO must not accumulate stale lines (the 'triplicado' path)")
    func waloDeletedAndRecreatedDoesNotAccumulate() throws {
        let context = try makeContext()
        loadPeriod(sep1, context: context)
        loadPeriod(sep16, context: context)

        // Three successive "create → delete from the list → create again" cycles, exactly what
        // Bertrand did between runs ("se borraron y recrearon desde cero").
        for _ in 0..<3 {
            let walo = RecurringItem(
                kind: .income, title: "WALO", amount: 2750, currency: .usd, frequency: .biweekly,
                startDate: CivilDate(year: 2026, month: 9, day: 1).date(calendar: .current), endDate: nil
            )
            context.insert(walo)
            try context.save()
            PeriodCoordinator.reprojectRecurring(item: walo, context: context, exchangeRate: rate)

            // RecurringListView swipe-to-delete: `context.delete(item)` and nothing else.
            context.delete(walo)
            try context.save()
            loadPeriod(sep1, context: context)
            loadPeriod(sep16, context: context)
        }

        // Mechanism of the "triplicado": each orphan line keeps the `sourceRecurringID` of the
        // RecurringItem that generated it, so `dedupeLines` (which keys off the *current*
        // item's id) can never see them as duplicates of each other.
        let orphanIDs = Set(lines(sep16, context: context, titled: "WALO").compactMap(\.sourceRecurringID))
        #expect(orphanIDs.count <= 1, "stale lines come from distinct, already-deleted RecurringItems — dedupe by id can never catch them")

        #expect(lines(sep1, context: context, titled: "WALO").isEmpty, "deleting the recurring item must purge its generated lines in Sep 1–15")
        #expect(lines(sep16, context: context, titled: "WALO").isEmpty, "deleting the recurring item must purge its generated lines in Sep 16–30")
    }

    @Test("BUG 1c — WALO created with start = today (Sep 15) still lands in the current half Sep 1–15")
    func waloStartingTodayAppearsInCurrentHalf() throws {
        let context = try makeContext()
        loadPeriod(sep1, context: context)

        let walo = RecurringItem(
            kind: .income, title: "WALO", amount: 2750, currency: .usd, frequency: .biweekly,
            startDate: CivilDate(year: 2026, month: 9, day: 15).date(calendar: .current), endDate: nil
        )
        context.insert(walo)
        try context.save()
        PeriodCoordinator.reprojectRecurring(item: walo, context: context, exchangeRate: rate)
        loadPeriod(sep1, context: context)

        #expect(lines(sep1, context: context, titled: "WALO").count == 1)
    }

    // MARK: - Bug 2 — Luz (home service, kind == .service)

    @Test("BUG 2 — 'Luz' $82 day 12 created today (Sep 15) shows up in the Sep 1–15 Servicios line")
    func luzServiceProjectsIntoItsOwnHalf() throws {
        let context = try makeContext()
        loadPeriod(sep1, context: context)
        loadPeriod(sep16, context: context)

        // Servicios → nuevo servicio. The form's start date defaults to *today*, which in the
        // simulator run was Sep 15 — after the service's own payment day (12) in that half.
        let luz = Subscription(
            name: "Luz", price: 82, currency: .usd, paymentDay: 12,
            startDate: CivilDate(year: 2026, month: 9, day: 15).date(calendar: .current),
            endDate: nil, homeServiceCategory: .electricity
        )
        context.insert(luz)
        try context.save()
        PeriodCoordinator.reprojectSubscription(kind: .service, context: context, exchangeRate: rate)

        loadPeriod(sep1, context: context)

        let servicios = lines(sep1, context: context, origin: .subscription).filter(\.isHomeService)
        #expect(servicios.count == 1, "Sep 1–15 must carry one combined Servicios line")
        #expect(servicios.first?.amount == 82, "the Servicios line must include Luz's $82")
    }

    @Test("BUG 2 control — the same service with start Sep 1 does project (isolates the vigencia rule)")
    func luzServiceWithEarlierStartProjects() throws {
        let context = try makeContext()
        loadPeriod(sep1, context: context)

        let luz = Subscription(
            name: "Luz", price: 82, currency: .usd, paymentDay: 12,
            startDate: CivilDate(year: 2026, month: 9, day: 1).date(calendar: .current),
            endDate: nil, homeServiceCategory: .electricity
        )
        context.insert(luz)
        try context.save()
        PeriodCoordinator.reprojectSubscription(kind: .service, context: context, exchangeRate: rate)

        let servicios = lines(sep1, context: context, origin: .subscription).filter(\.isHomeService)
        #expect(servicios.count == 1)
        #expect(servicios.first?.amount == 82)
    }

    // MARK: - Bug 3 — deleting a Loan leaves its generated lines behind

    @Test("BUG 3 — deleting a loan purges its generated lines from every materialized quincena")
    func deletingLoanPurgesGeneratedLines() throws {
        let context = try makeContext()

        let loan = Loan(
            name: "Préstamo Auto", direction: .borrowed, principal: 10000, currency: .usd,
            apr: 12, startDate: CivilDate(year: 2026, month: 8, day: 20).date(calendar: .current),
            termMonths: 24, frequency: .monthly(day: 20)
        )
        context.insert(loan)
        try context.save()

        loadPeriod(sep1, context: context)
        loadPeriod(sep16, context: context)
        #expect(!lines(sep16, context: context, origin: .loan).isEmpty, "precondition: the loan line exists in Sep 16–30")

        // LoansView swipe-to-delete: `context.delete(loan)` and nothing else.
        context.delete(loan)
        try context.save()
        loadPeriod(sep16, context: context)

        #expect(lines(sep16, context: context, origin: .loan).isEmpty, "a deleted loan must not leave phantom EXPENSES lines behind")
    }

    // MARK: - Idempotency of the UI's own repeated loads

    @Test("Repeated loadPeriod() (.task + .onAppear + tab switches) never duplicates generated lines")
    func repeatedLoadPeriodIsIdempotent() throws {
        let context = try makeContext()
        let walo = RecurringItem(
            kind: .income, title: "WALO", amount: 2750, currency: .usd, frequency: .biweekly,
            startDate: CivilDate(year: 2026, month: 9, day: 1).date(calendar: .current), endDate: nil
        )
        context.insert(walo)
        try context.save()

        for _ in 0..<5 {
            loadPeriod(sep1, context: context)
            loadPeriod(sep16, context: context)
            PeriodCoordinator.reprojectRecurring(item: walo, context: context, exchangeRate: rate)
        }

        #expect(lines(sep1, context: context, titled: "WALO").count == 1)
        #expect(lines(sep16, context: context, titled: "WALO").count == 1)
    }
}
