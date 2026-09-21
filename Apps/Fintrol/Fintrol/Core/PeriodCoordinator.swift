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

    /// TRD "Límite de navegación hacia atrás" (2026-09-16): the actual, combined floor the
    /// "atrás" chevron/jump sheet must respect — whichever of the two bounds is **closer to
    /// today** (i.e. more restrictive) wins: "Historial visible" (`monthsBack`, an Ajustes
    /// preference — passed in here as a plain `Int`, this function never reads `@AppStorage`
    /// itself, same separation as the rest of `Core/`) and the pre-existing "first
    /// materialized quincena" floor (there is no data before it, so the setting can never see
    /// further back than that regardless of how large `monthsBack` is). `PeriodCoordinate` is
    /// `Comparable` in chronological order, so the later (closer-to-today) of the two is
    /// simply `max`.
    public static func navigableLowerBound(context: ModelContext, monthsBack: Int) -> PeriodCoordinate {
        let historyLimit = PeriodDateEngine.monthsAgoCoordinate(from: CivilDate.today(calendar: .current), months: monthsBack)
        guard let materializedFloor = earliestMaterializedCoordinate(context: context) else { return historyLimit }
        return max(historyLimit, materializedFloor)
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
            migrateLegacyCombinedSubscriptionLines(in: existing, context: context, exchangeRate: exchangeRate)
            purgeOrphanLines(in: existing, context: context, exchangeRate: exchangeRate)
            backfillMissingCarryOverLine(in: existing, context: context, exchangeRate: exchangeRate)
            reorderAggregateSubscriptionLines(in: existing)
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
                migrateLegacyCombinedSubscriptionLines(in: clamped, context: context, exchangeRate: exchangeRate)
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

    /// Coordinator (2026-09-21, user's request — Investments backfill): `materializeIfNeeded`'s
    /// `FIN-2026-BERTRAND-01` clamp exists to stop ordinary USER NAVIGATION from wandering
    /// further back than "Historial visible" allows; it was never meant to block an explicit,
    /// user-confirmed backfill ("¿Ya hiciste las N aportaciones anteriores?" → "Sí"). Materializing
    /// an Investment's schedule back to its own `startDate` needs to create real periods BEFORE
    /// whatever the user has already browsed to in Quincena, which `materializeIfNeeded` would
    /// otherwise silently clamp to the existing anchor (confirmed: it returned the SAME already-
    /// materialized period for every different past coordinate requested, so only one line ever
    /// actually got marked paid instead of each period's own). Same create-if-missing behavior,
    /// no anchor check. Callers materialize past coordinates in ascending (oldest → newest) order
    /// so each new period's own carry-over lookup finds its already-created predecessor.
    public static func forceMaterialize(
        coordinate: PeriodCoordinate,
        context: ModelContext,
        recurringItems: [RecurringItemSnapshot],
        subscriptions: [SubscriptionSnapshot],
        loans: [LoanSnapshot] = [],
        exchangeRate: Decimal
    ) -> Period {
        if let existing = fetchPeriod(coordinate: coordinate, context: context) {
            migrateLegacyCombinedSubscriptionLines(in: existing, context: context, exchangeRate: exchangeRate)
            purgeOrphanLines(in: existing, context: context, exchangeRate: exchangeRate)
            backfillMissingCarryOverLine(in: existing, context: context, exchangeRate: exchangeRate)
            reorderAggregateSubscriptionLines(in: existing)
            return existing
        }
        return createPeriod(coordinate, context: context, recurringItems: recurringItems, subscriptions: subscriptions, loans: loans, exchangeRate: exchangeRate)
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

        // Coordinator (2026-09-21): one real line per contributing subscription, grouped
        // Essentials → Subscriptions → Services (the block order `reorderAggregateSubscriptionLines`
        // also enforces going forward) — not one combined sum per kind.
        for kind in [SubscriptionKind.essential, .subscription, .service] {
            for subscription in subscriptions where subscription.kind == kind {
                if let generated = ProjectionEngine.generatedLine(for: coordinate, subscription: subscription, exchangeRate: exchangeRate) {
                    let line = LineItem(
                        kind: generated.kind, title: generated.title, amount: generated.amount,
                        currency: generated.currency, sortOrder: order, origin: generated.origin,
                        sourceSubscriptionID: generated.sourceSubscriptionID, isHomeService: generated.isHomeService, period: period
                    )
                    context.insert(line)
                    lines.append(line)
                    order += 1
                }
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

        // `.revolving` loans (per-loan, since each needs its own actualPayments calendar).
        for loan in loans where loan.isActive && loan.mode == .revolving {
            let actualPayments = revolvingActualPayments(for: loan, context: context)
            if let generated = ProjectionEngine.generateRevolvingLoanLine(for: coordinate, loan: loan, actualPayments: actualPayments) {
                let line = LineItem(
                    kind: generated.kind, title: generated.title, amount: generated.amount, currency: generated.currency,
                    sortOrder: order, origin: generated.origin, sourceLoanID: generated.sourceLoanID,
                    exchangeRateSnapshot: generated.currency == .mxn ? exchangeRate : nil,
                    period: period
                )
                context.insert(line)
                lines.append(line)
                order += 1
            }
        }

        period.lineItems = lines
        return period
    }

    /// Builds the `[CivilDate: Decimal]` real-payment map `generateRevolvingLoanLine` needs
    /// for `loan`, by scanning every already-materialized `Period` for a manually-edited
    /// `LineItem` whose `sourceLoanID` matches, and pairing it with the installment date at
    /// that period's calendar index (`LoanEngine.revolvingInstallmentDate`). Only manually
    /// edited lines count as "real" — an untouched, still-projected `expectedPayment` line is
    /// not a real payment yet.
    private static func revolvingActualPayments(for loan: LoanSnapshot, context: ModelContext) -> [CivilDate: Decimal] {
        guard loan.mode == .revolving else { return [:] }
        let allPeriods = ((try? context.fetch(FetchDescriptor<Period>())) ?? []).sorted { $0.coordinate < $1.coordinate }
        return revolvingActualPayments(loanID: loan.id, expectedPayment: loan.expectedPayment ?? 0, frequency: loan.frequency, start: loan.startDate, allPeriods: allPeriods)
    }

    /// Core of the above — separated so `reprojectLoan` (which already has `allPeriods`
    /// fetched) can reuse it without a second fetch.
    private static func revolvingActualPayments(
        loanID: UUID, expectedPayment: Decimal, frequency: LoanFrequency, start: CivilDate, allPeriods: [Period]
    ) -> [CivilDate: Decimal] {
        var result: [CivilDate: Decimal] = [:]
        var index = 0
        // installmentDate index is monotonic with calendar date for both frequencies, so a
        // single forward walk in period order (ascending) keeps the index in lockstep with the
        // periods, without needing to search per line.
        for period in allPeriods {
            guard let line = (period.lineItems ?? []).first(where: { $0.sourceLoanID == loanID }) else { continue }
            index += 1
            guard line.isManuallyEdited else { continue }
            let date = LoanEngine.revolvingInstallmentDate(index: index, start: start, frequency: frequency)
            result[date] = line.amount
        }
        return result
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
                .map { LineSnapshot(kind: $0.kind, amount: $0.amount, currency: $0.currency, origin: $0.origin, isActive: $0.isActive) }
            chain.append(CarryOverEngine.ChainEntry(coordinate: cursor, nonCarryOverLines: nonCarryOver, previousCarryOverReceived: carryAmount))
            chainPeriods[cursor] = next
            cursor = cursor.next
        }

        let updates = CarryOverEngine.recomputeForward(materializedChain: chain, startingSobrante: newSobrante, exchangeRate: exchangeRate)
        for (coordinate, newAmount) in updates {
            guard let targetPeriod = chainPeriods[coordinate] else { continue }
            if let carryLine = (targetPeriod.lineItems ?? []).first(where: { $0.origin == .carryOver }) {
                carryLine.amount = newAmount
            } else {
                // Bug fix (2026-09-21, user report — real account had no "Latest Month" line
                // despite a real surplus): `createPeriod` only inserts a carry-over line at THE
                // MOMENT a period is first materialized, and only if its `previous` period
                // already existed then. If materialization order ever skips ahead (ex: the
                // period the user opens first becomes an anchor before its own previous period
                // is created), that period permanently has no carry-over `LineItem` — this loop
                // used to silently no-op forever afterward instead of creating one now that the
                // chain (and a real amount to carry) exists. Mirrors `createPeriod`'s own
                // carry-line construction; sorted first, same as at normal creation time.
                let minSortOrder = (targetPeriod.lineItems ?? []).map(\.sortOrder).min() ?? 0
                let carryLine = LineItem(
                    kind: .income, title: "Latest Month", amount: newAmount, currency: .usd,
                    sortOrder: minSortOrder - 1, origin: .carryOver, period: targetPeriod
                )
                context.insert(carryLine)
                targetPeriod.lineItems = (targetPeriod.lineItems ?? []) + [carryLine]
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
        for kind in [SubscriptionKind.essential, .subscription, .service] {
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
            frequency: item.frequency, startDate: item.civilStartDate, endDate: item.civilEndDate, isActive: item.isActive,
            category: item.category
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

    /// Coordinator (2026-09-21, user's request — "si elimino/edito 'Food' aquí, solo debe
    /// afectar esta quincena, la definición se queda"): clone of `reprojectCreditCard`/
    /// `reprojectLoan` — one real line PER `Subscription`, keyed by `sourceSubscriptionID`,
    /// not a combined sum. Editing/deactivating that line in one quincena (`isManuallyEdited`/
    /// `isActive`) never touches another quincena or the `Subscription` itself; a true
    /// permanent removal still goes through `deleteSubscription`. Supersedes the old
    /// kind-wide "one combined line" reproject.
    public static func reprojectSubscription(item: Subscription, context: ModelContext, exchangeRate: Decimal) {
        let snapshot = SubscriptionSnapshot(
            id: item.id, name: item.name, price: item.price, currency: item.currency, paymentDay: item.paymentDay,
            startDate: item.civilStartDate, endDate: item.civilEndDate, kind: item.kind, isActive: item.isActive, isBiweekly: item.isBiweekly
        )
        let allPeriods = ((try? context.fetch(FetchDescriptor<Period>())) ?? []).sorted { $0.coordinate < $1.coordinate }
        guard !allPeriods.isEmpty else { return }

        var earliestTouched: Period?

        for period in allPeriods {
            dedupeLines(in: period, context: context, matching: { $0.sourceSubscriptionID == item.id })
            let existingLine = (period.lineItems ?? []).first { $0.sourceSubscriptionID == item.id }
            let generated = ProjectionEngine.generatedLine(for: period.coordinate, subscription: snapshot, exchangeRate: exchangeRate)

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
                    sortOrder: nextOrder, origin: generated.origin, sourceSubscriptionID: generated.sourceSubscriptionID,
                    isHomeService: generated.isHomeService, period: period
                )
                context.insert(newLine)
                period.lineItems?.append(newLine)
                if earliestTouched == nil { earliestTouched = period }
            }

            // Coordinator (2026-09-21, user's request): Essentials, Subscriptions, Services, in
            // that relative order — runs for EVERY period on every reproject (not just the ones
            // this call touched), so it also self-heals periods materialized before this
            // ordering existed, without needing a data migration.
            reorderAggregateSubscriptionLines(in: period)
        }

        try? context.save()
        if let earliestTouched {
            recomputeForward(after: earliestTouched, context: context, exchangeRate: exchangeRate)
            try? context.save()
        }
    }

    /// Bulk convenience over `reprojectSubscription(item:)` — every `Subscription` of `kind`,
    /// one at a time. Existing call sites (edit sheets pass a single item now, but a couple of
    /// bulk paths — JSON import, `deleteSubscription`'s sibling cleanup — still think in terms
    /// of "this kind changed").
    public static func reprojectSubscription(kind: SubscriptionKind, context: ModelContext, exchangeRate: Decimal) {
        let items = ((try? context.fetch(FetchDescriptor<Subscription>())) ?? []).filter { $0.kind == kind }
        for item in items {
            reprojectSubscription(item: item, context: context, exchangeRate: exchangeRate)
        }
    }

    // MARK: - JSON import (Ajustes → "Importar suscripciones y servicios…")

    public struct SubscriptionImportSummary: Sendable {
        public let imported: Int
        public let updated: Int
        public let skipped: Int
    }

    /// Persists `items` (already validated by `SubscriptionImportService.parse`) as
    /// `Subscription` rows, deduped by `name` — an existing row with a matching name is
    /// updated in place, everything else is inserted new. `skippedCount` is the caller's
    /// `SubscriptionImportService.ParseResult.issues.count` (items that never made it this
    /// far); it's only threaded through so the UI can report one combined summary. Finishes
    /// with `reprojectSubscription(kind:)` for both kinds, exactly like any other
    /// create/edit/delete of a `Subscription`.
    @discardableResult
    public static func importSubscriptions(
        _ items: [SubscriptionImportService.ValidatedItem],
        context: ModelContext,
        exchangeRate: Decimal,
        skippedCount: Int = 0
    ) -> SubscriptionImportSummary {
        let existing = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        var byName: [String: Subscription] = Dictionary(existing.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

        var imported = 0
        var updated = 0

        // `SubscriptionImportService.mapSubscriptionCategory` still maps against the fixed
        // `SubscriptionCategory` enum (it's a pure, context-free `Core/Engine` type, same
        // convention as `ProjectionEngine`/`LoanEngine` — it can't touch SwiftData). Since
        // categories became user-editable (`SubscriptionCategoryItem`), an import can now name
        // a category the user has since renamed or deleted — ensure a matching row exists
        // here, where `context` is available, instead of leaving `categoryRaw` pointing at
        // nothing (which would only show a fallback icon, never break the import itself).
        let existingCategories = (try? context.fetch(FetchDescriptor<SubscriptionCategoryItem>())) ?? []
        var categoryNames = Set(existingCategories.map(\.name))
        var nextCategorySortOrder = (existingCategories.map(\.sortOrder).max() ?? -1) + 1
        func ensureCategoryExists(_ name: String) {
            guard !categoryNames.contains(name) else { return }
            context.insert(SubscriptionCategoryItem(name: name, iconName: "tag", sortOrder: nextCategorySortOrder))
            categoryNames.insert(name)
            nextCategorySortOrder += 1
        }

        for item in items {
            if item.kind == .subscription {
                ensureCategoryExists(item.subscriptionCategory.rawValue)
            }
            if let match = byName[item.name] {
                match.price = item.amount
                match.currency = item.currency
                match.paymentDay = item.payDay
                match.civilStartDate = item.startDate
                match.civilEndDate = item.endDate
                match.card = item.paymentMethod
                match.isActive = item.isActive
                match.kind = item.kind
                switch item.kind {
                case .subscription: match.category = item.subscriptionCategory
                case .service: match.homeServiceCategory = item.homeServiceCategory
                // JSON import (Ajustes → "Importar suscripciones y servicios…") only ever
                // parses `.subscription`/`.service` kinds — `SubscriptionImportService.parse`
                // has no `.essential` case in its schema, so this is structurally unreachable.
                case .essential: break
                }
                updated += 1
            } else {
                let created: Subscription
                switch item.kind {
                case .service:
                    created = Subscription(
                        name: item.name, price: item.amount, currency: item.currency, paymentDay: item.payDay,
                        startDate: item.startDate.date(calendar: .current), endDate: item.endDate?.date(calendar: .current),
                        homeServiceCategory: item.homeServiceCategory, isActive: item.isActive
                    )
                case .subscription:
                    created = Subscription(
                        name: item.name, price: item.amount, currency: item.currency, paymentDay: item.payDay,
                        startDate: item.startDate.date(calendar: .current), endDate: item.endDate?.date(calendar: .current),
                        card: item.paymentMethod, kind: .subscription, category: item.subscriptionCategory, isActive: item.isActive
                    )
                // Same as above — `.essential` never actually comes out of
                // `SubscriptionImportService.parse`, this only satisfies exhaustiveness.
                case .essential:
                    created = Subscription(
                        name: item.name, price: item.amount, currency: item.currency, paymentDay: item.payDay,
                        startDate: item.startDate.date(calendar: .current), endDate: item.endDate?.date(calendar: .current),
                        essentialCategory: .food, isActive: item.isActive
                    )
                }
                // `paymentMethod` (JSON) <-> `card` (model) applies to both kinds — the service
                // init above has no `card:` parameter (Services UI never shows one), so it's
                // set here uniformly for both branches instead of duplicating it per case.
                created.card = item.paymentMethod
                context.insert(created)
                byName[item.name] = created
                imported += 1
            }
        }

        try? context.save()
        reprojectSubscription(kind: .subscription, context: context, exchangeRate: exchangeRate)
        reprojectSubscription(kind: .service, context: context, exchangeRate: exchangeRate)

        return SubscriptionImportSummary(imported: imported, updated: updated, skipped: skippedCount)
    }

    /// Same bug, same fix, for `Loan` — symmetric to `reprojectRecurring`, keyed by
    /// `sourceLoanID` instead of `sourceRecurringID`. A period stops getting a line once it's
    /// past the loan's schedule (deactivated, term ended, or `paymentOverride` shortened it).
    public static func reprojectLoan(item: Loan, context: ModelContext, exchangeRate: Decimal) {
        let snapshot = LoanSnapshot(
            id: item.id, name: item.name, direction: item.direction, principal: item.principal,
            currency: item.currency, apr: item.apr, startDate: item.civilStartDate, termMonths: item.termMonths,
            frequency: item.frequency, paymentOverride: item.paymentOverride, isActive: item.isActive,
            mode: item.mode, expectedPayment: item.expectedPayment
        )
        let allPeriods = ((try? context.fetch(FetchDescriptor<Period>())) ?? []).sorted { $0.coordinate < $1.coordinate }
        guard !allPeriods.isEmpty else { return }

        // `.revolving` (TRD): "cualquier pago real registrado en cualquier quincena dispara un
        // recálculo completo hacia adelante" — computed once, from every currently-materialized
        // period's real (manually-edited) payment, then reused for every period below instead
        // of recomputing per period (which would be quadratic).
        let revolvingActuals: [CivilDate: Decimal] = {
            guard item.mode == .revolving, let expected = item.expectedPayment else { return [:] }
            return revolvingActualPayments(loanID: item.id, expectedPayment: expected, frequency: item.frequency, start: item.civilStartDate, allPeriods: allPeriods)
        }()

        var earliestTouched: Period?

        for period in allPeriods {
            dedupeLines(in: period, context: context, matching: { $0.sourceLoanID == item.id })
            let existingLine = (period.lineItems ?? []).first { $0.sourceLoanID == item.id }
            let generated: GeneratedLine? = snapshot.mode == .revolving
                ? ProjectionEngine.generateRevolvingLoanLine(for: period.coordinate, loan: snapshot, actualPayments: revolvingActuals)
                : ProjectionEngine.generateLoanLines(for: period.coordinate, loans: [snapshot]).first

            if let existingLine {
                guard !existingLine.isManuallyEdited else { continue }
                if let generated {
                    // Bug (coordinator, 2026-09-17): every OTHER field from `generated` was
                    // copied here except `kind` — editing a loan's `direction` after lines
                    // were already materialized left those existing lines on the old
                    // Income/Expense `kind` forever (only newly-generated future lines picked
                    // up the change). `direction` is the only editable field on `Loan` that
                    // can flip `kind` after creation — `RecurringItem`/`Subscription` have no
                    // equivalent (checked: `category` doesn't affect `kind`), so this fix is
                    // loan-specific.
                    existingLine.kind = generated.kind
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

    /// Clone of `reprojectLoan` (TRD "Credit Cards", 2026-09-17) — same pattern: find the
    /// existing line by `sourceCreditCardID`, respect `isManuallyEdited`, create/update/
    /// retire, finish with `recomputeForward`. The one real difference: a card's quincena
    /// isn't derived from a fixed frequency, it's derived from `cutoffDay`/`paymentDay` plus
    /// `dateRule` — a plain parameter, never read from `@AppStorage` inside `Core/` (same
    /// pattern as `navigableLowerBound(context:monthsBack:)`).
    public static func reprojectCreditCard(item: CreditCard, context: ModelContext, exchangeRate: Decimal, dateRule: CreditCardPaymentDateRule) {
        let snapshot = CreditCardSnapshot(
            id: item.id, name: item.name, balance: item.balance, apr: item.apr, creditLimit: item.creditLimit,
            cutoffDay: item.cutoffDay, paymentDay: item.paymentDay, expectedPayment: item.expectedPayment, isActive: item.isActive
        )
        let allPeriods = ((try? context.fetch(FetchDescriptor<Period>())) ?? []).sorted { $0.coordinate < $1.coordinate }
        guard !allPeriods.isEmpty else { return }

        var earliestTouched: Period?

        for period in allPeriods {
            dedupeLines(in: period, context: context, matching: { $0.sourceCreditCardID == item.id })
            let existingLine = (period.lineItems ?? []).first { $0.sourceCreditCardID == item.id }
            let realPayment = (existingLine?.isManuallyEdited ?? false) ? existingLine?.amount : nil
            let generated = CreditCardEngine.generatedLine(for: period.coordinate, card: snapshot, dateRule: dateRule, realPayment: realPayment)

            if let existingLine {
                guard !existingLine.isManuallyEdited else { continue }
                if let generated {
                    existingLine.kind = generated.kind
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
                    sortOrder: nextOrder, origin: generated.origin, sourceCreditCardID: generated.sourceCreditCardID,
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

    /// Same fix, for `CreditCard` (TRD "Credit Cards", 2026-09-17).
    public static func deleteCreditCard(_ item: CreditCard, context: ModelContext, exchangeRate: Decimal) {
        let id = item.id
        context.delete(item)
        try? context.save()
        purgeLines(context: context, exchangeRate: exchangeRate) { $0.sourceCreditCardID == id }
    }

    /// Same fix, for `Subscription` (2026-09-21, per-item refactor: now has real generated
    /// lines to orphan, exactly like Recurring/Loan/CreditCard). This is the PERMANENT delete
    /// — removes the recurring definition itself forever, everywhere. For "remove this one
    /// quincena only, keep the definition", deactivate that quincena's line instead
    /// (`LineItemRow`'s swipe/contextMenu "Desactivar") — manual-edit-wins still applies here
    /// too, so a hand-edited line survives this delete until the user removes it themselves.
    public static func deleteSubscription(_ item: Subscription, context: ModelContext, exchangeRate: Decimal) {
        let id = item.id
        context.delete(item)
        try? context.save()
        purgeLines(context: context, exchangeRate: exchangeRate) { $0.sourceSubscriptionID == id }
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
        // Coordinator (2026-09-17, "Credit Cards"): extended per the explicitly flagged risk —
        // without this, deleting a card leaves orphaned `LineItem`s that no `reproject*` ever
        // cleans up again (`purgeLines` inside `deleteCreditCard` handles the normal-deletion
        // path; this whole-store sweep is the belt-and-suspenders catch-all for anything that
        // bypassed it).
        let existingCreditCardIDs = Set(((try? context.fetch(FetchDescriptor<CreditCard>())) ?? []).map(\.id))
        // Coordinator (2026-09-21, per-item refactor): same belt-and-suspenders catch-all,
        // extended now that `Subscription` has real per-period lines to orphan too.
        let existingSubscriptionIDs = Set(((try? context.fetch(FetchDescriptor<Subscription>())) ?? []).map(\.id))

        let orphans = (period.lineItems ?? []).filter { line in
            if let sourceID = line.sourceRecurringID { return !existingRecurringIDs.contains(sourceID) }
            if let loanID = line.sourceLoanID { return !existingLoanIDs.contains(loanID) }
            if let cardID = line.sourceCreditCardID { return !existingCreditCardIDs.contains(cardID) }
            if let subscriptionID = line.sourceSubscriptionID { return !existingSubscriptionIDs.contains(subscriptionID) }
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

    /// Self-heal (2026-09-21, per-item refactor — user's request that editing/deleting "Food"
    /// only ever affects one quincena): periods materialized BEFORE this refactor still carry
    /// the old "one combined line per kind" `LineItem`s, which have no `sourceSubscriptionID`
    /// (every line created going forward always sets one) — that's how a legacy line is
    /// recognized here. Purges them unconditionally, `isManuallyEdited` included: same
    /// reasoning as `purgeOrphanLines`'s own doc comment — a manual edit made against a concept
    /// that no longer exists (one line standing in for many subscriptions) can never be
    /// reconciled into the new per-item model, so keeping it around only leaves a permanent,
    /// double-counted duplicate once the real per-item lines regenerate. Runs before
    /// `purgeOrphanLines` in `materializeIfNeeded` — every time a `Period` is opened, no
    /// one-time migration script needed.
    private static func migrateLegacyCombinedSubscriptionLines(in period: Period, context: ModelContext, exchangeRate: Decimal) {
        let legacyLines = (period.lineItems ?? []).filter {
            ($0.origin == .essential || $0.origin == .subscription) && $0.sourceSubscriptionID == nil
        }
        guard !legacyLines.isEmpty else { return }

        for line in legacyLines {
            period.lineItems?.removeAll { $0.id == line.id }
            context.delete(line)
        }
        try? context.save()

        reprojectSubscription(kind: .essential, context: context, exchangeRate: exchangeRate)
        reprojectSubscription(kind: .subscription, context: context, exchangeRate: exchangeRate)
        reprojectSubscription(kind: .service, context: context, exchangeRate: exchangeRate)
    }

    /// Bug fix (2026-09-21, user report — real account had no "Latest Month" line despite a
    /// real surplus the period before): `createPeriod` only inserts a carry-over `LineItem` at
    /// the moment `period` is first materialized, and only if its `previous` period already
    /// existed in the store then. If a period ever got created before its own previous period
    /// did (e.g. the user's first-ever open landed on it as the anchor), it permanently has no
    /// carry-over line, and `recomputeForward`'s per-edit walk could only UPDATE an existing
    /// line, never create the missing one — so it stayed broken forever, silently. Same cheap
    /// per-`Period` hook as `purgeOrphanLines(in:context:exchangeRate:)` above (every time a
    /// `Period` is opened), so a real amount backfills the next time the user visits it, no
    /// edit required.
    private static func backfillMissingCarryOverLine(in period: Period, context: ModelContext, exchangeRate: Decimal) {
        guard (period.lineItems ?? []).first(where: { $0.origin == .carryOver }) == nil else { return }
        guard let previous = fetchPeriod(coordinate: period.coordinate.previous, context: context) else { return }

        let sobrante = CarryOverEngine.sobrante(for: snapshots(of: previous), exchangeRate: exchangeRate)
        let minSortOrder = (period.lineItems ?? []).map(\.sortOrder).min() ?? 0
        let carryLine = LineItem(
            kind: .income, title: "Latest Month", amount: sobrante, currency: .usd,
            sortOrder: minSortOrder - 1, origin: .carryOver, period: period
        )
        context.insert(carryLine)
        period.lineItems = (period.lineItems ?? []) + [carryLine]
        try? context.save()
        recomputeForward(after: period, context: context, exchangeRate: exchangeRate)
        try? context.save()
    }

    /// Bug fix (2026-09-21, user's request): expense lines must group Essentials, then
    /// Subscriptions ("Payments"), then Services ("Servicios"), in that block order — whatever
    /// order they happened to be created/reprojected in. Coordinator (2026-09-21, per-item
    /// refactor): each group can now hold SEVERAL lines (one per `Subscription`, not one
    /// combined line) — sorts each group by its own existing `sortOrder` first so items keep
    /// their relative order within the group, then renumbers the three groups back-to-back
    /// starting at their current combined minimum. Cheap enough to run on every
    /// `materializeIfNeeded`/`reprojectSubscription` pass — self-heals every period
    /// automatically instead of needing a one-time migration.
    private static func reorderAggregateSubscriptionLines(in period: Period) {
        let lines = (period.lineItems ?? []).sorted { $0.sortOrder < $1.sortOrder }
        let essentials = lines.filter { $0.origin == .essential }
        let subscriptions = lines.filter { $0.origin == .subscription && !$0.isHomeService }
        let services = lines.filter { $0.origin == .subscription && $0.isHomeService }
        let ordered = essentials + subscriptions + services
        guard ordered.count > 1 else { return }

        let baseOrder = ordered.map(\.sortOrder).min() ?? 0
        for (offset, line) in ordered.enumerated() {
            line.sortOrder = baseOrder + offset
        }
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
            for kind in [SubscriptionKind.essential, .subscription, .service] {
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

    // MARK: - Línea bloqueada al pagar (TRD/DESIGN_LIQUID.md "bloqueo de líneas pagadas", 2026-09-16)

    /// Pure gate: once a line is confirmed paid (`isPaid == true`) it's frozen — no edit,
    /// delete, or activate/deactivate. `togglePaid` itself is the sole exempt action (it's how
    /// the user unlocks the line again), so it must never call this guard. Both `PeriodView`'s
    /// mutation methods and `LineItemRow`'s UI (swipe/contextMenu/accessibilityActions) read
    /// this single source of truth rather than re-checking `line.isPaid` ad hoc.
    public static func canModify(line: LineItem) -> Bool {
        !line.isPaid
    }

    // MARK: - Loan progress (TRD "paidAt/progreso real", 2026-09-16)

    /// The single source of truth for a loan's real paid-to-date amount — sum of `amount`
    /// across every materialized `LineItem` with `sourceLoanID == loanID && isPaid == true`,
    /// any period, past or future. Deliberately NOT derived from the amortization schedule by
    /// elapsed time (that was the old, wrong behavior this replaces): progress only advances
    /// when the user manually confirms a payment via the swipe toggle in `PeriodView`, never
    /// just because a scheduled date has passed. Both `LoanDetailView` and `LoansView`'s
    /// `LoanRow` call this instead of each computing their own version.
    public static func loanPaidToDate(loanID: UUID, context: ModelContext) -> Decimal {
        let periods = (try? context.fetch(FetchDescriptor<Period>())) ?? []
        return periods
            .flatMap { $0.lineItems ?? [] }
            .filter { $0.sourceLoanID == loanID && $0.isPaid }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// The most recently confirmed-paid `LineItem` for this loan (by `paidAt`), or `nil` if
    /// none are marked paid yet — single source both `loanLastPaymentDate` and
    /// `loanLastPaymentAmount` read from, so neither re-implements the same filter/sort.
    private static func lastPaidLine(loanID: UUID, context: ModelContext) -> LineItem? {
        let periods = (try? context.fetch(FetchDescriptor<Period>())) ?? []
        return periods
            .flatMap { $0.lineItems ?? [] }
            .filter { $0.sourceLoanID == loanID && $0.isPaid && $0.paidAt != nil }
            .max { $0.paidAt! < $1.paidAt! }
    }

    /// "Fecha del último pago" — the latest `paidAt` among that loan's `isPaid == true`
    /// lines, or `nil` if none are marked paid yet.
    public static func loanLastPaymentDate(loanID: UUID, context: ModelContext) -> CivilDate? {
        lastPaidLine(loanID: loanID, context: context)?.paidAt
    }

    /// "Último Pago $X" (LoansView, 2026-09-17, DESIGN_LIQUID.md § Préstamos lista) — the
    /// amount of that same most-recently-paid line, not the cumulative `loanPaidToDate`.
    public static func loanLastPaymentAmount(loanID: UUID, context: ModelContext) -> Decimal? {
        lastPaidLine(loanID: loanID, context: context)?.amount
    }

    // MARK: - Credit card progress (TRD "Credit Cards", 2026-09-17 — clones of the Loan versions)

    public static func creditCardPaidToDate(creditCardID: UUID, context: ModelContext) -> Decimal {
        let periods = (try? context.fetch(FetchDescriptor<Period>())) ?? []
        return periods
            .flatMap { $0.lineItems ?? [] }
            .filter { $0.sourceCreditCardID == creditCardID && $0.isPaid }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    private static func lastPaidCreditCardLine(creditCardID: UUID, context: ModelContext) -> LineItem? {
        let periods = (try? context.fetch(FetchDescriptor<Period>())) ?? []
        return periods
            .flatMap { $0.lineItems ?? [] }
            .filter { $0.sourceCreditCardID == creditCardID && $0.isPaid && $0.paidAt != nil }
            .max { $0.paidAt! < $1.paidAt! }
    }

    public static func creditCardLastPaymentDate(creditCardID: UUID, context: ModelContext) -> CivilDate? {
        lastPaidCreditCardLine(creditCardID: creditCardID, context: context)?.paidAt
    }

    public static func creditCardLastPaymentAmount(creditCardID: UUID, context: ModelContext) -> Decimal? {
        lastPaidCreditCardLine(creditCardID: creditCardID, context: context)?.amount
    }

    // MARK: - Home insight signals (feature "Home", 2026-09-17)

    /// Bridges live SwiftData into `HomeInsightContext` — the pure struct
    /// `HomeInsightEngine.message(for:)` consumes. Every derived number reuses an existing
    /// formula (`loanPaidToDate`, `CreditCardEngine.utilizationLevel`, `CarryOverEngine.
    /// sobrante`) rather than a second one; see `HomeInsightContext`'s doc comments for the
    /// two judgment calls (`hasOtherExpenseLines`, worst-card utilization) this makes.
    public static func homeInsightContext(
        for period: Period,
        loans: [Loan],
        creditCards: [CreditCard],
        context: ModelContext,
        exchangeRate: Decimal
    ) -> HomeInsightContext {
        let activeLines = (period.lineItems ?? []).filter(\.isActive)
        let pendingCount = activeLines.filter { $0.kind == .expense && $0.origin != .creditCard && !$0.isPaid }.count
        let creditCardsDueCount = activeLines.filter { $0.origin == .creditCard && !$0.isPaid }.count
        let otherExpenseLinesCount = activeLines.filter { $0.kind == .expense && $0.origin != .creditCard }.count

        let activeLoans = loans.filter(\.isActive)
        let activeCards = creditCards.filter(\.isActive)
        let hasAnyDebt = !activeLoans.isEmpty || !activeCards.isEmpty

        let range = PeriodDateEngine.dateRange(for: period.coordinate)
        let justPaidOffLoanName = loans.first { loan in
            guard !loan.isActive else { return false }
            guard let lastPaymentDate = loanLastPaymentDate(loanID: loan.id, context: context) else { return false }
            return lastPaymentDate >= range.start && lastPaymentDate <= range.end
        }?.name

        let loanProgressPercent: Int = {
            guard !activeLoans.isEmpty else { return 0 }
            let fractions = activeLoans.map { loan -> Double in
                guard loan.principal > 0 else { return 0 }
                let paid = loanPaidToDate(loanID: loan.id, context: context)
                let fraction = paid / loan.principal
                return max(0, min(1, Double(truncating: fraction as NSDecimalNumber)))
            }
            let average = fractions.reduce(0, +) / Double(fractions.count)
            return Int((average * 100).rounded())
        }()

        let creditUtilizationLevel: CreditCardEngine.UtilizationLevel = {
            let levels = activeCards.filter { $0.balance > 0 }.map {
                CreditCardEngine.utilizationLevel(balance: $0.balance, creditLimit: $0.creditLimit)
            }
            if levels.contains(.high) { return .high }
            if levels.contains(.medium) { return .medium }
            return .low
        }()

        let surplus = CarryOverEngine.sobrante(for: snapshots(of: period), exchangeRate: exchangeRate)

        return HomeInsightContext(
            pendingCount: pendingCount,
            creditCardsDueCount: creditCardsDueCount,
            hasAnyDebt: hasAnyDebt,
            hasOtherExpenseLines: otherExpenseLinesCount > 0,
            justPaidOffLoanName: justPaidOffLoanName,
            loanProgressPercent: loanProgressPercent,
            creditUtilizationLevel: creditUtilizationLevel,
            surplus: surplus
        )
    }

    // MARK: - Helpers

    public static func snapshots(of period: Period) -> [LineSnapshot] {
        (period.lineItems ?? [])
            .map { LineSnapshot(kind: $0.kind, amount: $0.amount, currency: $0.currency, origin: $0.origin, isActive: $0.isActive) }
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
