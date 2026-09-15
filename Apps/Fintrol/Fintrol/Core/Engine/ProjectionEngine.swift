import Foundation

/// Expands `RecurringItem`/`Subscription` snapshots into the `LineItem`s a given
/// quincena should contain. Pure, `Sendable`, no SwiftData — the coordinator that
/// materializes a `Period` calls this and writes the result into the store.
///
/// All comparisons run on `CivilDate` (TRD "Decisiones de Swift" — Fechas), never `Date`/
/// `Calendar` directly — see `CivilDate.swift` for the bug this eliminates.
public enum ProjectionEngine {
    /// One `GeneratedLine` per recurring item vigente in `coordinate`, per its frequency:
    /// - `.biweekly` fires every quincena while vigente.
    /// - `.monthlyOnDay(d)` fires only in the half that contains day `d` of that month.
    /// - `.once(date)` fires only in the quincena containing `date`.
    public static func generateRecurringLines(
        for coordinate: PeriodCoordinate,
        recurringItems: [RecurringItemSnapshot]
    ) -> [GeneratedLine] {
        let range = PeriodDateEngine.dateRange(for: coordinate)
        var lines: [GeneratedLine] = []

        for item in recurringItems where item.isActive {
            switch item.frequency {
            case .biweekly:
                guard isVigente(startDate: item.startDate, endDate: item.endDate, in: range) else { continue }
                lines.append(makeLine(from: item))

            case .monthlyOnDay(let day):
                let occurrence = PeriodDateEngine.date(forDayOfMonth: day, in: coordinate)
                guard occurrence >= range.start, occurrence <= range.end else { continue }
                // Avie's fix: vigencia is evaluated against the whole quincena `range`, not the
                // single `occurrence` day. A service created Sep 15 with paymentDay 12 has an
                // occurrence of Sep 12 — before its own startDate — but the item is still
                // vigente for the rest of Sep 1–15 (the quincena that contains its start), so
                // it must still appear. Checking `on: occurrence` incorrectly excluded it.
                guard isVigente(startDate: item.startDate, endDate: item.endDate, in: range) else { continue }
                lines.append(makeLine(from: item))

            case .once(let date):
                // `.once`'s associated value is still a raw `Date` (a single-occurrence pick
                // from a `DatePicker`, not persisted through the CivilDate refactor's snapshot
                // fields) — normalize at the point of use via `.current`, exactly like any
                // other DatePicker value crossing into Core/Engine.
                let civilDate = CivilDate(from: date, calendar: .current)
                guard civilDate >= range.start, civilDate <= range.end else { continue }
                lines.append(makeLine(from: item))
            }
        }

        return lines
    }

    /// A single combined "Payments 1–15" / "Payments 16–30" (subscriptions) or "Servicios
    /// 1–15" / "Servicios 16–30" (home services) expense line, summing every `Subscription`
    /// of the matching `kind` whose payment day falls in `coordinate`'s half and is vigente
    /// there. `exchangeRate` (USD→MXN) converts MXN entries so the whole line is one USD
    /// total. Returns `nil` when nothing of that kind is active in that half (no empty line).
    public static func generateSubscriptionLine(
        for coordinate: PeriodCoordinate,
        subscriptions: [SubscriptionSnapshot],
        kind: SubscriptionKind,
        exchangeRate: Decimal
    ) -> GeneratedLine? {
        let range = PeriodDateEngine.dateRange(for: coordinate)
        let isFirstHalf = coordinate.half == .first

        let active = subscriptions.filter { subscription in
            guard subscription.isActive else { return false }
            guard subscription.kind == kind else { return false }
            guard (subscription.paymentDay <= 15) == isFirstHalf else { return false }
            let occurrence = PeriodDateEngine.date(forDayOfMonth: subscription.paymentDay, in: coordinate)
            guard occurrence >= range.start, occurrence <= range.end else { return false }
            // Same fix as generateRecurringLines' .monthlyOnDay case: vigencia against the
            // whole quincena `range`, not the single `occurrence` day (Bug 2 — "Luz").
            return isVigente(startDate: subscription.startDate, endDate: subscription.endDate, in: range)
        }

        guard !active.isEmpty else { return nil }

        let total = active.reduce(Decimal(0)) { partial, subscription in
            partial + CurrencyConversion.toUSD(amount: subscription.price, currency: subscription.currency, rate: exchangeRate)
        }

        let title: String
        switch kind {
        case .subscription:
            title = isFirstHalf ? "Payments 1–15" : "Payments 16–30"
        case .service:
            title = isFirstHalf ? "Servicios 1–15" : "Servicios 16–30"
        }
        return GeneratedLine(kind: .expense, title: title, amount: total, currency: .usd, origin: .subscription, sourceRecurringID: nil, isHomeService: kind == .service)
    }

    /// One `GeneratedLine` per loan installment (at most) that falls within `coordinate`'s
    /// date range — mirrors `generateRecurringLines`, but the amount comes from
    /// `LoanEngine.schedule` (declining-balance amortization) instead of a flat recurring
    /// amount, and the line's `kind` follows `LoanDirection` (`.borrowed` → expense, `.lent`
    /// → income).
    public static func generateLoanLines(
        for coordinate: PeriodCoordinate,
        loans: [LoanSnapshot]
    ) -> [GeneratedLine] {
        let range = PeriodDateEngine.dateRange(for: coordinate)
        var lines: [GeneratedLine] = []

        // `.revolving` loans need `actualPayments` (real edited lines, live SwiftData state)
        // to compute anything meaningful — `generateRevolvingLoanLine` below handles those;
        // this function only ever produces `.fixedTerm` lines.
        for loan in loans where loan.isActive && loan.mode == .fixedTerm {
            let installments = LoanEngine.schedule(for: loan)
            for installment in installments where installment.date >= range.start && installment.date <= range.end {
                lines.append(GeneratedLine(
                    kind: loan.kind, title: loan.name, amount: installment.payment, currency: loan.currency,
                    origin: .loan, sourceRecurringID: nil, sourceLoanID: loan.id
                ))
            }
        }

        return lines
    }

    /// `.revolving` counterpart of `generateLoanLines` — one `GeneratedLine` (at most) for
    /// `coordinate`, using `LoanEngine.revolvingSchedule`. `actualPayments` is supplied by the
    /// caller (`PeriodCoordinator`, which alone has access to real, already-materialized
    /// `LineItem`s) — this stays pure otherwise.
    public static func generateRevolvingLoanLine(
        for coordinate: PeriodCoordinate,
        loan: LoanSnapshot,
        actualPayments: [CivilDate: Decimal]
    ) -> GeneratedLine? {
        guard loan.isActive, loan.mode == .revolving, let expectedPayment = loan.expectedPayment else { return nil }
        let range = PeriodDateEngine.dateRange(for: coordinate)
        let result = LoanEngine.revolvingSchedule(
            principal: loan.principal, apr: loan.apr, expectedPayment: expectedPayment,
            frequency: loan.frequency, start: loan.startDate, actualPayments: actualPayments
        )
        guard let row = result.rows.first(where: { $0.date >= range.start && $0.date <= range.end }) else { return nil }
        return GeneratedLine(
            kind: loan.kind, title: loan.name, amount: row.payment, currency: loan.currency,
            origin: .loan, sourceRecurringID: nil, sourceLoanID: loan.id
        )
    }

    /// The "manual edit wins" rule (TRD): when a `RecurringItem` changes, only the
    /// materialized lines it previously generated that the user has **not** manually
    /// edited should be overwritten with the new value. Returns the ids to regenerate.
    public static func lineIDsToRegenerate(
        matchingRecurringID: UUID,
        materializedLines: [(id: UUID, sourceRecurringID: UUID?, isManuallyEdited: Bool)]
    ) -> [UUID] {
        materializedLines
            .filter { $0.sourceRecurringID == matchingRecurringID && !$0.isManuallyEdited }
            .map(\.id)
    }

    private static func makeLine(from item: RecurringItemSnapshot) -> GeneratedLine {
        GeneratedLine(kind: item.kind, title: item.title, amount: item.amount, currency: item.currency, origin: item.category == .investment ? .investment : .recurring, sourceRecurringID: item.id)
    }

    private static func isVigente(startDate: CivilDate, endDate: CivilDate?, in range: (start: CivilDate, end: CivilDate)) -> Bool {
        if startDate > range.end { return false }
        if let endDate, endDate < range.start { return false }
        return true
    }
}
