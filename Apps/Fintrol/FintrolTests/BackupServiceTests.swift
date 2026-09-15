import Testing
import Foundation
import SwiftData
@testable import Fintrol

@MainActor
@Suite("BackupService — full export/import round trip")
struct BackupServiceTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @Test("Exporting then importing into a fresh store reproduces every field on every model type")
    func roundTripReproducesAllData() throws {
        let sourceContext = try makeContext()

        let period = Period(startDate: Date(), endDate: Date(), year: 2026, month: 9, half: .second)
        sourceContext.insert(period)
        let line = LineItem(kind: .income, title: "Ada", amount: 200, currency: .usd, isPaid: true, isActive: false, sortOrder: 0, origin: .loan, isManuallyEdited: true, period: period)
        sourceContext.insert(line)
        period.lineItems = [line]

        let recurring = RecurringItem(kind: .income, title: "WALO", amount: 2750, currency: .usd, frequency: .biweekly, startDate: Date())
        sourceContext.insert(recurring)

        let subscription = Subscription(name: "Netflix", price: 15.99, currency: .usd, paymentDay: 5, startDate: Date(), category: .entertainment)
        sourceContext.insert(subscription)

        let loan = Loan(name: "Ada", direction: .lent, principal: 824, currency: .usd, apr: Decimal(string: "0.262")!, startDate: Date(), termMonths: 1, frequency: .biweekly, mode: .revolving, expectedPayment: 200)
        sourceContext.insert(loan)

        let rate = ExchangeRateCache(date: Date(), rate: 18.45, fetchedFromAPI: true)
        sourceContext.insert(rate)

        try sourceContext.save()

        let backup = BackupService.exportBackup(context: sourceContext)
        let data = try #require(BackupService.encode(backup))
        let decoded = try #require(BackupService.decode(data))

        let destContext = try makeContext()
        let summary = BackupService.importBackup(decoded, context: destContext)

        #expect(summary.periods == 1)
        #expect(summary.lineItems == 1)
        #expect(summary.recurringItems == 1)
        #expect(summary.subscriptions == 1)
        #expect(summary.loans == 1)
        #expect(summary.rateEntries == 1)

        let restoredLoans = try destContext.fetch(FetchDescriptor<Loan>())
        let restoredLoan = try #require(restoredLoans.first)
        #expect(restoredLoan.name == "Ada")
        #expect(restoredLoan.mode == .revolving)
        #expect(restoredLoan.expectedPayment == 200)

        let restoredPeriods = try destContext.fetch(FetchDescriptor<Period>())
        let restoredPeriod = try #require(restoredPeriods.first)
        let restoredLine = try #require((restoredPeriod.lineItems ?? []).first)
        #expect(restoredLine.title == "Ada")
        #expect(restoredLine.isPaid == true)
        #expect(restoredLine.isActive == false)
        #expect(restoredLine.isManuallyEdited == true)
    }

    @Test("Importing again with an item removed from the backup deletes it locally (dedupe by id = full replace)")
    func importDeletesRecordsMissingFromBackup() throws {
        let context = try makeContext()
        let recurring = RecurringItem(kind: .expense, title: "Renta", amount: 500, currency: .usd, frequency: .biweekly, startDate: Date())
        context.insert(recurring)
        try context.save()

        var backup = BackupService.exportBackup(context: context)
        #expect(backup.recurringItems.count == 1)
        backup.recurringItems = []

        let summary = BackupService.importBackup(backup, context: context)
        #expect(summary.recurringItems == 0)
        let remaining = try context.fetch(FetchDescriptor<RecurringItem>())
        #expect(remaining.isEmpty)
    }
}
