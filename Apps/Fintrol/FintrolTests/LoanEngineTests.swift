import Testing
import Foundation
@testable import Fintrol

/// TRD "Préstamos (Loans) — LoanEngine": the 5 mandatory tests, all pure (no SwiftData).
@Suite("LoanEngine — amortization")
struct LoanEngineTests {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> CivilDate {
        CivilDate(year: year, month: month, day: day)
    }

    // MARK: - 1. Upstart-like: $20,000 / 12% / 48 months -> $526.68

    @Test("principal=20000, apr=0.12, termMonths=48, monthly -> payment 526.68")
    func upstartLikePayment() {
        let payment = LoanEngine.payment(principal: 20000, apr: Decimal(string: "0.12")!, termMonths: 48, frequency: .monthly(day: 20))
        #expect(payment == Decimal(string: "526.68")!)
    }

    @Test("PRD example: principal=10000, apr=0.12, termMonths=24, monthly -> payment 470.73, first installment interest/principal/balance")
    func prdExamplePayment() {
        let payment = LoanEngine.payment(principal: 10000, apr: Decimal(string: "0.12")!, termMonths: 24, frequency: .monthly(day: 1))
        #expect(payment == Decimal(string: "470.73")!)

        let schedule = LoanEngine.schedule(principal: 10000, apr: Decimal(string: "0.12")!, startDate: date(2026, 1, 1), termMonths: 24, frequency: .monthly(day: 1))
        let first = schedule[0]
        #expect(first.interest == Decimal(string: "100.00")!)
        #expect(first.principal == Decimal(string: "370.73")!)
        #expect(first.remainingBalance == Decimal(string: "9629.27")!)
    }

    // MARK: - 2. apr = 0 -> exact principal / n, no residue

    @Test("apr=0 -> payment is exactly principal/n")
    func zeroAPRExactDivision() {
        let payment = LoanEngine.payment(principal: 12000, apr: 0, termMonths: 12, frequency: .monthly(day: 1))
        #expect(payment == 1000)

        let schedule = LoanEngine.schedule(principal: 12000, apr: 0, startDate: date(2026, 1, 1), termMonths: 12, frequency: .monthly(day: 1))
        #expect(schedule.allSatisfy { $0.interest == 0 })
        #expect(schedule.last?.remainingBalance == 0)
    }

    // MARK: - 3. Biweekly frequency uses r = apr/24 and n quincenal payments

    @Test("biweekly frequency uses apr/24 and generates termMonths*2 quincenal installments")
    func biweeklyFrequencyUsesCorrectRateAndCount() {
        let apr = Decimal(string: "0.12")!
        #expect(LoanEngine.periodicRate(apr: apr, frequency: .biweekly) == apr / 24)
        #expect(LoanEngine.periodicRate(apr: apr, frequency: .monthly(day: 1)) == apr / 12)

        let schedule = LoanEngine.schedule(principal: 5000, apr: apr, startDate: date(2026, 1, 1), termMonths: 6, frequency: .biweekly)
        #expect(schedule.count == 12, "6 months at biweekly frequency = 12 quincenal payments")

        // Consecutive installments are 15 days apart, not a month apart.
        #expect(schedule[0].date.addingDays(15) == schedule[1].date)
    }

    // MARK: - 4. Last payment closes the balance to exactly 0

    @Test("The last installment's remaining balance is exactly 0, not a residual fraction of a cent")
    func lastPaymentClosesBalanceToZero() {
        // A term/rate combination prone to rounding drift.
        let schedule = LoanEngine.schedule(principal: 7777, apr: Decimal(string: "0.0733")!, startDate: date(2026, 3, 1), termMonths: 37, frequency: .monthly(day: 15))
        #expect(schedule.last?.remainingBalance == 0)

        let biweeklySchedule = LoanEngine.schedule(principal: 9999, apr: Decimal(string: "0.185")!, startDate: date(2026, 1, 1), termMonths: 11, frequency: .biweekly)
        #expect(biweeklySchedule.last?.remainingBalance == 0)
    }

    // MARK: - 5. paymentOverride recalculates n consistently (round-trip within rounding tolerance)

    @Test("paymentOverride recalculates n so that recomputing the payment from that n reproduces the override")
    func paymentOverrideRoundTrips() {
        let principal = Decimal(20000)
        let apr = Decimal(string: "0.12")!
        let frequency = LoanFrequency.monthly(day: 20)

        // Take a known-good payment for a specific term (24 months) and feed it back as an
        // override — LoanEngine must derive n=24 again and reproduce that exact payment.
        let knownPayment = LoanEngine.payment(principal: principal, apr: apr, termMonths: 24, frequency: frequency)
        let derivedN = LoanEngine.numberOfPayments(forPayment: knownPayment, principal: principal, apr: apr, frequency: frequency)
        #expect(derivedN == 24)

        let roundTrippedPayment = LoanEngine.payment(principal: principal, apr: apr, termMonths: derivedN, frequency: frequency)
        #expect(roundTrippedPayment == knownPayment)

        // And the full schedule generated with paymentOverride matches: same n, balance closes to 0.
        let schedule = LoanEngine.schedule(principal: principal, apr: apr, startDate: date(2026, 1, 1), termMonths: 48, frequency: frequency, paymentOverride: knownPayment)
        #expect(schedule.count == 24)
        #expect(schedule.last?.remainingBalance == 0)
    }

    // MARK: - Additional coverage: plazo <-> fecha fin linked fields

    @Test("endDate(startDate:termMonths:frequency:) and termMonths(from:to:) round-trip for monthly frequency")
    func termMonthsEndDateRoundTrip() {
        let start = date(2026, 8, 1)
        let end = LoanEngine.endDate(startDate: start, termMonths: 48, frequency: .monthly(day: 20))
        let recomputedTerm = LoanEngine.termMonths(from: start, to: end)
        #expect(recomputedTerm == 48)
    }

    /// Bertrand's Stepper bug: fijar el plazo en 24 debía quedar estable, no oscilar.
    /// `LoanEditSheet` ahora deriva `endDate` de `termMonths` vía una `Binding` computada en
    /// vez de dos `@State` sincronizados por `onChange` — este test cubre el mecanismo puro
    /// (`LoanEngine`) del que depende esa `Binding`; la vista ya no puede desincronizarse
    /// porque `endDate` no se almacena por separado.
    @Test("Round-trip is stable specifically at termMonths = 24 (the value Bertrand couldn't set)")
    func termMonthsEndDateRoundTripAt24() {
        let start = date(2026, 1, 15)
        let end = LoanEngine.endDate(startDate: start, termMonths: 24, frequency: .monthly(day: 15))
        #expect(LoanEngine.termMonths(from: start, to: end) == 24)

        // Simulates the Binding's get/set chain one more time, as if re-reading after the
        // "write": still 24, not 23 or 25.
        let endAgain = LoanEngine.endDate(startDate: start, termMonths: LoanEngine.termMonths(from: start, to: end), frequency: .monthly(day: 15))
        #expect(LoanEngine.termMonths(from: start, to: endAgain) == 24)
    }

    @Test("monthlyOnDay clamps to the last valid day of a short month (e.g. day 31 in a 30-day month)")
    func installmentDateClampsToLastValidDay() {
        let schedule = LoanEngine.schedule(principal: 1200, apr: 0, startDate: date(2026, 1, 31), termMonths: 4, frequency: .monthly(day: 31))
        // April has 30 days -> installment 4 (April) clamps to the 30th.
        let april = schedule[3]
        #expect(april.date.month == 4)
        #expect(april.date.day == 30)
    }

    // MARK: - Bertrand (critical crash): absurd APR must never crash, even bypassing form validation

    @Test("An absurd APR (9,999%) compounded over 600 periods does not crash — LoanEngine fails closed instead of raising an NSDecimalNumber overflow exception")
    func absurdAPRDoesNotCrash() {
        let absurdAPR = Decimal(9999) // 9,999% — the form/model layer validates 0...1 (0-100%),
        // but the engine itself must never trust that alone (defense in depth).
        let payment = LoanEngine.payment(principal: 1_000_000_000, apr: absurdAPR, termMonths: 600, frequency: .monthly(day: 1))
        #expect(!payment.isNaN)

        let schedule = LoanEngine.schedule(principal: 1_000_000_000, apr: absurdAPR, startDate: date(2026, 1, 1), termMonths: 600, frequency: .monthly(day: 1))
        // Must not crash reaching this point — whatever it returns, every value is a finite Decimal.
        #expect(schedule.allSatisfy { !$0.payment.isNaN && !$0.interest.isNaN && !$0.principal.isNaN && !$0.remainingBalance.isNaN })
    }

    @Test("An absurd APR with a biweekly frequency (more periods, more compounding) also does not crash")
    func absurdAPRBiweeklyDoesNotCrash() {
        let payment = LoanEngine.payment(principal: 1_000_000_000, apr: Decimal(9999), termMonths: 600, frequency: .biweekly)
        #expect(!payment.isNaN)
    }

    @Test("numberOfPayments(forPayment:) with an absurd APR does not crash and returns a bounded result")
    func absurdAPRNumberOfPaymentsDoesNotCrash() {
        let n = LoanEngine.numberOfPayments(forPayment: 100, principal: 1_000_000_000, apr: Decimal(9999), frequency: .monthly(day: 1))
        #expect(n >= 0)
    }

    @Test("Direction determines LineKind: borrowed -> expense, lent -> income")
    func directionDeterminesKind() {
        let today = CivilDate.today()
        let borrowed = LoanSnapshot(id: UUID(), name: "Upstart", direction: .borrowed, principal: 1000, currency: .usd, apr: 0.1, startDate: today, termMonths: 12, frequency: .monthly(day: 1), paymentOverride: nil, isActive: true)
        let lent = LoanSnapshot(id: UUID(), name: "Ada", direction: .lent, principal: 1000, currency: .usd, apr: 0, startDate: today, termMonths: 12, frequency: .monthly(day: 1), paymentOverride: nil, isActive: true)
        #expect(borrowed.kind == .expense)
        #expect(lent.kind == .income)
    }

    @Test("generateLoanLines projects exactly one line per installment falling within the coordinate, with the right kind")
    func generateLoanLinesProjectsIntoCorrectHalf() {
        let loan = LoanSnapshot(id: UUID(), name: "Upstart #1", direction: .borrowed, principal: 20000, currency: .usd, apr: Decimal(string: "0.12")!, startDate: date(2026, 1, 20), termMonths: 48, frequency: .monthly(day: 20), paymentOverride: nil, isActive: true)
        let secondHalfJanuary = ProjectionEngine.generateLoanLines(for: PeriodCoordinate(year: 2026, month: 1, half: .second), loans: [loan])
        let firstHalfJanuary = ProjectionEngine.generateLoanLines(for: PeriodCoordinate(year: 2026, month: 1, half: .first), loans: [loan])

        #expect(secondHalfJanuary.count == 1)
        #expect(secondHalfJanuary.first?.kind == .expense)
        #expect(secondHalfJanuary.first?.origin == .loan)
        #expect(secondHalfJanuary.first?.amount == Decimal(string: "526.68")!)
        #expect(firstHalfJanuary.isEmpty)
    }

    // MARK: - Bertrand smoke test: a monthly loan with day-of-payment 20 must show 20, not 19

    @Test("A loan with frequency .monthly(day: 20) generates its installment on civil day 20, in both device time zones", arguments: [
        TimeZone(identifier: "America/Mexico_City")!,
        TimeZone(identifier: "UTC")!,
    ])
    func loanDay20InstallmentLandsOnDay20(deviceZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = deviceZone
        // Simulates a DatePicker-originated start date, normalized at the model boundary —
        // exactly what `Loan.civilStartDate` does.
        let pickerDate = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20))!
        let civilStart = CivilDate(from: pickerDate, calendar: calendar)

        let loan = LoanSnapshot(id: UUID(), name: "Bertrand's loan", direction: .borrowed, principal: 10000, currency: .usd, apr: Decimal(string: "0.1")!, startDate: civilStart, termMonths: 12, frequency: .monthly(day: 20), paymentOverride: nil, isActive: true)
        let schedule = LoanEngine.schedule(for: loan)

        #expect(schedule.first?.date.day == 20, "Device zone \(deviceZone.identifier): expected installment day 20, got \(String(describing: schedule.first?.date.day))")
        #expect(schedule.allSatisfy { $0.date.day == 20 })
    }
}

/// TRD "Modo `.revolving` — `LoanEngine.revolvingSchedule`": the 4 mandatory tests, all pure.
@Suite("LoanEngine — revolvingSchedule (\"Hasta liquidar\")")
struct LoanEngineRevolvingTests {
    private let start = CivilDate(year: 2026, month: 1, day: 1)

    // MARK: - 1. Caso Ada: interés mes 1 ~= 17.99, saldo tras 2 pagos

    @Test("Ada: principal=824, apr=26.2%, expectedPayment=200 quincenal -> interest month 1 ~= 17.99, balance after 2 payments")
    func adaCaseInterestAndBalanceAfterTwoPayments() {
        let result = LoanEngine.revolvingSchedule(
            principal: 824, apr: Decimal(string: "0.262")!, expectedPayment: 200,
            frequency: .biweekly, start: start, actualPayments: [:]
        )
        #expect(result.neverEnds == false)
        #expect(result.rows.count >= 2)

        let row1 = result.rows[0]
        #expect(row1.interest == Decimal(string: "17.99")!)
        #expect(row1.payment == 200)
        #expect(row1.remainingBalance == Decimal(string: "641.99")!)
        #expect(row1.isProjected == true)

        // Row 2 lands in the same civil month (Jan 1 -> Jan 16) -> no second interest charge.
        let row2 = result.rows[1]
        #expect(row2.date.month == row1.date.month)
        #expect(row2.interest == 0)
        #expect(row2.payment == 200)
        #expect(row2.remainingBalance == Decimal(string: "441.99")!)

        // A projected end date must exist (the schedule terminates, doesn't run forever).
        #expect(result.rows.last?.remainingBalance == 0)
    }

    // MARK: - 2. A real payment overrides expectedPayment and reshapes the balance forward

    @Test("A real payment of 150 (instead of the expected 200) on an already-materialized period recalculates the balance from there")
    func realPaymentOverridesExpectedAndReshapesBalance() {
        let secondDate = start.addingDays(15)
        let result = LoanEngine.revolvingSchedule(
            principal: 824, apr: Decimal(string: "0.262")!, expectedPayment: 200,
            frequency: .biweekly, start: start, actualPayments: [secondDate: 150]
        )

        let row1 = result.rows[0]
        #expect(row1.isProjected == true, "row 1 has no actual payment recorded -> still projected")
        #expect(row1.remainingBalance == Decimal(string: "641.99")!)

        let row2 = result.rows[1]
        #expect(row2.date == secondDate)
        #expect(row2.payment == 150)
        #expect(row2.isProjected == false, "a real payment was recorded for this date")
        #expect(row2.remainingBalance == Decimal(string: "491.99")!, "641.99 - 150, not 641.99 - 200")
    }

    // MARK: - 3. neverEnds when expectedPayment doesn't cover month-1 interest

    @Test("expectedPayment <= the initial month's interest -> neverEnds == true, bounded to 10 years, no infinite loop")
    func expectedPaymentBelowInterestNeverEnds() {
        // Month-1 interest on 824 at 26.2% APR is ~17.99 (see Ada test); biweekly means two
        // payments land per month, so the real comparison is 8*2=16, still short of 17.99.
        let result = LoanEngine.revolvingSchedule(
            principal: 824, apr: Decimal(string: "0.262")!, expectedPayment: 8,
            frequency: .biweekly, start: start, actualPayments: [:]
        )
        #expect(result.neverEnds == true)
        // Bounded to 10 years of biweekly periods (24/year) -> exactly 240 rows, not unbounded.
        #expect(result.rows.count == 24 * 10)
        // The balance must never have reached 0 (that's the whole point of "never ends").
        #expect(result.rows.allSatisfy { $0.remainingBalance > 0 })
    }

    // MARK: - 4. Liquidación anticipada: a real payment bigger than the balance clamps, never negative

    @Test("A real payment larger than the remaining balance clamps to exactly the balance — never a negative balance or an unexplained overpayment")
    func earlyPayoffClampsToExactBalance() {
        let thirdDate = LoanEngine.endDate(startDate: start, termMonths: 3, frequency: .monthly(day: 1))
        let result = LoanEngine.revolvingSchedule(
            principal: 300, apr: 0, expectedPayment: 100,
            frequency: .monthly(day: 1), start: start, actualPayments: [thirdDate: 500]
        )
        #expect(result.rows.count == 3)
        #expect(result.rows[0].remainingBalance == 200)
        #expect(result.rows[1].remainingBalance == 100)
        let last = result.rows[2]
        #expect(last.payment == 100, "clamped down from the 500 actual payment to the exact 100 remaining")
        #expect(last.remainingBalance == 0)
    }
}
