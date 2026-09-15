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
    @State private var editingLineID: UUID?
    /// Tracks a line created via "Agregar ingreso/gasto" that hasn't been confirmed yet
    /// (Bertrand's ghost-row bug fix — see `LineItemRow.isDraft`).
    @State private var draftLineID: UUID?
    @State private var showJumpSheet = false
    @State private var showRateEditor = false
    @State private var manualRateText = ""
    @State private var isLoading = true
    @State private var rateEditorErrorMessage: String?

    // HIG_REVIEW #5 (Larry): the leading/trailing swipe gestures on a line have no visual
    // hint before the first drag — shown exactly once, ever, then persisted dismissed so it
    // never nags a returning user.
    @AppStorage("fintrol.hasSeenSwipeHint") private var hasSeenSwipeHint = false

    // A11Y #11: at accessibility Dynamic Type sizes, the badge/panel need to stack instead
    // of sitting side by side (macOS) so nothing gets clipped or squeezed unreadably.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var isLargeAccessibilitySize: Bool { dynamicTypeSize >= .accessibility1 }

    private var todayCoordinate: PeriodCoordinate { PeriodDateEngine.coordinate(containing: CivilDate.today()) }

    private var effectiveRate: Decimal {
        period?.manualExchangeRateOverride ?? rateStore.currentRate ?? 0
    }

    private var earliestCoordinate: PeriodCoordinate {
        PeriodCoordinator.earliestMaterializedCoordinate(context: context) ?? coordinate
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
        .sheet(isPresented: $showRateEditor) {
            rateEditorSheet
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
                Image(systemName: "chevron.left")
            }
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
                        Text(coordinate.dayRangeTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fecha: \(coordinate.accessibleTitle)")
                .accessibilityHint("Toca para saltar a otra quincena")

                if coordinate == todayCoordinate {
                    Text("Hoy")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                        .accessibilityHidden(true)
                } else if coordinate > todayCoordinate {
                    Text("Proyección")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(.secondary.opacity(0.15)))
                        .accessibilityHidden(true)
                }
            }

            Spacer()

            Button {
                coordinate = coordinate.next
                loadPeriod()
            } label: {
                Image(systemName: "chevron.right")
            }
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

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.headline)
                    .tracking(0.5)
                    .textCase(.uppercase)
                Spacer()
            }
            .accessibilityHidden(true) // the block's own accessibilityLabel below covers this

            VStack(spacing: 0) {
                // FALLBACK (documented in the approved plan): a `List` here — the only way to
                // get native `.swipeActions` — was tried first but blocks touches to
                // `captureRow` below it even at zero rows/`.fixedSize(vertical:)` (confirmed
                // empirically in the simulator: "Agregar ingreso" stopped responding at all).
                // `LineItemRow` implements its own leading/trailing swipe via `DragGesture`
                // instead (see that file) — full-swipe-only (no partial reveal-then-tap
                // state): leading commits Activar/Desactivar, trailing commits Marcar/
                // Desmarcar pagado. Eliminar/Editar stay reachable via `.contextMenu` (long
                // press) and `accessibilityActions`, both already gesture-independent.
                ForEach(lines) { line in
                    LineItemRow(
                        line: line,
                        exchangeRate: effectiveRate,
                        isEditing: editingLineID == line.id,
                        isDraft: draftLineID == line.id,
                        onStartEditing: { editingLineID = line.id },
                        onCommit: { commitEdit() },
                        onDelete: line.origin == .manual ? { deleteLine(line) } : nil,
                        onDiscardDraft: draftLineID == line.id ? { discardDraft() } : nil,
                        onToggleActive: { toggleActive(line) },
                        onTogglePaid: { togglePaid(line) }
                    )
                    if line.id != lines.last?.id {
                        Divider()
                    }
                }

                captureRow(kind: kind)
            }

            Divider().frame(height: 2).overlay(Color.secondary)

            HStack {
                Text(kind == .income ? "TOTAL INCOME" : "TOTAL EXPENSES")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text(total(for: kind).currencyString())
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.5))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(kind == .income ? "Ingresos" : "Gastos")
    }

    private func captureRow(kind: LineKind) -> some View {
        Button {
            addLine(kind: kind)
        } label: {
            HStack {
                Image(systemName: "plus.circle")
                Text(kind == .income ? "Agregar ingreso" : "Agregar gasto")
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind == .income ? "Agregar ingreso" : "Agregar gasto")
    }

    private var summaryPanel: some View {
        SummaryPanel(
            mandar: mandar,
            exchangeRate: rateStore.currentRate == nil ? period?.manualExchangeRateOverride : effectiveRate,
            isRateStale: rateStore.isUsingCache,
            nextMonth: nextMonth,
            onEditRate: {
                manualRateText = effectiveRate > 0 ? effectiveRate.twoDecimalString : ""
                rateEditorErrorMessage = nil
                showRateEditor = true
            }
        )
    }

    private var rateEditorSheet: some View {
        NavigationStack {
            Form {
                LabTextField(placeholder: "Tipo de cambio USD→MXN", text: $manualRateText, config: PatternConfig(accentColor: .accentColor))
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Text("Este override aplica solo a esta quincena.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let rateEditorErrorMessage {
                    Text(rateEditorErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Tipo de cambio")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showRateEditor = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        // M-01: same plausibility rule as the global override in Ajustes —
                        // this per-quincena field feeds the exact same Sobrante calculation.
                        guard let value = Decimal(string: manualRateText, locale: Locale(identifier: "en_US_POSIX")),
                              ExchangeRateParser.plausibleRange.contains(value) else {
                            rateEditorErrorMessage = "El tipo de cambio debe estar entre \(ExchangeRateParser.plausibleRange.lowerBound) y \(ExchangeRateParser.plausibleRange.upperBound)."
                            return
                        }
                        period?.manualExchangeRateOverride = value
                        commitEdit()
                        rateEditorErrorMessage = nil
                        showRateEditor = false
                    }
                }
            }
        }
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

    private func addLine(kind: LineKind) {
        guard let period else { return }
        let nextOrder = ((period.lineItems ?? []).map(\.sortOrder).max() ?? -1) + 1
        let line = LineItem(kind: kind, title: "", amount: 0, currency: .usd, sortOrder: nextOrder, origin: .manual, period: period)
        context.insert(line)
        period.lineItems?.append(line)
        editingLineID = line.id
        draftLineID = line.id
    }

    private func deleteLine(_ line: LineItem) {
        guard let period else { return }
        period.lineItems?.removeAll { $0.id == line.id }
        context.delete(line)
        commitEdit()
    }

    /// Discards a not-yet-confirmed draft line entirely — the capture row returns to its
    /// initial state without leaving a $0.00, no-description ghost row behind.
    private func discardDraft() {
        defer {
            editingLineID = nil
            draftLineID = nil
        }
        guard let draftLineID, let period,
              let line = (period.lineItems ?? []).first(where: { $0.id == draftLineID }) else { return }
        period.lineItems?.removeAll { $0.id == draftLineID }
        context.delete(line)
        try? context.save()
    }

    /// Swipe-leading (DESIGN_LIQUID.md): toggles `isActive`, which affects every total —
    /// needs the same persist-then-`recomputeForward` sequence as any other edit. Counts as a
    /// manual edit on non-manual lines so `reproject*` never silently reactivates it later.
    private func toggleActive(_ line: LineItem) {
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
        if line.origin != .manual { line.isManuallyEdited = true }
        try? context.save()
    }

    private func commitEdit() {
        if editingLineID == draftLineID {
            draftLineID = nil
        }
        editingLineID = nil
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
