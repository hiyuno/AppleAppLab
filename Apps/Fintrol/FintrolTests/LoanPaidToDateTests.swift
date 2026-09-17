import Testing
import Foundation
import SwiftData
@testable import Fintrol

/// TRD "paidAt/progreso real de préstamos" (2026-09-16, decisión del usuario): a loan's
/// progress must only advance when the user manually confirms a payment (the `isPaid` swipe
/// toggle in `PeriodView`, which also sets `paidAt`) — never just because a scheduled period
/// date has passed. `PeriodCoordinator.loanPaidToDate`/`loanLastPaymentDate` are the single
/// source of truth both `LoanDetailView` and `LoansView`'s `LoanRow` read from.
@MainActor
@Suite("PeriodCoordinator — loan paidToDate/paidAt (real, user-confirmed progress)")
struct LoanPaidToDateTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, url: URL.temporaryDirectory.appending(path: UUID().uuidString + ".sqlite"))
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    /// Mirrors `PeriodView.togglePaid` exactly (can't drive the real SwiftUI view from a unit
    /// test, so this replicates its two-line effect): flips `isPaid` and sets/clears `paidAt`.
    private func togglePaid(_ line: LineItem) {
        line.isPaid.toggle()
        line.paidAt = line.isPaid ? CivilDate.today(calendar: .current) : nil
    }

    @Test("Marking a loan line paid advances paidToDate and records paidAt")
    func markingPaidAdvancesProgressAndRecordsPaidAt() throws {
        let context = try makeContext()
        let loan = Loan(name: "Ada", direction: .lent, principal: 1000, currency: .usd, apr: 0, startDate: Date(), termMonths: 4, frequency: .monthly(day: 1))
        context.insert(loan)

        let period = Period(startDate: Date(), endDate: Date(), year: 2026, month: 9, half: .first)
        context.insert(period)
        let line = LineItem(kind: .income, title: "Ada", amount: 250, currency: .usd, sortOrder: 0, origin: .loan, sourceLoanID: loan.id, period: period)
        context.insert(line)
        period.lineItems = [line]
        try context.save()

        #expect(PeriodCoordinator.loanPaidToDate(loanID: loan.id, context: context) == 0)
        #expect(PeriodCoordinator.loanLastPaymentDate(loanID: loan.id, context: context) == nil)

        togglePaid(line)
        try context.save()

        #expect(line.isPaid == true)
        #expect(line.paidAt == CivilDate.today(calendar: .current))
        #expect(PeriodCoordinator.loanPaidToDate(loanID: loan.id, context: context) == 250)
        #expect(PeriodCoordinator.loanLastPaymentDate(loanID: loan.id, context: context) == CivilDate.today(calendar: .current))
    }

    @Test("Unmarking a paid loan line retreats progress and clears paidAt")
    func unmarkingPaidRetreatsProgressAndClearsPaidAt() throws {
        let context = try makeContext()
        let loan = Loan(name: "Ada", direction: .lent, principal: 1000, currency: .usd, apr: 0, startDate: Date(), termMonths: 4, frequency: .monthly(day: 1))
        context.insert(loan)

        let period = Period(startDate: Date(), endDate: Date(), year: 2026, month: 9, half: .first)
        context.insert(period)
        let line = LineItem(kind: .income, title: "Ada", amount: 250, currency: .usd, sortOrder: 0, origin: .loan, sourceLoanID: loan.id, period: period)
        context.insert(line)
        period.lineItems = [line]
        try context.save()

        togglePaid(line) // mark paid
        try context.save()
        #expect(PeriodCoordinator.loanPaidToDate(loanID: loan.id, context: context) == 250)

        togglePaid(line) // unmark
        try context.save()

        #expect(line.isPaid == false)
        #expect(line.paidAt == nil)
        #expect(PeriodCoordinator.loanPaidToDate(loanID: loan.id, context: context) == 0)
        #expect(PeriodCoordinator.loanLastPaymentDate(loanID: loan.id, context: context) == nil)
    }

    @Test("A future/past line the user never marked paid does not count, even if its quincena date has already elapsed on the calendar")
    func unmarkedLineNeverCountsRegardlessOfCalendarDate() throws {
        let context = try makeContext()
        let loan = Loan(name: "Ada", direction: .lent, principal: 1000, currency: .usd, apr: 0, startDate: Date.distantPast, termMonths: 24, frequency: .monthly(day: 1))
        context.insert(loan)

        // A period whose own scheduled date is far in the past — but its line was never
        // manually confirmed, so it must not contribute to paidToDate.
        let pastPeriod = Period(startDate: Date(timeIntervalSince1970: 0), endDate: Date(timeIntervalSince1970: 86_400), year: 2020, month: 1, half: .first)
        context.insert(pastPeriod)
        let unmarkedLine = LineItem(kind: .income, title: "Ada", amount: 100, currency: .usd, sortOrder: 0, origin: .loan, sourceLoanID: loan.id, period: pastPeriod)
        context.insert(unmarkedLine)
        pastPeriod.lineItems = [unmarkedLine]

        // A different period, confirmed paid — only this one should count.
        let confirmedPeriod = Period(startDate: Date(), endDate: Date(), year: 2026, month: 9, half: .first)
        context.insert(confirmedPeriod)
        let confirmedLine = LineItem(kind: .income, title: "Ada", amount: 250, currency: .usd, sortOrder: 0, origin: .loan, sourceLoanID: loan.id, period: confirmedPeriod)
        context.insert(confirmedLine)
        confirmedPeriod.lineItems = [confirmedLine]
        try context.save()

        togglePaid(confirmedLine)
        try context.save()

        #expect(PeriodCoordinator.loanPaidToDate(loanID: loan.id, context: context) == 250)
        #expect(unmarkedLine.isPaid == false)
        #expect(unmarkedLine.paidAt == nil)
    }
}
