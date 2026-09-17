import SwiftUI
import SwiftData
import AppleAppLabUI

struct PeriodView: View {
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore

    @Query(sort: \RecurringItem.title) private var recurringItems: [RecurringItem]
    @Query(sort: \Subscription.name) private var subscriptions: [Subscription]
    @Query(sort: \Loan.name) private var loans: [Loan]

    @State private var coordinate = PeriodDateEngine.coordinate(containing: CivilDate.today())
    @State private var period: Period?
    /// Coordinator (2026-09-15, DESIGN_LIQUID.md § "Sheet de captura/edición de línea"):
    /// replaces `editingLineID`/`draftLineID` + the inline-editing row entirely. `nil` while
    /// closed; a non-nil `line` means editing that existing `LineItem`; a nil `line` with a
    /// `kind` means creating a new one (no draft `LineItem` exists until "Listo" is tapped —
    /// this removes the old ghost-row problem at the source instead of working around it).
    @State private var captureTarget: CaptureTarget?
    private struct CaptureTarget: Identifiable {
        let id = UUID()
        let line: LineItem?
        let kind: LineKind
    }
    @State private var showJumpSheet = false
    @State private var isLoading = true

    // HIG_REVIEW #5 (Larry): the leading/trailing swipe gestures on a line have no visual
    // hint before the first drag — shown exactly once, ever, then persisted dismissed so it
    // never nags a returning user.
    @AppStorage("fintrol.hasSeenSwipeHint") private var hasSeenSwipeHint = false

    // TRD "Límite de navegación hacia atrás" (2026-09-16): Ajustes → Preferencias → "Historial
    // visible" — the `@AppStorage` read stays here (Core/ never touches it directly, only
    // receives the resolved `Int` as a parameter, same separation as every other
    // preference-driven Core call).
    @AppStorage("fintrol.historyMonthsBack") private var historyMonthsBack = 1

    // A11Y #11: at accessibility Dynamic Type sizes, the badge/panel need to stack instead
    // of sitting side by side (macOS) so nothing gets clipped or squeezed unreadably.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var isLargeAccessibilitySize: Bool { dynamicTypeSize >= .accessibility1 }

    private var todayCoordinate: PeriodCoordinate { PeriodDateEngine.coordinate(containing: CivilDate.today()) }
    private var isTodayCoordinate: Bool { coordinate == todayCoordinate }

    private var effectiveRate: Decimal {
        period?.manualExchangeRateOverride ?? rateStore.currentRate ?? 0
    }

    private var earliestCoordinate: PeriodCoordinate {
        PeriodCoordinator.navigableLowerBound(context: context, monthsBack: historyMonthsBack)
    }

    private var recurringSnapshots: [RecurringItemSnapshot] {
        recurringItems.map {
            RecurringItemSnapshot(id: $0.id, kind: $0.kind, title: $0.title, amount: $0.amount, currency: $0.currency, frequency: $0.frequency, startDate: $0.civilStartDate, endDate: $0.civilEndDate, isActive: $0.isActive, category: $0.category)
        }
    }

    private var subscriptionSnapshots: [SubscriptionSnapshot] {
        subscriptions.map {
            SubscriptionSnapshot(id: $0.id, name: $0.name, price: $0.price, currency: $0.currency, paymentDay: $0.paymentDay, startDate: $0.civilStartDate, endDate: $0.civilEndDate, kind: $0.kind, isActive: $0.isActive)
        }
    }

    private var loanSnapshots: [LoanSnapshot] {
        loans.map {
            LoanSnapshot(id: $0.id, name: $0.name, direction: $0.direction, principal: $0.principal, currency: $0.currency, apr: $0.apr, startDate: $0.civilStartDate, termMonths: $0.termMonths, frequency: $0.frequency, paymentOverride: $0.paymentOverride, isActive: $0.isActive)
        }
    }

    var body: some View {
        Group {
            if isLoading {
                loadingSkeleton
            } else {
                content
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarContent }
        .task {
            await rateStore.refresh(context: context)
            loadPeriod()
            isLoading = false
        }
        .onAppear {
            // Bug (Avie): `period` is a one-shot `@State` snapshot loaded only from `.task`
            // (which runs once per view identity) — editing a RecurringItem/Subscription/Loan
            // from another tab calls `reproject…`, which *does* persist the new lines, but
            // this view never re-fetched them until the app relaunched. `.task` doesn't refire
            // on tab reselection, so `.onAppear` (which does) refetches every time the user
            // comes back to Quincena. Cheap and idempotent — `loadPeriod()` just re-reads the
            // already-materialized `Period` when nothing changed.
            guard !isLoading else { return }
            loadPeriod()
        }
        .sheet(isPresented: $showJumpSheet) {
            JumpSheet(current: coordinate, earliest: earliestCoordinate) { destination in
                coordinate = destination
                loadPeriod()
            } onToday: {
                coordinate = todayCoordinate
                loadPeriod()
            }
        }
        .sheet(item: $captureTarget) { target in
            LineCaptureSheet(editingLine: target.line, kind: target.kind) { title, amount, currency in
                saveLine(target.line, kind: target.kind, title: title, amount: amount, currency: currency)
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                if isLargeAccessibilitySize {
                    VStack(spacing: 24) {
                        blocks
                        SobranteBadge(sobrante: sobrante)
                        summaryPanel
                    }
                } else {
                    #if os(macOS)
                    HStack(alignment: .top, spacing: 20) {
                        VStack(spacing: 24) {
                            blocks
                            SobranteBadge(sobrante: sobrante)
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Columna de ingresos y gastos")

                        summaryPanel
                            .frame(width: 280)
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel("Columna de resumen")
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Diseño de dos columnas")
                    #else
                    blocks
                    SobranteBadge(sobrante: sobrante)
                    summaryPanel
                    #endif
                }
            }
            .padding(16)
        }
    }

    private var blocks: some View {
        VStack(spacing: 24) {
            if !hasSeenSwipeHint {
                swipeDiscoverabilityHint
            }
            lineBlock(title: "INCOME", kind: .income)
            lineBlock(title: "EXPENSES", kind: .expense)
        }
    }

    private var swipeDiscoverabilityHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.draw")
                .foregroundStyle(Color.accentColor)
            Text("Desliza una línea: hacia la derecha para activar/desactivar, hacia la izquierda para marcarla pagada (y de nuevo para eliminar/editar).")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button {
                hasSeenSwipeHint = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cerrar aviso")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.accentColor.opacity(0.1)))
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack {
            Button {
                coordinate = coordinate.previous
                loadPeriod()
            } label: {
                // Coordinator (2026-09-16): system Liquid Glass paints the button now — plain
                // `chevron.backward` (no `.circle.fill`), no manual tint. `.glass` (not
                // `.glassProminent`): this side has no "active" accent state, and the
                // historical-limit disabled look comes from native `.disabled(true)`, not a
                // hand-picked gray.
                Image(systemName: "chevron.backward")
                    .frame(width: 29, height: 29)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Quincena anterior")
            .disabled(coordinate <= earliestCoordinate)

            Spacer()

            VStack(spacing: 2) {
                Button {
                    showJumpSheet = true
                } label: {
                    VStack(spacing: 2) {
                        Text(coordinate.monthYearTitle)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)
                        // Coordinator (2026-09-16, DESIGN_LIQUID.md, Jonny): the separate
                        // "Current"/"Proyección" badge is gone — this day-range pill is now
                        // the ONLY indicator. Today's period → solid green pill, white bold
                        // text (same green as the positive sobrante). Anything else (past OR
                        // future, no distinction) → transparent background, subtle border,
                        // `.secondary` text, no extra label.
                        Text(coordinate.dayRangeTitle)
                            .font(.subheadline.weight(isTodayCoordinate ? .bold : .regular))
                            .foregroundStyle(isTodayCoordinate ? .white : .secondary)
                            .padding(.horizontal, 10).padding(.vertical, 3)
                            .background(
                                Capsule().fill(isTodayCoordinate ? Color.green : Color.clear)
                            )
                            .overlay(
                                Capsule().strokeBorder(isTodayCoordinate ? Color.clear : Color.secondary.opacity(0.3))
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fecha: \(coordinate.accessibleTitle)\(isTodayCoordinate ? ", quincena actual" : "")")
                .accessibilityHint("Toca para saltar a otra quincena")
            }

            Spacer()

            Button {
                coordinate = coordinate.next
                loadPeriod()
            } label: {
                // Plain `chevron.forward` — system Liquid Glass paints the button.
                // Coordinator (2026-09-16): neutral `.glass` like "atrás" and "+" — the user
                // wants no solid accent fill here, `.glassProminent` was reverted.
                Image(systemName: "chevron.forward")
                    .frame(width: 29, height: 29)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Quincena siguiente")
        }
        .padding(.horizontal, 4)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) { EmptyView() }
    }

    private func lineBlock(title: String, kind: LineKind) -> some View {
        let lines = (period?.lineItems ?? [])
            .filter { $0.kind == kind }
            .sorted { $0.sortOrder < $1.sortOrder }

        // Coordinator (2026-09-15): "INCOME"/"EXPENSES" move out of the card entirely — a
        // grouped-list-style section header sitting above it (iOS grouped table convention:
        // caption/footnote, uppercase, secondary, left-aligned with the card's own padding,
        // ~8pt gap), not a title inside the card. The card itself now starts directly with
        // the rows. `accessibilityHidden` stays on the header text — the card's own
        // `.accessibilityLabel` below still announces "Ingresos"/"Gastos" for VoiceOver, so
        // this is not a regression, just moved with the rest of the visual.
        return VStack(alignment: .leading, spacing: 8) {
            // Coordinator (2026-09-16, DESIGN_LIQUID.md § Bloques INCOME/EXPENSES, Jonny):
            // the "+" moves OFF the section header (title-only now, no trailing icon) to its
            // own left-aligned spot below the last line card, above TOTAL INCOME/EXPENSES —
            // see `card(title:kind:lines:)` below for where it actually sits.
            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
                .padding(.horizontal, 16)

            card(title: title, kind: kind, lines: lines)
        }
    }

    // DESIGN_LIQUID.md § "Bloques INCOME/EXPENSES" (Figma, updated 2026-09-15 — supersedes
    // the single-card-with-dividers layout): each line is its own card now (see
    // `LineItemRow`), stacked with an 8pt gap, no `Divider()` between them — the gap itself
    // is the separator. "⊕ Agregar ingreso/gasto" sits below the last card as plain
    // `.secondary` text directly on the background (no card of its own); tapping it turns the
    // capture into a new card of the same style via the normal editing-row path. TOTAL
    // INCOME/EXPENSES sits below that, also directly on the background, no card.
    private func card(title: String, kind: LineKind, lines: [LineItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(lines) { line in
                LineItemRow(
                    line: line,
                    exchangeRate: effectiveRate,
                    onStartEditing: { captureTarget = CaptureTarget(line: line, kind: kind) },
                    onDelete: line.origin == .manual ? { deleteLine(line) } : nil,
                    onQuickCommit: { commitQuickEdit() },
                    onToggleActive: { toggleActive(line) },
                    onTogglePaid: { togglePaid(line) }
                )
            }

            // Coordinator (2026-09-16): the "+" lives here now — its own left-aligned spot
            // below the last line card, above TOTAL INCOME/EXPENSES, not in the section
            // header anymore. Small circular button, same treatment in both blocks.
            Button {
                captureTarget = CaptureTarget(line: nil, kind: kind)
            } label: {
                // Icon unchanged from before this move (`plus.capsule.fill`, confirmed
                // present in this SDK) — only its position changed this pass.
                Image(systemName: "plus.capsule.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .accessibilityLabel(kind == .income ? "Agregar ingreso" : "Agregar gasto")

            HStack {
                Text(kind == .income ? "TOTAL INCOME" : "TOTAL EXPENSES")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Text(total(for: kind).currencyString())
                    .font(.system(size: 14, weight: .bold))
                    .monospacedDigit()
            }
            .padding(.top, 10)
            .padding(.horizontal, 10)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(kind == .income ? "Ingresos" : "Gastos")
    }

    // Coordinator (2026-09-15, Figma tSUzh4zfCpDPYT5A88otst node 8:2): the "Tipo de cambio"
    // row + "Editar" button are removed from the Quincena's Resumen entirely — the manual
    // override stays reachable from Ajustes → Preferencias → Tipo de cambio
    // (`ExchangeRateSettingsView`), which already has it. The per-quincena-only override this
    // sheet used to write (`period.manualExchangeRateOverride`) has no UI trigger left as a
    // result — accepted by the coordinator's instruction, not an oversight.
    private var summaryPanel: some View {
        SummaryPanel(mandar: mandar, nextMonth: nextMonth)
    }

    private var loadingSkeleton: some View {
        VStack(spacing: 24) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8).fill(.quaternary).frame(height: 44)
                    }
                }
                .padding()
                .redacted(reason: .placeholder)
            }
        }
        .padding(16)
        .accessibilityLabel("Cargando quincena")
    }

    // MARK: - Actions

    private func loadPeriod() {
        period = PeriodCoordinator.materializeIfNeeded(
            coordinate: coordinate,
            context: context,
            recurringItems: recurringSnapshots,
            subscriptions: subscriptionSnapshots,
            loans: loanSnapshots,
            exchangeRate: rateStore.currentRate ?? 0
        )
        try? context.save()
    }

    /// `LineCaptureSheet`'s `onSave` — `existingLine == nil` creates a brand-new manual
    /// `LineItem` (no draft ever touches the store until this point, which is what actually
    /// eliminates the old ghost-row bug instead of just papering over it with a discard path);
    /// non-nil edits that line in place. Either way, ends with the same persist +
    /// `recomputeForward` sequence as every other edit.
    private func saveLine(_ existingLine: LineItem?, kind: LineKind, title: String, amount: Decimal, currency: Currency) {
        guard let period else { return }
        if let existingLine {
            // "Bloqueo de líneas pagadas" (2026-09-16): a confirmed-paid line is frozen —
            // the sheet shouldn't reach this path for one (UI hides the entry point), but
            // guard here too since `saveLine` is the actual mutation point.
            guard PeriodCoordinator.canModify(line: existingLine) else { return }
            existingLine.title = title
            existingLine.amount = amount
            existingLine.currency = currency
            if existingLine.origin != .manual { existingLine.isManuallyEdited = true }
        } else {
            let nextOrder = ((period.lineItems ?? []).map(\.sortOrder).max() ?? -1) + 1
            let line = LineItem(kind: kind, title: title, amount: amount, currency: currency, sortOrder: nextOrder, origin: .manual, period: period)
            context.insert(line)
            period.lineItems?.append(line)
        }
        try? context.save()
        PeriodCoordinator.recomputeForward(after: period, context: context, exchangeRate: effectiveRate)
        try? context.save()
    }

    private func deleteLine(_ line: LineItem) {
        guard let period else { return }
        guard PeriodCoordinator.canModify(line: line) else { return }
        period.lineItems?.removeAll { $0.id == line.id }
        context.delete(line)
        try? context.save()
        PeriodCoordinator.recomputeForward(after: period, context: context, exchangeRate: effectiveRate)
        try? context.save()
    }

    /// Swipe-leading (DESIGN_LIQUID.md): toggles `isActive`, which affects every total —
    /// needs the same persist-then-`recomputeForward` sequence as any other edit. Counts as a
    /// manual edit on non-manual lines so `reproject*` never silently reactivates it later.
    private func toggleActive(_ line: LineItem) {
        guard PeriodCoordinator.canModify(line: line) else { return }
        line.isActive.toggle()
        if line.origin != .manual { line.isManuallyEdited = true }
        try? context.save()
        if let period {
            PeriodCoordinator.recomputeForward(after: period, context: context, exchangeRate: effectiveRate)
            try? context.save()
        }
    }

    /// Swipe-trailing's first action: purely visual, no recompute — but still counts as a
    /// manual edit so a later `reproject*` doesn't reset it (same reasoning as `toggleActive`).
    private func togglePaid(_ line: LineItem) {
        line.isPaid.toggle()
        // TRD "paidAt/progreso real de préstamos" (2026-09-16): the real confirmation date,
        // set only by this manual toggle — never derived from the period's own date.
        line.paidAt = line.isPaid ? CivilDate.today(calendar: .current) : nil
        if line.origin != .manual { line.isManuallyEdited = true }
        try? context.save()
    }

    /// The one direct in-place row mutation left (`LineItemRow`'s contextMenu "Cambiar a
    /// MXN/USD") — same persist + `recomputeForward` sequence as everything else.
    private func commitQuickEdit() {
        try? context.save()
        if let period {
            PeriodCoordinator.recomputeForward(after: period, context: context, exchangeRate: effectiveRate)
            try? context.save()
        }
    }

    private func total(for kind: LineKind) -> Decimal {
        CarryOverEngine.total(for: currentSnapshots, kind: kind, exchangeRate: effectiveRate)
    }

    private var currentSnapshots: [LineSnapshot] {
        period.map(PeriodCoordinator.snapshots(of:)) ?? []
    }

    private var sobrante: Decimal {
        CarryOverEngine.sobrante(for: currentSnapshots, exchangeRate: effectiveRate)
    }

    private var mandar: Decimal {
        CarryOverEngine.mandar(for: currentSnapshots, exchangeRate: effectiveRate)
    }

    private var nextMonth: Decimal {
        guard let period else { return 0 }
        return PeriodCoordinator.previewNextMonth(
            after: period,
            context: context,
            recurringItems: recurringSnapshots,
            subscriptions: subscriptionSnapshots,
            loans: loanSnapshots,
            exchangeRate: effectiveRate
        )
    }
}
