import Testing
import Foundation
import SwiftData
@testable import Fintrol

/// TRD/DESIGN_LIQUID.md "bloqueo de líneas pagadas" (2026-09-16, decisión del usuario): once a
/// line is confirmed paid (`isPaid == true`) it's frozen — edit, delete and activate/deactivate
/// must have no effect. `togglePaid` is the sole exempt action, since it's how the user unlocks
/// the line again. `PeriodCoordinator.canModify(line:)` is the single source of truth both
/// `PeriodView`'s mutation methods and `LineItemRow`'s UI read from.
@MainActor
@Suite("PeriodCoordinator — canModify / bloqueo de líneas pagadas")
struct LineLockTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, url: URL.temporaryDirectory.appending(path: UUID().uuidString + ".sqlite"))
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    /// Mirrors `PeriodView.togglePaid` exactly — the one action that must remain unguarded.
    private func togglePaid(_ line: LineItem) {
        line.isPaid.toggle()
        line.paidAt = line.isPaid ? CivilDate.today(calendar: .current) : nil
    }

    /// Mirrors `PeriodView.toggleActive`'s guard exactly (a no-op when the line is locked).
    private func toggleActive(_ line: LineItem) {
        guard PeriodCoordinator.canModify(line: line) else { return }
        line.isActive.toggle()
    }

    /// Mirrors `PeriodView.deleteLine`'s guard: a locked line survives the call untouched.
    private func attemptDelete(_ line: LineItem, in period: Period, context: ModelContext) {
        guard PeriodCoordinator.canModify(line: line) else { return }
        period.lineItems?.removeAll { $0.id == line.id }
        context.delete(line)
    }

    /// Mirrors `PeriodView.saveLine`'s existing-line-edit guard.
    private func attemptEdit(_ line: LineItem, newTitle: String, newAmount: Decimal) {
        guard PeriodCoordinator.canModify(line: line) else { return }
        line.title = newTitle
        line.amount = newAmount
    }

    @Test("canModify is true while unpaid, false once isPaid == true")
    func canModifyReflectsIsPaid() throws {
        let context = try makeContext()
        let period = Period(startDate: Date(), endDate: Date(), year: 2026, month: 9, half: .first)
        context.insert(period)
        let line = LineItem(kind: .expense, title: "Renta", amount: 100, currency: .usd, sortOrder: 0, origin: .manual, period: period)
        context.insert(line)
        period.lineItems = [line]
        try context.save()

        #expect(PeriodCoordinator.canModify(line: line) == true)
        togglePaid(line)
        #expect(PeriodCoordinator.canModify(line: line) == false)
        togglePaid(line)
        #expect(PeriodCoordinator.canModify(line: line) == true)
    }

    @Test("Editing, deleting or deactivating a paid line has no effect")
    func lockedLineIgnoresEditDeleteDeactivate() throws {
        let context = try makeContext()
        let period = Period(startDate: Date(), endDate: Date(), year: 2026, month: 9, half: .first)
        context.insert(period)
        let line = LineItem(kind: .expense, title: "Renta", amount: 100, currency: .usd, sortOrder: 0, origin: .manual, period: period)
        context.insert(line)
        period.lineItems = [line]
        try context.save()

        togglePaid(line) // lock it
        try context.save()
        #expect(line.isPaid == true)

        attemptEdit(line, newTitle: "Otro título", newAmount: 999)
        #expect(line.title == "Renta")
        #expect(line.amount == 100)

        toggleActive(line)
        #expect(line.isActive == true)

        attemptDelete(line, in: period, context: context)
        #expect(period.lineItems?.contains { $0.id == line.id } == true)
    }

    @Test("Unmarking paid unlocks the line — edit/delete/deactivate work again")
    func unmarkingPaidUnlocksLine() throws {
        let context = try makeContext()
        let period = Period(startDate: Date(), endDate: Date(), year: 2026, month: 9, half: .first)
        context.insert(period)
        let line = LineItem(kind: .expense, title: "Renta", amount: 100, currency: .usd, sortOrder: 0, origin: .manual, period: period)
        context.insert(line)
        period.lineItems = [line]
        try context.save()

        togglePaid(line) // lock
        try context.save()
        toggleActive(line) // blocked while locked
        #expect(line.isActive == true)

        togglePaid(line) // unlock
        try context.save()
        #expect(line.isPaid == false)

        toggleActive(line)
        #expect(line.isActive == false)

        attemptEdit(line, newTitle: "Renta editada", newAmount: 150)
        #expect(line.title == "Renta editada")
        #expect(line.amount == 150)

        attemptDelete(line, in: period, context: context)
        #expect(period.lineItems?.contains { $0.id == line.id } == false)
    }
}
