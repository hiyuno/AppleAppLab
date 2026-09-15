import Foundation
import SwiftData

/// The "thin coordinator" the TRD calls for: bridges pure `Core/Engine` structs with the
/// live `ModelContext`. Materializes quincenas lazily, propagates the carry-over chain
/// incrementally after an edit, and resolves "Next Month" through the single unified
/// `CarryOverEngine.previewNextMonth` formula. Runs on `MainActor` — SwiftData in this app
/// never leaves the main actor (TRD: no background `ModelActor`, volume is trivial).
@MainActor
public enum PeriodCoordinator {
    // MARK: - Lookup

    public static func fetchPeriod(coordinate: PeriodCoordinate, context: ModelContext) -> Period? {
        let year = coordinate.year
        let month = coordinate.month
        let halfRaw = coordinate.half.rawValue
        let descriptor = FetchDescriptor<Period>(
            predicate: #Predicate { $0.year == year && $0.month == month && $0.halfRaw == halfRaw }
        )
        return try? context.fetch(descriptor).first
    }

    /// The earliest quincena the user has ever materialized — there is no "before" this
    /// coordinate (TRD: no symmetric past projection).
    public static func earliestMaterializedCoordinate(context: ModelContext) -> PeriodCoordinate? {
        let descriptor = FetchDescriptor<Period>()
        guard let all = try? context.fetch(descriptor), !all.isEmpty else { return nil }
        return all.map(\.coordinate).min()
    }

    // MARK: - Materialization (lazy, iterative — never recurses per-quincena)

    /// Materializes `coordinate` if needed, along with any intermediate quincenas between
    /// the earliest already-materialized one and `coordinate` (so the carry-over chain is
    /// always complete). Bounded to the distance actually navigated — never touches
    /// quincenas the user hasn't visited.
    @discardableResult
    public static func materializeIfNeeded(
        coordinate: PeriodCoordinate,
        context: ModelContext,
        recurringItems: [RecurringItemSnapshot],
        subscriptions: [SubscriptionSnapshot],
        loans: [LoanSnapshot] = [],
        exchangeRate: Decimal
    ) -> Period {
        if let existing = fetchPeriod(coordinate: coordinate, context: context) {
            // Avie's fix: purge before returning — this is the "opening a Period" moment the
            // rest of the app treats as fresh/authoritative (PeriodView's `.onAppear` and
            // `.task` both funnel through here), so it's the cheapest reliable point to catch
            // garbage left behind by a raw `context.delete` (a bypass of `deleteRecurring`/
            // `deleteLoan`, or leftovers from before those existed) without scanning the whole
            // store on every navigation.
            purgeOrphanLines(in: existing, context: context, exchangeRate: exchangeRate)
            return existing
        }

        let anchor = earliestMaterializedCoordinate(context: context)

        guard let anchor else {
            // Empty store: this coordinate becomes the first quincena ever, no carry-over.
            return createPeriod(coordinate, context: context, recurringItems: recurringItems, subscriptions: subscriptions, loans: loans, exchangeRate: exchangeRate)
        }

        guard coordinate > anchor else {
            // FIN-2026-BERTRAND-01 (fixed): TRD — "no existen quincenas anteriores a la
            // primera materializada". `coordinate < anchor` (`== anchor` already returned
            // above via the existing-period check) must never materialize anything before
            // the anchor; clamp to the anchor's own period instead of moving the historical
            // limit backward.
            if let clamped = fetchPeriod(coordinate: anchor, context: context) {
                purgeOrphanLines(in: clamped, context: context, exchangeRate: exchangeRate)
                return clamped
            }
            return createPeriod(anchor, context: context, recurringItems: recurringItems, subscriptions: subscriptions, loans: loans, exchangeRate: exchangeRate)
        }

        var toCreate: [PeriodCoordinate] = []
        var cursor = coordinate
        while cursor > anchor, fetchPeriod(coordinate: cursor, context: context) == nil {
            toCreate.append(cursor)
            cursor = cursor.previous
        }
        toCreate.reverse()

        var lastPeriod: Period?
        for coord in toCreate {
            lastPeriod = createPeriod(
                coord,
                context: context,
                recurringItems: recurringItems,
                subscriptions: subscriptions,
                loans: loans,
                exchangeRate: exchangeRate
            )
        }
        return lastPeriod ?? fetchPeriod(coordinate: coordinate, context: context)!
    }

    private static func createPeriod(
        _ coordinate: PeriodCoordinate,
        context: ModelContext,
        recurringItems: [RecurringItemSnapshot],
        subscriptions: [SubscriptionSnapshot],
        loans: [LoanSnapshot],
        exchangeRate: Decimal
    ) -> Period {
        let range = PeriodDateEngine.dateRange(for: coordinate)
        let period = Period(
            startDate: range.start.date(calendar: .current),
            endDate: range.end.date(calendar: .current),
            year: coordinate.year,
            month: coordinate.month,
            half: coordinate.half,
            isMaterialized: true,
            lineItems: []
        )
        context.insert(period)

        var lines: [LineItem] = []
        var order = 0

        if let previous = fetchPeriod(coordinate: coordinate.previous, context: context) {
            let previousLines = snapshots(of: previous)
            let sobrante = CarryOverEngine.sobrante(for: previousLines, exchangeRate: exchangeRate)
            let carryLine = LineItem(
                kind: .income, title: "Latest Month", amount: sobrante, currency: .usd,
                sortOrder: order, origin: .carryOver, period: period
            )
            context.insert(carryLine)
            lines.append(carryLine)
            order += 1
        }

        for generated in ProjectionEngine.generateRecurringLines(for: coordinate, recurringItems: recurringItems) {
            let line = LineItem(
                kind: generated.kind, title: generated.title, amount: generated.amount, currency: generated.currency,
                sortOrder: order, origin: generated.origin, sourceRecurringID: generated.sourceRecurringID, period: period
            )
            context.insert(line)
            lines.append(line)
            order += 1
        }

        for kind in [SubscriptionKind.subscription, .service] {
            if let generated = ProjectionEngine.generateSubscriptionLine(for: coordinate, subscriptions: subscriptions, kind: kind, exchangeRate: exchangeRate) {
                let line = LineItem(
                    kind: generated.kind, title: generated.title, amount: generated.amount,
                    currency: generated.currency, sortOrder: order, origin: generated.origin,
                    isHomeService: generated.isHomeService, period: period
                )
                context.insert(line)
                lines.append(line)
                order += 1
            }
        }

        for generated in ProjectionEngine.generateLoanLines(for: coordinate, loans: loans) {
            let line = LineItem(
                kind: generated.kind, title: generated.title, amount: generated.amount, currency: generated.currency,
                sortOrder: order, origin: generated.origin, sourceLoanID: generated.sourceLoanID,
                // TRD: MXN loan payments convert at the rate vigente in the quincena where
                // the payment falls, snapshotted at materialization time (same idea as "Mandar").
                exchangeRateSnapshot: generated.currency == .mxn ? exchangeRate : nil,
                period: period
            )
            context.insert(line)
            lines.append(line)
            order += 1
        }

        period.lineItems = lines
        return period
    }

    // MARK: - Carry-over propagation after an edit

    /// Call after any confirmed edit to a line inside `period`. Recomputes `period`'s
    /// sobrante and propagates it forward through already-materialized quincenas until
    /// the chain hits a fixed point (TRD: incremental recompute, not a full rewrite).
    public static func recomputeForward(after period: Period, context: ModelContext, exchangeRate: Decimal) {
        let editedLines = snapshots(of: period)
        let newSobrante = CarryOverEngine.sobrante(for: editedLines, exchangeRate: exchangeRate)

        var chain: [CarryOverEngine.ChainEntry] = []
        var chainPeriods: [PeriodCoordinate: Period] = [:]
        var cursor = period.coordinate.next
        while let next = fetchPeriod(coordinate: cursor, context: context) {
            let carryAmount = (next.lineItems ?? []).first { $0.origin == .carryOver }?.amount ?? 0
            let nonCarryOver = (next.lineItems ?? [])
                .filter { $0.origin != .carryOver }
                .map { LineSnapshot(kind: $0.kind, amount: $0.amount, currency: $0.currency, origin: $0.origin) }
            chain.append(CarryOverEngine.ChainEntry(coordinate: cursor, nonCarryOverLines: nonCarryOver, previousCarryOverReceived: carryAmount))
            chainPeriods[cursor] = next
            cursor = cursor.next
        }

        let updates = CarryOverEngine.recomputeForward(materializedChain: chain, startingSobrante: newSobrante, exchangeRate: exchangeRate)
        for (coordinate, newAmount) in updates {
            guard let targetPeriod = chainPeriods[coordinate] else { continue }
            if let carryLine = (targetPeriod.lineItems ?? []).first(where: { $0.origin == .carryOver }) {
                carryLine.amount = newAmount
            }
        }
    }

    // MARK: - Next Month (unified preview, materializes nothing)

    public static func previewNextMonth(
        after period: Period,
        context: ModelContext,
        recurringItems: [RecurringItemSnapshot],
        subscriptions: [SubscriptionSnapshot],
        loans: [LoanSnapshot] = [],
        exchangeRate: Decimal
    ) -> Decimal {
        let nextCoordinate = period.coordinate.next

        if let materialized = fetchPeriod(coordinate: nextCoordinate, context: context) {
            return CarryOverEngine.previewNextMonth(lines: snapshots(of: materialized), exchangeRate: exchangeRate)
        }

        let carryOverAmount = CarryOverEngine.sobrante(for: snapshots(of: period), exchangeRate: exchangeRate)
        var projected = ProjectionEngine.generateRecurringLines(for: nextCoordinate, recurringItems: recurringItems)
            .map { LineSnapshot(kind: $0.kind, amount: $0.amount, currency: $0.currency, origin: $0.origin) }
        for kind in [SubscriptionKind.subscription, .service] {
            if let generated = ProjectionEngine.generateSubscriptionLine(for: nextCoordinate, subscriptions: subscriptions, kind: kind, exchangeRate: exchangeRate) {
                projected.append(LineSnapshot(kind: generated.kind, amount: generated.amount, currency: generated.currency, origin: generated.origin))
            }
        }
        for generated in ProjectionEngine.generateLoanLines(for: nextCoordinate, loans: loans) {
            projected.append(LineSnapshot(kind: generated.kind, amount: generated.amount, currency: generated.currency, origin: generated.origin))
        }
        projected.append(LineSnapshot(kind: .income, amount: carryOverAmount, currency: .usd, origin: .carryOver))
        return CarryOverEngine.previewNextMonth(lines: projected, exchangeRate: exchangeRate)
    }

    // MARK: - Reprojecting onto already-materialized periods

    /// Bug found by Avie: creating/editing a `RecurringItem` only ever affected lines that
    /// *already existed* (the old `regenerateLines`) — a brand-new recurring item never got
    /// inserted into quincenas already materialized before it existed, and no carry-over
    /// recompute ever ran. This walks every materialized `Period`, and for each one:
    /// - no line yet, but `item` is now vigente there → **creates** the line.
    /// - a line exists, not manually edited, still vigente → **updates** it (amount/title/currency).
    /// - a line exists, not manually edited, no longer vigente (end date / inactive) → **removes** it.
    /// - a line exists and `isManuallyEdited` → **never touched** ("manual edit wins").
    /// Finishes with a single `recomputeForward` from the earliest period actually touched,
    /// so the carry-over chain reflects the change immediately, not just on next navigation.
    public static func reprojectRecurring(item: RecurringItem, context: ModelContext, exchangeRate: Decimal) {
        let snapshot = RecurringItemSnapshot(
            id: item.id, kind: item.kind, title: item.title, amount: item.amount, currency: item.currency,
            frequency: item.frequency, startDate: item.civilStartDate, endDate: item.civilEndDate, isActive: item.isActive
        )
        let allPeriods = ((try? context.fetch(FetchDescriptor<Period>())) ?? []).sorted { $0.coordinate < $1.coordinate }
        guard !allPeriods.isEmpty else { return }

        var earliestTouched: Period?

        for period in allPeriods {
            // Idempotency belt: two reprojection passes (or a race between them) must never
            // leave two LineItems for the same source in the same Period — keep the first,
            // delete the rest, before deciding whether to create/update/remove.
            dedupeLines(in: period, context: context, matching: { $0.sourceRecurringID == item.id })
            let existingLine = (period.lineItems ?? []).first { $0.sourceRecurringID == item.id }
            let generated = ProjectionEngine.generateRecurringLines(for: period.coordinate, recurringItems: [snapshot]).first

            if let existingLine {
                guard !existingLine.isManuallyEdited else { continue }
                if let generated {
                    existingLine.title = generated.title
                    existingLine.amount = generated.amount
                    existingLine.currency = generated.currency
                } else {
                    period.lineItems?.removeAll { $0.id == existingLine.id }
                    context.delete(existingLine)
                }
                if earliestTouched == nil { earliestTouched = period }
            } else if let generated {
                let nextOrder = ((period.lineItems ?? []).map(\.sortOrder).max() ?? -1) + 1
                let newLine = LineItem(
                    kind: generated.kind, title: generated.title, amount: generated.amount, currency: generated.currency,
                    sortOrder: nextOrder, origin: generated.origin, sourceRecurringID: generated.sourceRecurringID, period: period
                )
                context.insert(newLine)
                period.lineItems?.append(newLine)
                if earliestTouched == nil { earliestTouched = period }
            }
        }

        try? context.save()
        if let earliestTouched {
            recomputeForward(after: earliestTouched, context: context, exchangeRate: exchangeRate)
            try? context.save()
        }
    }

    /// Same bug, same fix, for the combined "Payments"/"Servicios" line: since that line
    /// sums *every* `Subscription` of the given `kind` (not one item — there's no
    /// `sourceRecurringID` to key off), it's identified per period by
    /// `origin == .subscription && isHomeService == (kind == .service)`. Call after any
    /// create/edit/delete of a `Subscription` with its `kind`.
    public static func reprojectSubscription(kind: SubscriptionKind, context: ModelContext, exchangeRate: Decimal) {
        let allSubscriptions = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        let snapshots = allSubscriptions.filter { $0.kind == kind }.map {
            SubscriptionSnapshot(id: $0.id, name: $0.name, price: $0.price, currency: $0.currency, paymentDay: $0.paymentDay, startDate: $0.civilStartDate, endDate: $0.civilEndDate, kind: $0.kind)
        }
        let allPeriods = ((try? context.fetch(FetchDescriptor<Period>())) ?? []).sorted { $0.coordinate < $1.coordinate }
        guard !allPeriods.isEmpty else { return }

        let wantsHomeService = kind == .service
        var earliestTouched: Period?

        for period in allPeriods {
            dedupeLines(in: period, context: context, matching: { $0.origin == .subscription && $0.isHomeService == wantsHomeService })
            let existingLine = (period.lineItems ?? []).first { $0.origin == .subscription && $0.isHomeService == wantsHomeService }
            let generated = ProjectionEngine.generateSubscriptionLine(for: period.coordinate, subscriptions: snapshots, kind: kind, exchangeRate: exchangeRate)

            if let existingLine {
                guard !existingLine.isManuallyEdited else { continue }
                if let generated {
                    existingLine.title = generated.title
                    existingLine.amount = generated.amount
                    existingLine.currency = generated.currency
                } else {
                    period.lineItems?.removeAll { $0.id == existingLine.id }
                    context.delete(existingLine)
                }
                if earliestTouched == nil { earliestTouched = period }
            } else if let generated {
                let nextOrder = ((period.lineItems ?? []).map(\.sortOrder).max() ?? -1) + 1
                let newLine = LineItem(
                    kind: generated.kind, title: generated.title, amount: generated.amount, currency: generated.currency,
                    sortOrder: nextOrder, origin: generated.origin, isHomeService: generated.isHomeService, period: period
                )
                context.insert(newLine)
                period.lineItems?.append(newLine)
                if earliestTouched == nil { earliestTouched = period }
            }
        }

        try? context.save()
        if let earliestTouched {
            recomputeForward(after: earliestTouched, context: context, exchangeRate: exchangeRate)
            try? context.save()
        }
    }

    /// Same bug, same fix, for `Loan` — symmetric to `reprojectRecurring`, keyed by
    /// `sourceLoanID` instead of `sourceRecurringID`. A period stops getting a line once it's
    /// past the loan's schedule (deactivated, term ended, or `paymentOverride` shortened it).
    public static func reprojectLoan(item: Loan, context: ModelContext, exchangeRate: Decimal) {
        let snapshot = LoanSnapshot(
            id: item.id, name: item.name, direction: item.direction, principal: item.principal,
            currency: item.currency, apr: item.apr, startDate: item.civilStartDate, termMonths: item.termMonths,
            frequency: item.frequency, paymentOverride: item.paymentOverride, isActive: item.isActive
        )
        let allPeriods = ((try? context.fetch(FetchDescriptor<Period>())) ?? []).sorted { $0.coordinate < $1.coordinate }
        guard !allPeriods.isEmpty else { return }

        var earliestTouched: Period?

        for period in allPeriods {
            dedupeLines(in: period, context: context, matching: { $0.sourceLoanID == item.id })
            let existingLine = (period.lineItems ?? []).first { $0.sourceLoanID == item.id }
            let generated = ProjectionEngine.generateLoanLines(for: period.coordinate, loans: [snapshot]).first

            if let existingLine {
                guard !existingLine.isManuallyEdited else { continue }
                if let generated {
                    existingLine.title = generated.title
                    existingLine.amount = generated.amount
                    existingLine.currency = generated.currency
                    existingLine.exchangeRateSnapshot = generated.currency == .mxn ? exchangeRate : nil
                } else {
                    period.lineItems?.removeAll { $0.id == existingLine.id }
                    context.delete(existingLine)
                }
                if earliestTouched == nil { earliestTouched = period }
            } else if let generated {
                let nextOrder = ((period.lineItems ?? []).map(\.sortOrder).max() ?? -1) + 1
                let newLine = LineItem(
                    kind: generated.kind, title: generated.title, amount: generated.amount, currency: generated.currency,
                    sortOrder: nextOrder, origin: generated.origin, sourceLoanID: generated.sourceLoanID,
                    exchangeRateSnapshot: generated.currency == .mxn ? exchangeRate : nil, period: period
                )
                context.insert(newLine)
                period.lineItems?.append(newLine)
                if earliestTouched == nil { earliestTouched = period }
            }
        }

        try? context.save()
        if let earliestTouched {
            recomputeForward(after: earliestTouched, context: context, exchangeRate: exchangeRate)
            try? context.save()
        }
    }

    // MARK: - Deletion (cascades to generated LineItems — Avie's fix)

    /// Bug found by Avie: `context.delete(item)` alone (the UI's swipe-to-delete) removes the
    /// `RecurringItem`/`Subscription`/`Loan` but leaves every `LineItem` it ever generated
    /// behind — `dedupeLines` in `reproject*` only compares against the *current* source's id,
    /// so an orphaned line (whose source no longer exists) can never be recognized as a
    /// duplicate of anything, which is exactly the "triplicado" Bertrand hit: create → delete
    /// → recreate, three times, leaves three permanently-orphaned lines with three different
    /// (all now-invalid) `sourceRecurringID`s. `deleteRecurring`/`deleteLoan`/
    /// `deleteSubscription` are the only correct way to delete these three model types —
    /// UI delete buttons must call these, never `context.delete` directly.

    /// Deletes `item` and purges every `LineItem` it generated, across every materialized
    /// `Period`. Captures `item.id` before deleting — `purgeLines` must key off the id, not a
    /// live re-projection, because a deleted source can no longer honestly answer "am I still
    /// vigente here".
    public static func deleteRecurring(_ item: RecurringItem, context: ModelContext, exchangeRate: Decimal) {
        let id = item.id
        context.delete(item)
        try? context.save()
        purgeLines(context: context, exchangeRate: exchangeRate) { $0.sourceRecurringID == id }
    }

    /// Same fix, for `Loan`.
    public static func deleteLoan(_ item: Loan, context: ModelContext, exchangeRate: Decimal) {
        let id = item.id
        context.delete(item)
        try? context.save()
        purgeLines(context: context, exchangeRate: exchangeRate) { $0.sourceLoanID == id }
    }

    /// `Subscription` has no per-item generated line — every subscription of a `kind` feeds
    /// one combined "Payments"/"Servicios" line — so deleting one doesn't orphan a line the
    /// way Recurring/Loan do. Re-running `reprojectSubscription(kind:)` after the delete
    /// recomputes that combined line (or removes it entirely) from whichever subscriptions of
    /// that kind remain.
    public static func deleteSubscription(_ item: Subscription, context: ModelContext, exchangeRate: Decimal) {
        let kind = item.kind
        context.delete(item)
        try? context.save()
        reprojectSubscription(kind: kind, context: context, exchangeRate: exchangeRate)
    }

    /// Deletes every `LineItem`, across every materialized `Period`, that matches `matching`
    /// and has not been manually edited (manual-edit-wins still applies — a hand-edited line
    /// survives its source's deletion until the user removes it themselves). Runs a single
    /// `recomputeForward` from the earliest touched period so the carry-over chain reflects
    /// the purge immediately.
    public static func purgeLines(context: ModelContext, exchangeRate: Decimal, matching: (LineItem) -> Bool) {
        let allPeriods = ((try? context.fetch(FetchDescriptor<Period>())) ?? []).sorted { $0.coordinate < $1.coordinate }
        guard !allPeriods.isEmpty else { return }

        var earliestTouched: Period?
        for period in allPeriods {
            let toDelete = (period.lineItems ?? []).filter { matching($0) && !$0.isManuallyEdited }
            guard !toDelete.isEmpty else { continue }
            for line in toDelete {
                period.lineItems?.removeAll { $0.id == line.id }
                context.delete(line)
            }
            if earliestTouched == nil { earliestTouched = period }
        }

        try? context.save()
        if let earliestTouched {
            recomputeForward(after: earliestTouched, context: context, exchangeRate: exchangeRate)
            try? context.save()
        }
    }

    /// Sweeps every materialized `Period` for `LineItem`s whose generating `RecurringItem`/
    /// `Loan` no longer exists at all — garbage left behind by `context.delete` calls made
    /// before this fix existed (or any future bypass of `deleteRecurring`/`deleteLoan`). Call
    /// once at app launch (`materializeIfNeeded` also purges per-`Period`, on every open, so
    /// this whole-store sweep is a belt-and-suspenders catch-all, not the only line of
    /// defense). Unlike `purgeLines`, this ignores `isManuallyEdited`: if the source is truly
    /// gone, a manual edit on its line can never be reconciled by anything again, so keeping
    /// it around only accumulates more untouchable garbage.
    public static func purgeOrphanLines(context: ModelContext, exchangeRate: Decimal) {
        let allPeriods = ((try? context.fetch(FetchDescriptor<Period>())) ?? []).sorted { $0.coordinate < $1.coordinate }
        for period in allPeriods {
            purgeOrphanLines(in: period, context: context, exchangeRate: exchangeRate)
        }
    }

    /// Per-`Period` version of the same sweep — cheap enough to run every time a `Period` is
    /// opened (`materializeIfNeeded`'s existing-period paths), rather than scanning the whole
    /// store on every navigation.
    private static func purgeOrphanLines(in period: Period, context: ModelContext, exchangeRate: Decimal) {
        let existingRecurringIDs = Set(((try? context.fetch(FetchDescriptor<RecurringItem>())) ?? []).map(\.id))
        let existingLoanIDs = Set(((try? context.fetch(FetchDescriptor<Loan>())) ?? []).map(\.id))

        let orphans = (period.lineItems ?? []).filter { line in
            if let sourceID = line.sourceRecurringID { return !existingRecurringIDs.contains(sourceID) }
            if let loanID = line.sourceLoanID { return !existingLoanIDs.contains(loanID) }
            return false
        }
        guard !orphans.isEmpty else { return }

        for orphan in orphans {
            period.lineItems?.removeAll { $0.id == orphan.id }
            context.delete(orphan)
        }
        try? context.save()
        recomputeForward(after: period, context: context, exchangeRate: exchangeRate)
        try? context.save()
    }

    // MARK: - Overview (in-memory projection, never persists)

    /// INCOME/EXPENSES/sobrante for `coordinate` without materializing anything. Uses the
    /// real materialized `Period` when one already exists; otherwise simulates the
    /// carry-over chain in memory starting from the latest materialized period at/before
    /// `coordinate` (TRD: Overview and multi-year "what if" queries never write to the store).
    public static func projectedTotals(
        for coordinate: PeriodCoordinate,
        context: ModelContext,
        recurringItems: [RecurringItemSnapshot],
        subscriptions: [SubscriptionSnapshot],
        loans: [LoanSnapshot] = [],
        exchangeRate: Decimal
    ) -> (income: Decimal, expense: Decimal, sobrante: Decimal) {
        if let materialized = fetchPeriod(coordinate: coordinate, context: context) {
            let lines = snapshots(of: materialized)
            return (
                CarryOverEngine.total(for: lines, kind: .income, exchangeRate: exchangeRate),
                CarryOverEngine.total(for: lines, kind: .expense, exchangeRate: exchangeRate),
                CarryOverEngine.sobrante(for: lines, exchangeRate: exchangeRate)
            )
        }

        let allCoordinates = ((try? context.fetch(FetchDescriptor<Period>())) ?? []).map(\.coordinate)
        let base = allCoordinates.filter { $0 < coordinate }.max()

        var runningSobrante: Decimal = 0
        var cursor: PeriodCoordinate

        if let base, let basePeriod = fetchPeriod(coordinate: base, context: context) {
            runningSobrante = CarryOverEngine.sobrante(for: snapshots(of: basePeriod), exchangeRate: exchangeRate)
            cursor = base.next
        } else {
            cursor = coordinate
        }

        var income: Decimal = 0
        var expense: Decimal = 0

        while cursor <= coordinate {
            var lines = ProjectionEngine.generateRecurringLines(for: cursor, recurringItems: recurringItems)
                .map { LineSnapshot(kind: $0.kind, amount: $0.amount, currency: $0.currency, origin: $0.origin) }
            for kind in [SubscriptionKind.subscription, .service] {
                if let generated = ProjectionEngine.generateSubscriptionLine(for: cursor, subscriptions: subscriptions, kind: kind, exchangeRate: exchangeRate) {
                    lines.append(LineSnapshot(kind: generated.kind, amount: generated.amount, currency: generated.currency, origin: generated.origin))
                }
            }
            for generated in ProjectionEngine.generateLoanLines(for: cursor, loans: loans) {
                lines.append(LineSnapshot(kind: generated.kind, amount: generated.amount, currency: generated.currency, origin: generated.origin))
            }
            lines.append(LineSnapshot(kind: .income, amount: runningSobrante, currency: .usd, origin: .carryOver))

            income = CarryOverEngine.total(for: lines, kind: .income, exchangeRate: exchangeRate)
            expense = CarryOverEngine.total(for: lines, kind: .expense, exchangeRate: exchangeRate)
            runningSobrante = CarryOverEngine.sobrante(for: lines, exchangeRate: exchangeRate)
            cursor = cursor.next
        }

        return (income, expense, runningSobrante)
    }

    // MARK: - Manual line validation

    /// A manual line is only worth persisting if it has a real description and a positive
    /// amount — gates the "Agregar ingreso/gasto" capture flow so confirming (or abandoning)
    /// an empty draft never leaves a $0.00, no-description ghost row behind.
    public static func isValidManualLine(title: String, amount: Decimal) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0
    }

    // MARK: - Helpers

    public static func snapshots(of period: Period) -> [LineSnapshot] {
        (period.lineItems ?? [])
            .map { LineSnapshot(kind: $0.kind, amount: $0.amount, currency: $0.currency, origin: $0.origin) }
    }

    /// Idempotency belt (Avie): `reprojectRecurring`/`reprojectSubscription`/`reprojectLoan`
    /// must be safe to call more than once (or concurrently) for the same source without ever
    /// leaving two `LineItem`s for it in the same `Period`. Keeps the first (lowest
    /// `sortOrder`) match and deletes the rest before the create/update/remove decision runs.
    private static func dedupeLines(in period: Period, context: ModelContext, matching: (LineItem) -> Bool) {
        let matches = (period.lineItems ?? []).filter(matching).sorted { $0.sortOrder < $1.sortOrder }
        guard matches.count > 1 else { return }
        for duplicate in matches.dropFirst() {
            period.lineItems?.removeAll { $0.id == duplicate.id }
            context.delete(duplicate)
        }
    }
}
