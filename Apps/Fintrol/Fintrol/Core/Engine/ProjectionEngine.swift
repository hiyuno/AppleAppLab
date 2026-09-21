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

    /// Coordinator (2026-09-21, user's request — Investments detail was only ever listing
    /// quincenas the user had actually visited/materialized in `Period`, so an account started
    /// years ago showed a handful of rows instead of its whole history, and never showed
    /// future rows past whatever the user had navigated to either): every `PeriodCoordinate`
    /// from `item`'s own start through `endCoordinate` (inclusive) at which it fires, computed
    /// purely from its frequency/vigencia — same "full deterministic table" idea as
    /// `LoanEngine.schedule`, just expressed as coordinates instead of installments, with zero
    /// dependency on which quincenas happen to exist in the store. Reuses
    /// `generateRecurringLines` per-coordinate instead of re-deriving the frequency rules.
    public static func occurrenceCoordinates(
        for item: RecurringItemSnapshot,
        through endCoordinate: PeriodCoordinate
    ) -> [PeriodCoordinate] {
        guard item.isActive else { return [] }
        var coordinate = PeriodDateEngine.coordinate(containing: item.startDate)
        guard coordinate <= endCoordinate else { return [] }

        var result: [PeriodCoordinate] = []
        while coordinate <= endCoordinate {
            if !generateRecurringLines(for: coordinate, recurringItems: [item]).isEmpty {
                result.append(coordinate)
            }
            coordinate = coordinate.next
        }
        return result
    }

    /// Coordinator (2026-09-21, user's request — breakdown sheet for the "Essentials"/
    /// "Payments"/"Servicios" aggregate rows, mirroring "Credit Cards Payments"): the exact set
    /// of `Subscription`s that make up `generateSubscriptionLine`'s combined total for
    /// `coordinate`/`kind` — extracted out of that function (which now just calls this and sums
    /// the result) so a breakdown UI can show the same list instead of re-deriving the filter.
    public static func contributingSubscriptions(
        for coordinate: PeriodCoordinate,
        subscriptions: [SubscriptionSnapshot],
        kind: SubscriptionKind
    ) -> [SubscriptionSnapshot] {
        let range = PeriodDateEngine.dateRange(for: coordinate)
        let isFirstHalf = coordinate.half == .first

        return subscriptions.filter { subscription in
            guard subscription.isActive else { return false }
            guard subscription.kind == kind else { return false }
            // Same fix as generateRecurringLines' .monthlyOnDay case: vigencia against the
            // whole quincena `range`, not the single `occurrence` day (Bug 2 — "Luz").
            guard isVigente(startDate: subscription.startDate, endDate: subscription.endDate, in: range) else { return false }
            // "Cada quincena" (2026-09-21): fires in BOTH halves while vigente — `paymentDay`'s
            // half no longer gates it, unlike the default "cada mes" behavior below.
            if subscription.isBiweekly {
                return true
            }
            guard (subscription.paymentDay <= 15) == isFirstHalf else { return false }
            let occurrence = PeriodDateEngine.date(forDayOfMonth: subscription.paymentDay, in: coordinate)
            return occurrence >= range.start && occurrence <= range.end
        }
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
        let isFirstHalf = coordinate.half == .first
        let active = contributingSubscriptions(for: coordinate, subscriptions: subscriptions, kind: kind)
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
        case .essential:
            title = isFirstHalf ? "Essentials 1–15" : "Essentials 16–30"
        }
        // Coordinator (2026-09-21): Essentials gets its own `LineOrigin` (not `.subscription` +
        // `isHomeService`) — that flag is only binary, and a third kind needs its own tag.
        let origin: LineOrigin = kind == .essential ? .essential : .subscription
        return GeneratedLine(kind: .expense, title: title, amount: total, currency: .usd, origin: origin, sourceRecurringID: nil, isHomeService: kind == .service)
    }

    /// Coordinator (2026-09-21, user's request — "si elimino/edito 'Food' aquí, solo debe
    /// afectar esta quincena, la definición se queda"): one real `LineItem` per contributing
    /// `Subscription` per half, mirroring `CreditCardEngine.generatedLine`/
    /// `generateRevolvingLoanLine` exactly — same vigencia/half-match rule
    /// `contributingSubscriptions` already encodes, applied to a single subscription instead of
    /// summing a whole kind. Supersedes `generateSubscriptionLine` for anything that WRITES
    /// `LineItem`s (materialization/reprojection); that combined-total function stays only for
    /// in-memory previews (`previewNextMonth`, Overview's `projectedTotals`) that never persist
    /// a line to edit/delete in the first place.
    public static func generatedLine(
        for coordinate: PeriodCoordinate,
        subscription: SubscriptionSnapshot,
        exchangeRate: Decimal
    ) -> GeneratedLine? {
        guard subscription.isActive else { return nil }
        let range = PeriodDateEngine.dateRange(for: coordinate)
        guard isVigente(startDate: subscription.startDate, endDate: subscription.endDate, in: range) else { return nil }

        if !subscription.isBiweekly {
            let isFirstHalf = coordinate.half == .first
            guard (subscription.paymentDay <= 15) == isFirstHalf else { return nil }
            let occurrence = PeriodDateEngine.date(forDayOfMonth: subscription.paymentDay, in: coordinate)
            guard occurrence >= range.start, occurrence <= range.end else { return nil }
        }

        let amount = CurrencyConversion.toUSD(amount: subscription.price, currency: subscription.currency, rate: exchangeRate)
        let origin: LineOrigin = subscription.kind == .essential ? .essential : .subscription
        return GeneratedLine(
            kind: .expense, title: subscription.name, amount: amount, currency: .usd, origin: origin,
            sourceRecurringID: nil, isHomeService: subscription.kind == .service, sourceSubscriptionID: subscription.id
        )
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
