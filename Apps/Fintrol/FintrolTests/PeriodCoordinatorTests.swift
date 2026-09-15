import Testing
import Foundation
import SwiftData
@testable import Fintrol

@MainActor
@Suite("PeriodCoordinator — end-to-end materialization and carry-over")
struct PeriodCoordinatorTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @Test("Carry-over: the sobrante of period N appears as the 'Latest Month' income line of N+1")
    func carryOverChains() throws {
        let context = try makeContext()
        let coordinateN = PeriodCoordinate(year: 2026, month: 6, half: .first)

        let period = PeriodCoordinator.materializeIfNeeded(coordinate: coordinateN, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)
        let income = LineItem(kind: .income, title: "WALO", amount: 2750, currency: .usd, sortOrder: 0, origin: .manual, period: period)
        context.insert(income)
        period.lineItems?.append(income)
        try context.save()

        let next = PeriodCoordinator.materializeIfNeeded(coordinate: coordinateN.next, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)
        let carryLine = (next.lineItems ?? []).first { $0.origin == .carryOver }

        #expect(carryLine?.title == "Latest Month")
        #expect(carryLine?.amount == 2750)
    }

    @Test("Editing a past period recomputes forward and stops at the fixed point")
    func recomputeForwardStopsAtFixedPoint() throws {
        let context = try makeContext()
        let coordinateN = PeriodCoordinate(year: 2026, month: 6, half: .first)

        let periodN = PeriodCoordinator.materializeIfNeeded(coordinate: coordinateN, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)
        let income = LineItem(kind: .income, title: "WALO", amount: 1000, currency: .usd, sortOrder: 0, origin: .manual, period: periodN)
        context.insert(income)
        periodN.lineItems?.append(income)
        try context.save()

        let periodN1 = PeriodCoordinator.materializeIfNeeded(coordinate: coordinateN.next, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)
        #expect((periodN1.lineItems ?? []).first { $0.origin == .carryOver }?.amount == 1000)

        // Edit period N's income upward.
        income.amount = 1500
        try context.save()
        PeriodCoordinator.recomputeForward(after: periodN, context: context, exchangeRate: 18)
        try context.save()

        let updatedCarry = (periodN1.lineItems ?? []).first { $0.origin == .carryOver }
        #expect(updatedCarry?.amount == 1500)
    }

    @Test("Materializing skips the earlier half when the store already has an anchor")
    func noPeriodExistsBeforeFirstMaterialized() throws {
        let context = try makeContext()
        let anchor = PeriodCoordinate(year: 2026, month: 6, half: .first)
        _ = PeriodCoordinator.materializeIfNeeded(coordinate: anchor, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)

        #expect(PeriodCoordinator.earliestMaterializedCoordinate(context: context) == anchor)
    }

    @Test("Recurring regeneration respects manual edits (manual edit wins end-to-end)")
    func regenerationRespectsManualEdits() throws {
        let context = try makeContext()
        let recurring = RecurringItem(kind: .income, title: "Ada", amount: 300, currency: .usd, frequency: .biweekly, startDate: Date.distantPast)
        context.insert(recurring)
        try context.save()

        let coordinate = PeriodDateEngine.coordinate(containing: CivilDate.today())
        let snapshot = RecurringItemSnapshot(id: recurring.id, kind: recurring.kind, title: recurring.title, amount: recurring.amount, currency: recurring.currency, frequency: recurring.frequency, startDate: recurring.civilStartDate, endDate: recurring.civilEndDate, isActive: recurring.isActive)
        let period = PeriodCoordinator.materializeIfNeeded(coordinate: coordinate, context: context, recurringItems: [snapshot], subscriptions: [], exchangeRate: 18)

        let generatedLine = (period.lineItems ?? []).first { $0.sourceRecurringID == recurring.id }
        #expect(generatedLine?.amount == 300)

        // User manually edits this quincena's line.
        generatedLine?.amount = 999
        generatedLine?.isManuallyEdited = true
        try context.save()

        // The recurring item's amount changes...
        recurring.amount = 350
        try context.save()
        PeriodCoordinator.reprojectRecurring(item: recurring, context: context, exchangeRate: 18)
        try context.save()

        // ...but the manually-edited line must be untouched.
        #expect(generatedLine?.amount == 999)
    }

    // MARK: - Reprojection onto already-materialized periods (Avie's bug)

    @Test("A brand-new recurring item projects onto a quincena materialized BEFORE it existed")
    func reprojectRecurringCreatesLineOnExistingPeriod() throws {
        let context = try makeContext()
        let coordinate = PeriodCoordinate(year: 2026, month: 6, half: .first)
        let period = PeriodCoordinator.materializeIfNeeded(coordinate: coordinate, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)
        #expect((period.lineItems ?? []).isEmpty)

        let newItem = RecurringItem(kind: .income, title: "Bono nuevo", amount: 500, currency: .usd, frequency: .biweekly, startDate: Date.distantPast)
        context.insert(newItem)
        try context.save()

        PeriodCoordinator.reprojectRecurring(item: newItem, context: context, exchangeRate: 18)

        let line = (period.lineItems ?? []).first { $0.sourceRecurringID == newItem.id }
        #expect(line?.amount == 500)
        #expect(CarryOverEngine.sobrante(for: PeriodCoordinator.snapshots(of: period), exchangeRate: 18) == 500)
    }

    @Test("Editing a recurring item's amount respects a manually-edited line, updates the rest")
    func reprojectRecurringRespectsManualEdit() throws {
        let context = try makeContext()
        let item = RecurringItem(kind: .expense, title: "Renta", amount: 1000, currency: .usd, frequency: .biweekly, startDate: Date.distantPast)
        context.insert(item)
        try context.save()

        let coordinateA = PeriodCoordinate(year: 2026, month: 6, half: .first)
        let coordinateB = coordinateA.next
        let periodA = PeriodCoordinator.materializeIfNeeded(coordinate: coordinateA, context: context, recurringItems: [RecurringItemSnapshot(id: item.id, kind: item.kind, title: item.title, amount: item.amount, currency: item.currency, frequency: item.frequency, startDate: item.civilStartDate, endDate: item.civilEndDate, isActive: item.isActive)], subscriptions: [], exchangeRate: 18)
        let periodB = PeriodCoordinator.materializeIfNeeded(coordinate: coordinateB, context: context, recurringItems: [RecurringItemSnapshot(id: item.id, kind: item.kind, title: item.title, amount: item.amount, currency: item.currency, frequency: item.frequency, startDate: item.civilStartDate, endDate: item.civilEndDate, isActive: item.isActive)], subscriptions: [], exchangeRate: 18)

        let lineA = (periodA.lineItems ?? []).first { $0.sourceRecurringID == item.id }
        lineA?.amount = 1234
        lineA?.isManuallyEdited = true
        try context.save()

        item.amount = 1100
        try context.save()
        PeriodCoordinator.reprojectRecurring(item: item, context: context, exchangeRate: 18)

        let refreshedLineA = (periodA.lineItems ?? []).first { $0.sourceRecurringID == item.id }
        let lineB = (periodB.lineItems ?? []).first { $0.sourceRecurringID == item.id }
        #expect(refreshedLineA?.amount == 1234, "manually-edited line must not be overwritten")
        #expect(lineB?.amount == 1100, "non-edited line picks up the new amount")
    }

    @Test("Deactivating a recurring item removes it from future non-edited periods")
    func reprojectRecurringRemovesWhenDeactivated() throws {
        let context = try makeContext()
        let item = RecurringItem(kind: .expense, title: "Prueba gratis", amount: 20, currency: .usd, frequency: .biweekly, startDate: Date.distantPast)
        context.insert(item)
        try context.save()
        let snapshot = { RecurringItemSnapshot(id: item.id, kind: item.kind, title: item.title, amount: item.amount, currency: item.currency, frequency: item.frequency, startDate: item.civilStartDate, endDate: item.civilEndDate, isActive: item.isActive) }

        let coordinate = PeriodCoordinate(year: 2026, month: 7, half: .first)
        let period = PeriodCoordinator.materializeIfNeeded(coordinate: coordinate, context: context, recurringItems: [snapshot()], subscriptions: [], exchangeRate: 18)
        #expect((period.lineItems ?? []).contains { $0.sourceRecurringID == item.id })

        item.isActive = false
        try context.save()
        PeriodCoordinator.reprojectRecurring(item: item, context: context, exchangeRate: 18)

        #expect(!(period.lineItems ?? []).contains { $0.sourceRecurringID == item.id })
    }

    @Test("reprojectRecurring propagates the carry-over chain to the next materialized period")
    func reprojectRecurringUpdatesCarryOverChain() throws {
        let context = try makeContext()
        let coordinateA = PeriodCoordinate(year: 2026, month: 8, half: .first)
        let coordinateB = coordinateA.next
        let periodA = PeriodCoordinator.materializeIfNeeded(coordinate: coordinateA, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)
        let periodB = PeriodCoordinator.materializeIfNeeded(coordinate: coordinateB, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)
        let carryLineBefore = (periodB.lineItems ?? []).first { $0.origin == .carryOver }
        #expect(carryLineBefore?.amount == 0)

        let item = RecurringItem(kind: .income, title: "Ingreso nuevo", amount: 700, currency: .usd, frequency: .biweekly, startDate: Date.distantPast)
        context.insert(item)
        try context.save()

        PeriodCoordinator.reprojectRecurring(item: item, context: context, exchangeRate: 18)

        _ = periodA // materialized to establish the chain
        let carryLineAfter = (periodB.lineItems ?? []).first { $0.origin == .carryOver }
        #expect(carryLineAfter?.amount == 700)
    }

    // MARK: - Same four cases for Subscription (subscriptions AND services share reprojectSubscription)

    @Test("A brand-new subscription projects onto a quincena materialized BEFORE it existed")
    func reprojectSubscriptionCreatesLineOnExistingPeriod() throws {
        let context = try makeContext()
        let coordinate = PeriodCoordinate(year: 2026, month: 6, half: .first)
        let period = PeriodCoordinator.materializeIfNeeded(coordinate: coordinate, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)

        let netflix = Subscription(name: "Netflix", price: 15, currency: .usd, paymentDay: 5, startDate: Date.distantPast, kind: .subscription, category: .entertainment)
        context.insert(netflix)
        try context.save()

        PeriodCoordinator.reprojectSubscription(kind: .subscription, context: context, exchangeRate: 18)

        let line = (period.lineItems ?? []).first { $0.origin == .subscription && !$0.isHomeService }
        #expect(line?.amount == 15)
        #expect(line?.title == "Payments 1–15")
    }

    @Test("Editing a subscription's price respects a manually-edited combined line")
    func reprojectSubscriptionRespectsManualEdit() throws {
        let context = try makeContext()
        let netflix = Subscription(name: "Netflix", price: 15, currency: .usd, paymentDay: 5, startDate: Date.distantPast, kind: .subscription, category: .entertainment)
        context.insert(netflix)
        try context.save()

        let coordinateA = PeriodCoordinate(year: 2026, month: 6, half: .first)
        let coordinateB = coordinateA.next
        let subSnapshot = SubscriptionSnapshot(id: netflix.id, name: netflix.name, price: netflix.price, currency: netflix.currency, paymentDay: netflix.paymentDay, startDate: netflix.civilStartDate, endDate: netflix.civilEndDate, kind: .subscription)
        let periodA = PeriodCoordinator.materializeIfNeeded(coordinate: coordinateA, context: context, recurringItems: [], subscriptions: [subSnapshot], exchangeRate: 18)
        // netflix pays day 5 -> only first half; second half combined line won't exist for this sub.

        let lineA = (periodA.lineItems ?? []).first { $0.origin == .subscription && !$0.isHomeService }
        lineA?.amount = 999
        lineA?.isManuallyEdited = true
        try context.save()

        netflix.price = 20
        try context.save()
        PeriodCoordinator.reprojectSubscription(kind: .subscription, context: context, exchangeRate: 18)

        let refreshedLineA = (periodA.lineItems ?? []).first { $0.origin == .subscription && !$0.isHomeService }
        #expect(refreshedLineA?.amount == 999, "manually-edited combined line must not be overwritten")
        _ = coordinateB
    }

    @Test("Setting a subscription's end date before the period removes it from future non-edited periods")
    func reprojectSubscriptionRemovesWhenExpired() throws {
        let context = try makeContext()
        let calendar = Calendar.gregorianUTC
        let netflix = Subscription(name: "Netflix", price: 15, currency: .usd, paymentDay: 5, startDate: Date.distantPast, kind: .subscription, category: .entertainment)
        context.insert(netflix)
        try context.save()

        let coordinate = PeriodCoordinate(year: 2026, month: 7, half: .first)
        let subSnapshot = SubscriptionSnapshot(id: netflix.id, name: netflix.name, price: netflix.price, currency: netflix.currency, paymentDay: netflix.paymentDay, startDate: netflix.civilStartDate, endDate: netflix.civilEndDate, kind: .subscription)
        let period = PeriodCoordinator.materializeIfNeeded(coordinate: coordinate, context: context, recurringItems: [], subscriptions: [subSnapshot], exchangeRate: 18)
        #expect((period.lineItems ?? []).contains { $0.origin == .subscription && !$0.isHomeService })

        netflix.endDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        try context.save()
        PeriodCoordinator.reprojectSubscription(kind: .subscription, context: context, exchangeRate: 18)

        #expect(!(period.lineItems ?? []).contains { $0.origin == .subscription && !$0.isHomeService })
    }

    @Test("reprojectSubscription propagates the carry-over chain to the next materialized period")
    func reprojectSubscriptionUpdatesCarryOverChain() throws {
        let context = try makeContext()
        let coordinateA = PeriodCoordinate(year: 2026, month: 8, half: .first)
        let coordinateB = coordinateA.next
        let periodA = PeriodCoordinator.materializeIfNeeded(coordinate: coordinateA, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)
        let periodB = PeriodCoordinator.materializeIfNeeded(coordinate: coordinateB, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)
        _ = periodA

        let rent = Subscription(name: "Renta", price: 1900, currency: .usd, paymentDay: 3, startDate: Date.distantPast, homeServiceCategory: .rent)
        context.insert(rent)
        try context.save()

        PeriodCoordinator.reprojectSubscription(kind: .service, context: context, exchangeRate: 18)

        let carryLineAfter = (periodB.lineItems ?? []).first { $0.origin == .carryOver }
        #expect(carryLineAfter?.amount == -1900)
    }

    // MARK: - Ghost-line bug (Bertrand)

    @Test("A manual line needs both a non-empty description and a positive amount to be valid")
    func manualLineValidation() {
        #expect(PeriodCoordinator.isValidManualLine(title: "", amount: 0) == false)
        #expect(PeriodCoordinator.isValidManualLine(title: "", amount: 50) == false)
        #expect(PeriodCoordinator.isValidManualLine(title: "   ", amount: 50) == false, "whitespace-only description doesn't count")
        #expect(PeriodCoordinator.isValidManualLine(title: "Café", amount: 0) == false)
        #expect(PeriodCoordinator.isValidManualLine(title: "Café", amount: -5) == false)
        #expect(PeriodCoordinator.isValidManualLine(title: "Café", amount: 4.50) == true)
    }

    // MARK: - Idempotency belt (Avie): reproject* must never leave two LineItems for the same
    // source in the same Period, even if called twice in a row.

    @Test("Calling reprojectRecurring twice for the same item leaves exactly one line, not two")
    func reprojectRecurringIsIdempotent() throws {
        let context = try makeContext()
        let coordinate = PeriodCoordinate(year: 2026, month: 6, half: .first)
        let period = PeriodCoordinator.materializeIfNeeded(coordinate: coordinate, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)

        let item = RecurringItem(kind: .income, title: "Bono doble", amount: 500, currency: .usd, frequency: .biweekly, startDate: Date.distantPast)
        context.insert(item)
        try context.save()

        PeriodCoordinator.reprojectRecurring(item: item, context: context, exchangeRate: 18)
        PeriodCoordinator.reprojectRecurring(item: item, context: context, exchangeRate: 18)

        let matches = (period.lineItems ?? []).filter { $0.sourceRecurringID == item.id }
        #expect(matches.count == 1, "two calls must not duplicate the line")
    }

    @Test("Calling reprojectSubscription twice for the same kind leaves exactly one combined line, not two")
    func reprojectSubscriptionIsIdempotent() throws {
        let context = try makeContext()
        let coordinate = PeriodCoordinate(year: 2026, month: 6, half: .first)
        let period = PeriodCoordinator.materializeIfNeeded(coordinate: coordinate, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)

        let netflix = Subscription(name: "Netflix", price: 15, currency: .usd, paymentDay: 5, startDate: Date.distantPast, kind: .subscription, category: .entertainment)
        context.insert(netflix)
        try context.save()

        PeriodCoordinator.reprojectSubscription(kind: .subscription, context: context, exchangeRate: 18)
        PeriodCoordinator.reprojectSubscription(kind: .subscription, context: context, exchangeRate: 18)

        let matches = (period.lineItems ?? []).filter { $0.origin == .subscription && !$0.isHomeService }
        #expect(matches.count == 1, "two calls must not duplicate the combined line")
    }

    @Test("Calling reprojectLoan twice for the same loan leaves exactly one line per installment, not two")
    func reprojectLoanIsIdempotent() throws {
        let context = try makeContext()
        let coordinate = PeriodCoordinate(year: 2026, month: 1, half: .second)
        let period = PeriodCoordinator.materializeIfNeeded(coordinate: coordinate, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)

        let loan = Loan(name: "Upstart", direction: .borrowed, principal: 20000, currency: .usd, apr: Decimal(string: "0.12")!, startDate: CivilDate(year: 2026, month: 1, day: 20).date(calendar: .current), termMonths: 48, frequency: .monthly(day: 20))
        context.insert(loan)
        try context.save()

        PeriodCoordinator.reprojectLoan(item: loan, context: context, exchangeRate: 18)
        PeriodCoordinator.reprojectLoan(item: loan, context: context, exchangeRate: 18)

        let matches = (period.lineItems ?? []).filter { $0.sourceLoanID == loan.id }
        #expect(matches.count == 1, "two calls must not duplicate the loan's line")
    }
}
