import Testing
import Foundation
import SwiftData
@testable import Fintrol

@MainActor
@Suite("Investments — RecurringItem.category == .investment (feature #12)")
struct InvestmentsTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, url: URL.temporaryDirectory.appending(path: UUID().uuidString + ".sqlite"))
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    /// GBM $300 biweekly from Sep 1 — materializing Sep 1–15 and Sep 16–30 each produce one
    /// `.investment`-origin line, and "aportado a la fecha" (sum of isActive lines) reflects
    /// both.
    @Test("GBM $300 cada quincena desde 1 sep: una línea en 1-15 y otra en 16-30")
    func biweeklyInvestmentGeneratesOneLinePerHalf() throws {
        let context = try makeContext()
        let gbm = RecurringItem(
            kind: .expense, title: "GBM", amount: 300, currency: .usd, frequency: .biweekly,
            startDate: Date(timeIntervalSince1970: 0), category: .investment, accountName: "GBM"
        )
        // Use civilStartDate so the CivilDate normalization matches what the UI would save.
        gbm.civilStartDate = CivilDate(year: 2026, month: 9, day: 1)
        context.insert(gbm)
        try context.save()

        let snapshot = RecurringItemSnapshot(
            id: gbm.id, kind: gbm.kind, title: gbm.title, amount: gbm.amount, currency: gbm.currency,
            frequency: gbm.frequency, startDate: gbm.civilStartDate, endDate: gbm.civilEndDate,
            isActive: gbm.isActive, category: gbm.category
        )

        let firstHalf = PeriodCoordinator.materializeIfNeeded(
            coordinate: PeriodCoordinate(year: 2026, month: 9, half: .first), context: context,
            recurringItems: [snapshot], subscriptions: [], exchangeRate: 18
        )
        let secondHalf = PeriodCoordinator.materializeIfNeeded(
            coordinate: PeriodCoordinate(year: 2026, month: 9, half: .second), context: context,
            recurringItems: [snapshot], subscriptions: [], exchangeRate: 18
        )

        let firstLine = (firstHalf.lineItems ?? []).first { $0.sourceRecurringID == gbm.id }
        let secondLine = (secondHalf.lineItems ?? []).first { $0.sourceRecurringID == gbm.id }

        #expect(firstLine?.origin == .investment)
        #expect(firstLine?.amount == 300)
        #expect(secondLine?.origin == .investment)
        #expect(secondLine?.amount == 300)

        let contributedToDate = [firstLine, secondLine].compactMap { $0 }.filter(\.isActive).reduce(Decimal(0)) { $0 + $1.amount }
        #expect(contributedToDate == 600)
    }

    @Test("Desactivar una línea de inversión baja el acumulado ('aportado a la fecha')")
    func deactivatingInvestmentLineLowersContributedToDate() throws {
        let context = try makeContext()
        let gbm = RecurringItem(
            kind: .expense, title: "GBM", amount: 300, currency: .usd, frequency: .biweekly,
            startDate: Date(timeIntervalSince1970: 0), category: .investment, accountName: "GBM"
        )
        gbm.civilStartDate = CivilDate(year: 2026, month: 9, day: 1)
        context.insert(gbm)
        try context.save()

        let snapshot = RecurringItemSnapshot(
            id: gbm.id, kind: gbm.kind, title: gbm.title, amount: gbm.amount, currency: gbm.currency,
            frequency: gbm.frequency, startDate: gbm.civilStartDate, endDate: gbm.civilEndDate,
            isActive: gbm.isActive, category: gbm.category
        )

        let firstHalf = PeriodCoordinator.materializeIfNeeded(
            coordinate: PeriodCoordinate(year: 2026, month: 9, half: .first), context: context,
            recurringItems: [snapshot], subscriptions: [], exchangeRate: 18
        )
        let secondHalf = PeriodCoordinator.materializeIfNeeded(
            coordinate: PeriodCoordinate(year: 2026, month: 9, half: .second), context: context,
            recurringItems: [snapshot], subscriptions: [], exchangeRate: 18
        )

        func contributedToDate() -> Decimal {
            let allLines = [firstHalf, secondHalf].flatMap { $0.lineItems ?? [] }.filter { $0.sourceRecurringID == gbm.id && $0.isActive }
            return allLines.reduce(Decimal(0)) { $0 + $1.amount }
        }

        #expect(contributedToDate() == 600)

        let firstLine = try #require((firstHalf.lineItems ?? []).first { $0.sourceRecurringID == gbm.id })
        firstLine.isActive = false
        firstLine.isManuallyEdited = true
        try context.save()

        #expect(contributedToDate() == 300)
    }

    @Test("Un RecurringItem .investment no aparece en Ingresos/Gastos recurrentes (solo en Inversiones)")
    func investmentExcludedFromOrdinaryRecurringLists() throws {
        let context = try makeContext()
        let gbm = RecurringItem(
            kind: .expense, title: "GBM", amount: 300, currency: .usd, frequency: .biweekly,
            startDate: Date(), category: .investment, accountName: "GBM"
        )
        let renta = RecurringItem(kind: .expense, title: "Renta", amount: 500, currency: .usd, frequency: .biweekly, startDate: Date())
        context.insert(gbm)
        context.insert(renta)
        try context.save()

        let all = try context.fetch(FetchDescriptor<RecurringItem>())
        let expenseListItems = all.filter { $0.kind == .expense && $0.category != .investment }
        let investmentListItems = all.filter { $0.category == .investment }

        #expect(expenseListItems.map(\.title) == ["Renta"])
        #expect(investmentListItems.map(\.title) == ["GBM"])
    }
}
