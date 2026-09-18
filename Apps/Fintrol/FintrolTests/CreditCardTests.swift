import Testing
import Foundation
import SwiftData
@testable import Fintrol

/// TRD "Credit Cards" (2026-09-17) — the 6 tests required by the plan.
@MainActor
@Suite("CreditCardEngine / PeriodCoordinator — Credit Cards")
struct CreditCardTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, url: URL.temporaryDirectory.appending(path: UUID().uuidString + ".sqlite"))
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    // MARK: 1. Payment date rules → correct quincena

    @Test("Cutoff day 15, rule '5 days before cutoff' → payment date is day 10, falls in the 1–15 quincena (PRD acceptance example)")
    func daysBeforeCutoffFallsInExpectedQuincena() throws {
        let due = CreditCardEngine.paymentDate(cutoffDay: 15, paymentDay: 5, year: 2026, month: 9, rule: .daysBeforeCutoff(5))
        #expect(due == CivilDate(year: 2026, month: 9, day: 10))
        let coordinate = PeriodDateEngine.coordinate(containing: due)
        #expect(coordinate.half == .first)
    }

    @Test("Rule 'on cutoff date' → payment date is the cutoff day itself")
    func onCutoffDateRule() throws {
        let due = CreditCardEngine.paymentDate(cutoffDay: 20, paymentDay: 5, year: 2026, month: 9, rule: .onCutoffDate)
        #expect(due == CivilDate(year: 2026, month: 9, day: 20))
        let coordinate = PeriodDateEngine.coordinate(containing: due)
        #expect(coordinate.half == .second)
    }

    @Test("Rule 'on payment date' → payment date is the card's own paymentDay, anchored to the same billing month")
    func onPaymentDateRule() throws {
        let due = CreditCardEngine.paymentDate(cutoffDay: 15, paymentDay: 3, year: 2026, month: 9, rule: .onPaymentDate)
        #expect(due == CivilDate(year: 2026, month: 9, day: 3))
        let coordinate = PeriodDateEngine.coordinate(containing: due)
        #expect(coordinate.half == .first)
    }

    // MARK: 2. suggestedMinimumPayment formula

    @Test("suggestedMinimumPayment == MAX($25, balance×1% + interés del mes) across several balances/APRs")
    func suggestedMinimumPaymentFormula() throws {
        // Low balance: 1%+interest below $25 floor.
        let low = CreditCardEngine.suggestedMinimumPayment(balance: 500, apr: Decimal(string: "0.20")!)
        let lowInterest = LoanEngine.monthlyRevolvingInterest(balance: 500, apr: Decimal(string: "0.20")!)
        #expect(low == max(Decimal(25), Decimal(500) * Decimal(string: "0.01")! + lowInterest))
        #expect(low == 25) // 500*0.01=5 + interest(~8.33) = ~13.33, floor wins

        // High balance: formula exceeds the floor.
        let high = CreditCardEngine.suggestedMinimumPayment(balance: 5000, apr: Decimal(string: "0.24")!)
        let highInterest = LoanEngine.monthlyRevolvingInterest(balance: 5000, apr: Decimal(string: "0.24")!)
        #expect(high == Decimal(5000) * Decimal(string: "0.01")! + highInterest)
        #expect(high > 25)

        // Zero balance: no payment owed.
        #expect(CreditCardEngine.suggestedMinimumPayment(balance: 0, apr: Decimal(string: "0.24")!) == 0)
    }

    // MARK: 3. Monthly interest reuses LoanEngine.monthlyRevolvingInterest (not a second formula)

    @Test("CreditCardEngine's interest matches LoanEngine.monthlyRevolvingInterest exactly, for several balances/APRs")
    func monthlyInterestReusesLoanEngine() throws {
        let cases: [(Decimal, Decimal)] = [(1000, Decimal(string: "0.1999")!), (2500, Decimal(string: "0.2499")!), (100, Decimal(string: "0.30")!)]
        for (balance, apr) in cases {
            let expected = LoanEngine.monthlyRevolvingInterest(balance: balance, apr: apr)
            let suggested = CreditCardEngine.suggestedMinimumPayment(balance: balance, apr: apr)
            let onePercent = balance * Decimal(string: "0.01")!
            #expect(suggested == max(Decimal(25), onePercent + expected), "suggestedMinimumPayment must use the exact same interest value LoanEngine computes")
        }
    }

    // MARK: 4. Real payment vs. projected — a manually-edited line overrides the projection

    @Test("A real (manually-edited) payment for the due date replaces the projected suggested/expected amount")
    func realPaymentOverridesProjection() throws {
        let card = CreditCardSnapshot(id: UUID(), name: "Chase Sapphire", balance: 2000, apr: Decimal(string: "0.24")!, creditLimit: 5000, cutoffDay: 15, paymentDay: 5, expectedPayment: nil, isActive: true)
        let coordinate = PeriodCoordinate(year: 2026, month: 9, half: .first)

        let projected = CreditCardEngine.generatedLine(for: coordinate, card: card, dateRule: .daysBeforeCutoff(5), realPayment: nil)
        #expect(projected != nil)
        let suggested = CreditCardEngine.suggestedMinimumPayment(balance: 2000, apr: Decimal(string: "0.24")!)
        #expect(projected?.amount == suggested)

        let real = CreditCardEngine.generatedLine(for: coordinate, card: card, dateRule: .daysBeforeCutoff(5), realPayment: 300)
        #expect(real?.amount == 300)
        #expect(real?.amount != projected?.amount)
    }

    // MARK: 5. Delete cascade — no orphaned LineItems

    @Test("deleteCreditCard purges its generated LineItem — purgeOrphanLines also reaches it via sourceCreditCardID")
    func deleteCascadeLeavesNoOrphans() throws {
        let context = try makeContext()
        let coordinate = PeriodCoordinate(year: 2026, month: 9, half: .first)
        let period = PeriodCoordinator.materializeIfNeeded(coordinate: coordinate, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)

        let card = CreditCard(name: "Amex Gold", balance: 1200, apr: Decimal(string: "0.22")!, creditLimit: 4000, cutoffDay: 15, paymentDay: 10, expectedPayment: nil, isActive: true)
        context.insert(card)
        try context.save()

        PeriodCoordinator.reprojectCreditCard(item: card, context: context, exchangeRate: 18, dateRule: .daysBeforeCutoff(5))
        let matches = (period.lineItems ?? []).filter { $0.sourceCreditCardID == card.id }
        #expect(matches.count == 1, "reprojectCreditCard should have generated exactly one line for this quincena")

        PeriodCoordinator.deleteCreditCard(card, context: context, exchangeRate: 18)

        let afterDelete = (period.lineItems ?? []).filter { $0.sourceCreditCardID == card.id }
        #expect(afterDelete.isEmpty, "deleteCreditCard's purgeLines must remove the generated line")

        // Belt-and-suspenders sweep must also find nothing left orphaned.
        PeriodCoordinator.purgeOrphanLines(context: context, exchangeRate: 18)
        let afterSweep = (period.lineItems ?? []).filter { $0.sourceCreditCardID == card.id }
        #expect(afterSweep.isEmpty)
    }

    // MARK: 6. Aggregated row sum — 0/1/N cards with a payment in the same quincena

    /// Mirrors `PeriodView.card(...)`'s aggregation math exactly (can't drive the real SwiftUI
    /// view from a unit test, same pattern as `LoanPaidToDateTests`'s `togglePaid` mirror) —
    /// sum of `amount` across every active `origin == .creditCard` line.
    private func aggregatedCreditCardTotal(_ lines: [LineItem]) -> Decimal {
        lines.filter { $0.origin == .creditCard && $0.isActive }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    @Test("Aggregated 'Credit Cards Payments' total is correct with 0, 1, and N cards paying in the same quincena")
    func aggregatedTotalWithZeroOneAndManyCards() throws {
        let context = try makeContext()
        let period = Period(startDate: Date(), endDate: Date(), year: 2026, month: 9, half: .first)
        context.insert(period)

        // 0 cards.
        #expect(aggregatedCreditCardTotal(period.lineItems ?? []) == 0)

        // 1 card.
        let line1 = LineItem(kind: .expense, title: "Chase Sapphire", amount: 58, currency: .usd, sortOrder: 0, origin: .creditCard, sourceCreditCardID: UUID(), period: period)
        context.insert(line1)
        period.lineItems = [line1]
        try context.save()
        #expect(aggregatedCreditCardTotal(period.lineItems ?? []) == 58)

        // N cards (3).
        let line2 = LineItem(kind: .expense, title: "Amex Gold", amount: 312, currency: .usd, sortOrder: 1, origin: .creditCard, sourceCreditCardID: UUID(), period: period)
        let line3 = LineItem(kind: .expense, title: "Discover It", amount: 45.50, currency: .usd, sortOrder: 2, origin: .creditCard, sourceCreditCardID: UUID(), period: period)
        context.insert(line2)
        context.insert(line3)
        period.lineItems = [line1, line2, line3]
        try context.save()
        #expect(aggregatedCreditCardTotal(period.lineItems ?? []) == 58 + 312 + Decimal(string: "45.50")!)

        // A non-credit-card line must never be swept into the aggregate.
        let manualLine = LineItem(kind: .expense, title: "Renta", amount: 1000, currency: .usd, sortOrder: 3, origin: .manual, period: period)
        context.insert(manualLine)
        period.lineItems = [line1, line2, line3, manualLine]
        try context.save()
        #expect(aggregatedCreditCardTotal(period.lineItems ?? []) == 58 + 312 + Decimal(string: "45.50")!)

        // An inactive card line must not count either (matches TOTAL EXPENSES' own isActive filter).
        line2.isActive = false
        try context.save()
        #expect(aggregatedCreditCardTotal(period.lineItems ?? []) == 58 + Decimal(string: "45.50")!)
    }

    // MARK: 7. Utilization semaphore (coordinator, 2026-09-17) — green <10%, yellow 10–29.99%, red ≥30%

    @Test("utilizationLevel matches the 3-tier semaphore across the range, including the exact boundaries")
    func utilizationLevelThresholds() throws {
        // Green: comfortably under 10%, and just under the boundary.
        #expect(CreditCardEngine.utilizationLevel(balance: 50, creditLimit: 5000) == .low) // 1%
        #expect(CreditCardEngine.utilizationLevel(balance: 499, creditLimit: 5000) == .low) // 9.98%

        // Yellow: right at 10% up to just under 30%.
        #expect(CreditCardEngine.utilizationLevel(balance: 500, creditLimit: 5000) == .medium) // exactly 10%
        #expect(CreditCardEngine.utilizationLevel(balance: 1000, creditLimit: 5000) == .medium) // 20%
        #expect(CreditCardEngine.utilizationLevel(balance: 1499, creditLimit: 5000) == .medium) // 29.98%

        // Red: right at 30% and above, including well past 50%.
        #expect(CreditCardEngine.utilizationLevel(balance: 1500, creditLimit: 5000) == .high) // exactly 30%
        #expect(CreditCardEngine.utilizationLevel(balance: 4000, creditLimit: 5000) == .high) // 80%

        // Zero balance/no limit: never flag as risky.
        #expect(CreditCardEngine.utilizationLevel(balance: 0, creditLimit: 5000) == .low)
        #expect(CreditCardEngine.utilizationLevel(balance: 1000, creditLimit: 0) == .low)
    }
}
