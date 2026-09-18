import Foundation

/// TRD "Credit Cards" (2026-09-17): reuses `LoanEngine`'s revolving-balance mechanics
/// (`monthlyRevolvingInterest`, `revolvingSchedule`) rather than reimplementing them — this
/// type only adds what's genuinely new to credit cards: the suggested minimum payment
/// formula.
public enum CreditCardEngine {
    /// `MAX($25, balance × 0.01 + interésDelMes)` — standard large-issuer formula (Chase/
    /// Experian/NerdWallet, cited in the plan). `interésDelMes` comes from
    /// `LoanEngine.monthlyRevolvingInterest`, never a second interest formula.
    public static func suggestedMinimumPayment(balance: Decimal, apr: Decimal) -> Decimal {
        guard balance > 0 else { return 0 }
        let interest = LoanEngine.monthlyRevolvingInterest(balance: balance, apr: apr)
        let onePercentPlusInterest = balance * Decimal(string: "0.01")! + interest
        return max(Decimal(25), onePercentPlusInterest)
    }

    /// Coordinator (2026-09-17), researched against 3 sources (myFICO, Experian, CFPB/
    /// NerdWallet): 3-tier utilization semaphore replacing the earlier single-threshold
    /// "Alta utilización ≥30%" rule. `< 10%` is the ideal/excellent range for credit score
    /// purposes, `10%–29.99%` is acceptable/good, `≥ 30%` starts noticeably hurting the score
    /// (more so ≥50%, but a 4th tier isn't needed — red from 30% up is enough).
    public enum UtilizationLevel: Sendable, Equatable {
        case low
        case medium
        case high
    }

    public static func utilizationLevel(balance: Decimal, creditLimit: Decimal) -> UtilizationLevel {
        guard creditLimit > 0, balance > 0 else { return .low }
        let fraction = balance / creditLimit
        if fraction < Decimal(string: "0.10")! { return .low }
        if fraction < Decimal(string: "0.30")! { return .medium }
        return .high
    }

    /// The `CivilDate` a card's payment falls on for the billing cycle anchored at
    /// `cutoffDay` in `year`/`month`, per `rule`. PRD acceptance example: cutoff day 15, rule
    /// "5 days before cutoff" → payment date = day 10, same month.
    ///
    /// Judgment call (not pinned further by TRD/PRD): `.onPaymentDate` anchors `paymentDay` to
    /// this SAME `year`/`month` as the cutoff, not a following month — real-world due dates
    /// often land ~3 weeks after cutoff, sometimes into the next month, but the spec doesn't
    /// give a month-rollover rule, and every worked example anchors both fields to the same
    /// billing month. Flagged here rather than silently assumed.
    public static func paymentDate(cutoffDay: Int, paymentDay: Int, year: Int, month: Int, rule: CreditCardPaymentDateRule) -> CivilDate {
        switch rule {
        case .onCutoffDate:
            return CivilDate(year: year, month: month, day: cutoffDay).clampedToValidDay
        case .daysBeforeCutoff(let n):
            return CivilDate(year: year, month: month, day: cutoffDay).clampedToValidDay.addingDays(-n)
        case .onPaymentDate:
            return CivilDate(year: year, month: month, day: paymentDay).clampedToValidDay
        }
    }

    /// One `GeneratedLine` (at most) for `coordinate` — mirrors
    /// `ProjectionEngine.generateRevolvingLoanLine`'s role for `Loan.revolving`. Computes the
    /// payment date for `coordinate`'s billing month via `paymentDate(...)`; if that date
    /// falls inside `coordinate`'s own date range, this quincena gets the line.
    ///
    /// Judgment call: unlike `Loan.revolving` (whose `principal` is the ORIGINAL amount at a
    /// persisted `startDate`, requiring a full historical walk through `actualPayments` to
    /// reconstruct today's balance), `CreditCard.balance` is already the CURRENT live balance
    /// — there is no persisted origination date to walk from. So this builds a fresh one-row
    /// `LoanEngine.revolvingSchedule` anchored at `due` each time, reusing its interest/
    /// real-vs-projected mixing for that single row rather than a second formula.
    /// `realPayment`, when non-nil (an existing manually-edited line for THIS period), wins
    /// over `expectedPayment`/the suggested minimum — same "manual edit wins" rule as
    /// everywhere else.
    public static func generatedLine(
        for coordinate: PeriodCoordinate,
        card: CreditCardSnapshot,
        dateRule: CreditCardPaymentDateRule,
        realPayment: Decimal?
    ) -> GeneratedLine? {
        guard card.isActive, card.balance > 0 else { return nil }
        let range = PeriodDateEngine.dateRange(for: coordinate)
        let due = paymentDate(cutoffDay: card.cutoffDay, paymentDay: card.paymentDay, year: coordinate.year, month: coordinate.month, rule: dateRule)
        guard due >= range.start, due <= range.end else { return nil }

        let expected = card.expectedPayment ?? suggestedMinimumPayment(balance: card.balance, apr: card.apr)
        let actualPayments: [CivilDate: Decimal] = realPayment.map { [due: $0] } ?? [:]
        // `frequency`'s day must be `due.day`, not `card.paymentDay` directly — for
        // `.onCutoffDate`/`.daysBeforeCutoff` rules the payment day is NOT `card.paymentDay`,
        // and `LoanEngine.installmentDate` derives each row's date from the frequency's own
        // day component, not from `start` verbatim (only `start`'s year/month anchor it).
        let result = LoanEngine.revolvingSchedule(
            principal: card.balance, apr: card.apr, expectedPayment: expected,
            frequency: .monthly(day: due.day), start: due, actualPayments: actualPayments
        )
        guard let row = result.rows.first else { return nil }
        return GeneratedLine(
            kind: .expense, title: card.name, amount: row.payment, currency: .usd,
            origin: .creditCard, sourceRecurringID: nil, sourceCreditCardID: card.id
        )
    }
}
