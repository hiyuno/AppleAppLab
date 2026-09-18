import SwiftUI
import SwiftData
import AppleAppLabUI

/// "Préstamos" — fifth entry of the "Recurrentes y pagos" hub (DESIGN_LIQUID.md). Explicitly
/// not credit cards (Fase 2 del PRD): a loan has a fixed term and deterministic amortization,
/// a credit card has a revolving balance — different model, different screen.
struct LoansView: View {
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore
    @Query(sort: \Loan.name) private var allLoans: [Loan]

    @State private var editingLoan: Loan?
    @State private var isPresentingNew = false
    @State private var liquidatedExpanded = false

    private var activeLoans: [Loan] {
        allLoans.filter(\.isActive).sorted { endDate(of: $0) < endDate(of: $1) }
    }

    // Coordinator (2026-09-17, DESIGN_LIQUID.md § "Préstamos lista", Figma frame "03 ·
    // Prestamos lista" 5:67): the flat list with a per-card direction chip is replaced by two
    // grouped sections, one per direction — the section header communicates direction now, so
    // the chip disappears from active cards entirely (LIQUIDADOS keeps its own "Pagado" chip,
    // unaffected).
    private var lentLoans: [Loan] {
        activeLoans.filter { $0.direction == .lent }
    }

    private var borrowedLoans: [Loan] {
        activeLoans.filter { $0.direction == .borrowed }
    }

    private var liquidatedLoans: [Loan] {
        allLoans.filter { !$0.isActive }
    }

    var body: some View {
        Group {
            if allLoans.isEmpty {
                LabEmptyState(
                    icon: "banknote",
                    title: "Sin préstamos todavía",
                    message: "Registra un préstamo para ver su saldo y calendario de pagos automáticamente",
                    config: PatternConfig(accentColor: .accentColor)
                )
            } else {
                // Coordinator (2026-09-16): `List` kept ONLY for its native `.swipeActions`/
                // `.contextMenu`/`NavigationLink` behavior (verified safe here — unlike
                // PeriodView's lines, this `List` is the screen's own top-level scroll
                // container, not nested inside another `ScrollView`, so it doesn't hit the
                // touch-blocking bug documented in `LineItemRow`). Every row is stripped of
                // List's own chrome (`listRowBackground`/`listRowInsets`/`listRowSeparator`)
                // so `LoanRow`'s own card background/radius shows through as an independent
                // floating card with an ~8pt gap, not one big grouped section.
                List {
                    // Coordinator (2026-09-17): section per direction replaces the flat list
                    // — hidden entirely (not shown empty) when a direction has no active
                    // loans.
                    if !lentLoans.isEmpty {
                        Section {
                            ForEach(lentLoans) { loan in
                                loanRow(for: loan)
                            }
                        } header: {
                            sectionHeader("ME DEBEN")
                        }
                    }

                    if !borrowedLoans.isEmpty {
                        Section {
                            ForEach(borrowedLoans) { loan in
                                loanRow(for: loan)
                            }
                        } header: {
                            sectionHeader("DEBO")
                        }
                    }

                    if !liquidatedLoans.isEmpty {
                        DisclosureGroup(isExpanded: $liquidatedExpanded) {
                            ForEach(liquidatedLoans) { loan in
                                loanRow(for: loan)
                            }
                        } label: {
                            // Coordinator (2026-09-15, mockup round 4): uppercase section
                            // label to match the caption-style headers used elsewhere.
                            Text("LIQUIDADOS")
                                .font(.caption.weight(.semibold))
                                .tracking(0.5)
                                .foregroundStyle(.secondary)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.horizontal, 16)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Préstamos")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isPresentingNew = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Agregar préstamo")
            }
        }
        .sheet(isPresented: $isPresentingNew) {
            LoanEditSheet(loan: nil)
        }
        .sheet(item: $editingLoan) { loan in
            LoanEditSheet(loan: loan)
        }
    }

    @ViewBuilder
    private func loanRow(for loan: Loan) -> some View {
        // Coordinator (2026-09-17): same chevron-removal fix as `CreditCardRow` — confirmed
        // this row has the exact same structure (`NavigationLink` as the List row's label),
        // so it has the same native disclosure chevron. Invisible `.background` NavigationLink
        // instead, `LoanRow` alone is the visible label.
        LoanRow(loan: loan)
            .background(
                NavigationLink(destination: LoanDetailView(loan: loan)) { EmptyView() }
                    .opacity(0)
            )
        .swipeActions {
            Button(role: .destructive) {
                PeriodCoordinator.deleteLoan(loan, context: context, exchangeRate: rateStore.currentRate ?? 0)
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
            Button {
                editingLoan = loan
            } label: {
                Label("Editar", systemImage: "pencil")
            }
            .tint(.blue)
        }
        // Strip List's own row chrome — `LoanRow`'s own Frost card (background + 18pt
        // radius, DESIGN_LIQUID.md § Préstamos lista — distinct from the app's usual 20pt)
        // shows through as an independent floating card instead of a row inside one big
        // grouped section; the 8pt vertical padding is the gap between cards.
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    /// "ME DEBEN"/"DEBO" section headers — same `p small` token as Quincena's INCOME/EXPENSES
    /// headers (`.caption.weight(.bold)`), tracking per DESIGN_LIQUID.md's exact Figma spec
    /// for this screen (+0.6pt).
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .textCase(nil)
    }

    private func endDate(of loan: Loan) -> CivilDate {
        // Revolving loans have no fixed end — sort them after every fixed-term loan by using
        // a far-future date, rather than the meaningless `termMonths` they don't use.
        guard loan.mode == .fixedTerm else { return CivilDate(year: 9999, month: 12, day: 31) }
        return LoanEngine.endDate(startDate: loan.civilStartDate, termMonths: loan.termMonths, frequency: loan.frequency)
    }
}

/// Custom row — payment lines + progress bar don't fit `LabListRow`. Documented in
/// PROJECT_LEARNINGS.md as a generalization candidate.
///
/// Coordinator (2026-09-17, DESIGN_LIQUID.md § "Préstamos lista"): the direction chip is gone
/// for active loans — the section header ("ME DEBEN"/"DEBO") communicates direction now.
/// LIQUIDADOS keeps its own "Pagado" chip, restyled to spec (white 1pt border, no fill, 8pt
/// text — was a filled gray capsule at 12pt, didn't match the closed Figma measurements).
private struct LoanRow: View {
    let loan: Loan
    @Environment(\.modelContext) private var context

    private var isRevolving: Bool { loan.mode == .revolving }

    private var snapshot: LoanSnapshot {
        LoanSnapshot(id: loan.id, name: loan.name, direction: loan.direction, principal: loan.principal, currency: loan.currency, apr: loan.apr, startDate: loan.civilStartDate, termMonths: loan.termMonths, frequency: loan.frequency, paymentOverride: loan.paymentOverride, isActive: loan.isActive, mode: loan.mode, expectedPayment: loan.expectedPayment)
    }

    private var schedule: [LoanInstallment] { LoanEngine.schedule(for: snapshot) }
    private var today: CivilDate { CivilDate.today() }
    private var nextInstallment: LoanInstallment? { schedule.first { $0.date > today } }

    // Revolving: no persisted actual-payment ledger available from this list row (that lives
    // in `PeriodCoordinator`, keyed off real materialized `LineItem`s), so the row shows the
    // pure-projection schedule (assumes `expectedPayment` every period, no real overrides) —
    // close enough for a list badge; `LoanDetailView` shows the precise, ledger-aware figures.
    private var revolvingResult: LoanEngine.RevolvingResult? {
        guard isRevolving, let expected = loan.expectedPayment else { return nil }
        return LoanEngine.revolvingSchedule(principal: loan.principal, apr: loan.apr, expectedPayment: expected, frequency: loan.frequency, start: loan.civilStartDate, actualPayments: [:])
    }

    private var revolvingNext: LoanEngine.RevolvingRow? { revolvingResult?.rows.first { $0.date > today } }

    // TRD "paidAt/progreso real de préstamos" (2026-09-16): same real `paidToDate` +
    // `principal + accumulatedInterest − paidToDate` formula as `LoanDetailView` — reused via
    // `PeriodCoordinator.loanPaidToDate`/`LoanEngine.accumulatedInterest`, not a second
    // schedule-derived version.
    private var paidToDate: Decimal { PeriodCoordinator.loanPaidToDate(loanID: loan.id, context: context) }

    /// Último Pago — amount + date of the most recently confirmed-paid line, reused from
    /// `PeriodCoordinator` (not re-derived here) per the coordinator's explicit instruction.
    /// `nil` until the loan has at least one real confirmed payment.
    private var lastPaymentAmount: Decimal? { PeriodCoordinator.loanLastPaymentAmount(loanID: loan.id, context: context) }
    private var lastPaymentDate: CivilDate? { PeriodCoordinator.loanLastPaymentDate(loanID: loan.id, context: context) }

    private var currentBalance: Decimal {
        let interest = isRevolving
            ? LoanEngine.accumulatedInterest(revolvingRows: revolvingResult?.rows ?? [], through: today)
            : LoanEngine.accumulatedInterest(schedule: schedule, through: today)
        return loan.principal + interest - paidToDate
    }

    private var paidFraction: Double {
        guard loan.principal > 0 else { return 0 }
        let fraction = paidToDate / loan.principal
        return max(0, min(1, Double(truncating: fraction as NSDecimalNumber)))
    }

    private var isDebo: Bool { loan.direction == .borrowed }
    private var directionText: String { isDebo ? "Debo" : "Me deben" }
    private var isLiquidated: Bool { !loan.isActive }

    private var endDateText: String {
        LoanEngine.endDate(startDate: loan.civilStartDate, termMonths: loan.termMonths, frequency: loan.frequency)
            .date(calendar: .current)
            .formatted(.dateTime.month(.abbreviated).year())
    }

    /// "Sin plazo · termina aprox. [fecha]" or "· según pago esperado" when `neverEnds`.
    private var revolvingBadgeText: String {
        guard let revolvingResult else { return "Sin plazo" }
        if revolvingResult.neverEnds { return "Sin plazo · no liquida con el pago esperado" }
        if let lastRow = revolvingResult.rows.last {
            let dateText = lastRow.date.date(calendar: .current).formatted(.dateTime.month(.abbreviated).year())
            return "Sin plazo · termina aprox. \(dateText)"
        }
        return "Sin plazo · según pago esperado"
    }

    // DESIGN_LIQUID.md § "Préstamos lista" exact hex/type measurements (Figma 5:67).
    private static let mutedLabelColor = Color(red: 0xC7 / 255.0, green: 0xC7 / 255.0, blue: 0xCC / 255.0) // #C7C7CC

    /// "Último Pago $X · fecha" — label AND value both Regular #C7C7CC (same weight,
    /// unlike "Próximo pago" below), one plain `Text`. `nil` if no real payment yet.
    private var lastPaymentText: Text? {
        guard let lastPaymentAmount, let lastPaymentDate else { return nil }
        let dateText = lastPaymentDate.date(calendar: .current).formatted(.dateTime.day().month(.abbreviated).year())
        return Text("Último Pago  \(lastPaymentAmount.currencyString(currency: loan.currency)) · \(dateText)")
            .font(.system(size: 14))
            .foregroundStyle(Self.mutedLabelColor)
    }

    /// "Próximo pago $Y · fecha" — label Regular #C7C7CC, value Semibold white, composed as
    /// two concatenated `Text` runs so each half keeps its own weight/color in one line.
    private func nextPaymentText(amount: Decimal, date: CivilDate) -> Text {
        let dateText = date.date(calendar: .current).formatted(.dateTime.day().month(.abbreviated))
        return Text("Próximo pago  ").font(.system(size: 14)).foregroundStyle(Self.mutedLabelColor)
            + Text("\(amount.currencyString(currency: loan.currency)) · \(dateText)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
    }

    /// "Restante $Z" — label Regular `.secondary`, value Semibold white, both 14pt.
    private var restanteText: Text {
        let amount = isLiquidated ? Decimal(0) : currentBalance
        return Text("Restante  ").font(.system(size: 14)).foregroundStyle(Self.mutedLabelColor)
            + Text(amount.currencyString(currency: loan.currency))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isLiquidated ? 8 : 8) {
            Text(loan.name)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)

            if isLiquidated {
                // LIQUIDADOS: unchanged structure — "Pagado" chip lives beside the name (own
                // HStack, since this branch never shows the payment lines above), Restante,
                // Liquidado.
                restanteText
                Text("Liquidado —")
                    .font(.system(size: 14))
                    .foregroundStyle(Self.mutedLabelColor)
            } else {
                // Payment-lines cluster (8pt internal gap) sits close to the name; the
                // Restante+progress cluster gets an explicit extra 10pt on top of the
                // surrounding VStack's own 8pt spacing, landing the two blocks at the 18pt
                // Figma-measured gap while the name→payment-lines gap stays at the app's usual
                // 8pt block spacing (the mockup's ascii art only visually calls out ONE large
                // gap, right before Restante — interpreted here as that one, not a uniform
                // 18pt everywhere; flagging this reading, not silently assuming it).
                VStack(alignment: .leading, spacing: 8) {
                    if let lastPaymentText {
                        lastPaymentText
                    }
                    if isRevolving {
                        if let revolvingNext {
                            nextPaymentText(amount: revolvingNext.payment, date: revolvingNext.date)
                        }
                        Text(revolvingBadgeText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let nextInstallment {
                        nextPaymentText(amount: nextInstallment.payment, date: nextInstallment.date)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    restanteText
                    LoanProgressBar(value: paidFraction)
                }
                .padding(.top, 10)
            }
        }
        // Coordinator (2026-09-17): 18pt radius for THIS screen's cards — distinct from the
        // app's usual 20pt, per Figma 5:67 (confirmed, not an oversight).
        .padding(16)
        .background(Color("AppBackgroundSecondary"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isLiquidated ? "Pagado" : directionText), \(loan.name), restante \(isLiquidated ? Decimal(0).currencyString(currency: loan.currency) : currentBalance.currencyString(currency: loan.currency))\(isRevolving && !isLiquidated ? ", " + revolvingBadgeText : "")")
    }
}

/// Track `#023C2F` / fill `#00FFC5`, 5pt radius, 4pt height — DESIGN_LIQUID.md § "Préstamos
/// lista". Green for BOTH "ME DEBEN" and "DEBO" (confirmed by the coordinator, 2026-09-17):
/// the section already communicates direction, so the bar no longer tints by it — this
/// replaces the native `ProgressView(value:).tint(...)`, which can't hit this exact
/// track/fill/radius/height combination reliably across platforms.
// Coordinator (2026-09-17): widened from `private` to internal so `CreditCardsView`'s
// utilization bar can reuse this exact track/fill/radius/height instead of a second copy.
struct LoanProgressBar: View {
    let value: Double

    private static let trackColor = Color(red: 0x02 / 255.0, green: 0x3C / 255.0, blue: 0x2F / 255.0) // #023C2F
    private static let fillColor = Color(red: 0x00 / 255.0, green: 0xFF / 255.0, blue: 0xC5 / 255.0) // #00FFC5

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Self.trackColor)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Self.fillColor)
                    .frame(width: max(0, geometry.size.width * CGFloat(value)))
            }
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityValue("\(Int((value * 100).rounded())) por ciento pagado")
    }
}

private enum LoanFrequencyOption: String, CaseIterable, Identifiable {
    case monthly = "Mensual, día X"
    case biweekly = "Cada quincena"
    var id: String { rawValue }
}

// Coordinator (2026-09-16): widened from `private` to internal so `LoanDetailView`'s new
// "Editar" toolbar button can reuse this exact form/validation instead of duplicating it.
struct LoanEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore
    @Environment(\.dismiss) private var dismiss

    let loan: Loan?

    @State private var name: String
    @State private var direction: LoanDirection
    @State private var principal: Decimal
    @State private var currency: Currency
    @State private var aprPercent: Decimal
    @State private var startDate: Date
    /// The ONLY source of truth for the loan's term (TRD) — `endDate` is never stored
    /// separately; it's always derived from this via `endDateBinding` below. Bertrand found
    /// that two independent `@State` vars kept in sync through a pair of `.onChange` handlers
    /// oscillate: `SwiftUI`'s `onChange` isn't fired synchronously nested inside the state
    /// write that triggered it, so by the time the second handler ran, the reentrancy guard
    /// had already been reset — each edit could bounce the other field to a slightly
    /// different value and back, and the Stepper could never settle on the value the user
    /// picked. A single stored value with a computed get/set `Binding` for the linked field
    /// can't oscillate: there is nothing to feed back into.
    @State private var termMonths: Int
    @State private var frequencyOption: LoanFrequencyOption
    @State private var hasOverride: Bool
    @State private var overrideText: String
    @State private var isActive: Bool
    @State private var showDirectionChangeConfirm = false
    @State private var mode: LoanMode
    @State private var expectedPaymentText: String

    init(loan: Loan?) {
        self.loan = loan
        let initialFrequency = loan?.frequency ?? .monthly(day: 1)
        _name = State(initialValue: loan?.name ?? "")
        _direction = State(initialValue: loan?.direction ?? .borrowed)
        _principal = State(initialValue: loan?.principal ?? 0)
        _currency = State(initialValue: loan?.currency ?? .usd)
        _aprPercent = State(initialValue: (loan?.apr ?? 0) * 100)
        _startDate = State(initialValue: loan?.startDate ?? .now)
        _termMonths = State(initialValue: loan?.termMonths ?? 12)
        if case .biweekly = initialFrequency {
            _frequencyOption = State(initialValue: .biweekly)
        } else {
            _frequencyOption = State(initialValue: .monthly)
        }
        _hasOverride = State(initialValue: loan?.paymentOverride != nil)
        _overrideText = State(initialValue: loan?.paymentOverride?.twoDecimalString ?? "")
        _isActive = State(initialValue: loan?.isActive ?? true)
        _mode = State(initialValue: loan?.mode ?? .fixedTerm)
        _expectedPaymentText = State(initialValue: loan?.expectedPayment?.twoDecimalString ?? "")
    }

    private var expectedPayment: Decimal? {
        Decimal(string: expectedPaymentText, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// The interest a `.revolving` loan's CURRENT balance would accrue in one month — used to
    /// warn when `expectedPayment` doesn't even cover it (DESIGN_LIQUID: aviso naranja).
    private var currentMonthInterestEstimate: Decimal {
        (loan?.principal ?? principal) * (apr / 12)
    }

    private var expectedPaymentTooLow: Bool {
        guard mode == .revolving, let expectedPayment, expectedPayment > 0 else { return false }
        return expectedPayment <= currentMonthInterestEstimate
    }

    // El día de pago mensual se deriva del día del mes de "Fecha de inicio" — no hay un
    // campo separado que pueda desincronizarse (feedback del usuario).
    private var frequency: LoanFrequency {
        frequencyOption == .biweekly ? .biweekly : .monthly(day: Calendar.current.component(.day, from: startDate))
    }

    /// `endDate` for display/editing: always freshly derived from `termMonths` (never
    /// drifts), and editing it writes `termMonths` back exactly once — no re-derivation of
    /// `endDate` from that write, so there is nothing left to bounce (Bertrand's Stepper bug).
    private var endDateBinding: Binding<Date> {
        Binding(
            get: {
                LoanEngine.endDate(startDate: CivilDate(from: startDate, calendar: .current), termMonths: termMonths, frequency: frequency)
                    .date(calendar: .current)
            },
            set: { newDate in
                let start = CivilDate(from: startDate, calendar: .current)
                let end = CivilDate(from: newDate, calendar: .current)
                termMonths = LoanEngine.termMonths(from: start, to: end)
            }
        )
    }

    private var apr: Decimal { aprPercent / 100 }

    /// Bertrand's crash (critical): an absurd APR compounded over many periods can overflow
    /// `Decimal` inside `LoanEngine`. `LoanEngine` itself now fails closed instead of
    /// crashing, but the form is the first line of defense — never let the user submit a
    /// value that shouldn't exist in the first place.
    private var isFormValid: Bool {
        guard !name.isEmpty else { return false }
        guard ValidationRange.amount.contains(principal) else { return false }
        guard aprPercent >= 0, aprPercent <= 100 else { return false }
        if mode == .fixedTerm {
            guard ValidationRange.termMonths.contains(termMonths) else { return false }
        } else {
            guard let expectedPayment, expectedPayment > 0 else { return false }
        }
        return true
    }

    private var calculatedPayment: Decimal {
        LoanEngine.payment(principal: principal, apr: apr, termMonths: termMonths, frequency: frequency)
    }

    private var overrideRecalculatedTermText: String? {
        guard hasOverride, let override = Decimal(string: overrideText, locale: Locale(identifier: "en_US_POSIX")), override > 0 else { return nil }
        let n = LoanEngine.numberOfPayments(forPayment: override, principal: principal, apr: apr, frequency: frequency)
        let periods = frequencyOption == .biweekly ? "quincenas" : "meses"
        let civilStart = CivilDate(from: startDate, calendar: .current)
        let recalculatedEnd = frequencyOption == .biweekly
            ? civilStart.addingDays(15 * n)
            : LoanEngine.endDate(startDate: civilStart, termMonths: n, frequency: frequency)
        return "Con este pago, el préstamo se liquida en \(n) \(periods) (\(recalculatedEnd.date(calendar: .current).formatted(.dateTime.month(.abbreviated).year())))."
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabTextField(placeholder: "Nombre", text: $name, config: PatternConfig(accentColor: .accentColor))

                    Picker("Dirección", selection: $direction) {
                        Text("Me lo prestaron").tag(LoanDirection.borrowed)
                        Text("Lo presté").tag(LoanDirection.lent)
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        // Coordinator (2026-09-17): `LabDecimalField` — centralized fix for
                        // "0.00 isn't a placeholder, has to be deleted by hand".
                        LabDecimalField(placeholder: "Monto original", value: $principal)
                        Picker("Moneda", selection: $currency) {
                            Text("USD").tag(Currency.usd)
                            Text("MXN").tag(Currency.mxn)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }

                    HStack {
                        // isCurrency: false — a percentage, not money, no thousands grouping.
                        LabDecimalField(placeholder: "APR", value: $aprPercent, isCurrency: false)
                        Text("%")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    DatePicker("Fecha de inicio", selection: $startDate, displayedComponents: .date)

                    Picker("Frecuencia", selection: $frequencyOption) {
                        ForEach(LoanFrequencyOption.allCases) { Text($0.rawValue).tag($0) }
                    }

                    LabToggleRow(title: "Hasta liquidar (revolving)", isOn: Binding(
                        get: { mode == .revolving },
                        set: { mode = $0 ? .revolving : .fixedTerm }
                    ), config: PatternConfig(accentColor: .accentColor))

                    if mode == .fixedTerm {
                        Stepper("Plazo (meses): \(termMonths)", value: $termMonths, in: 1...600)
                        DatePicker("Fecha fin", selection: endDateBinding, displayedComponents: .date)
                    }
                } footer: {
                    Text(mode == .fixedTerm
                        ? "Editar el plazo o la fecha fin recalcula el otro en vivo."
                        : "Sin plazo fijo: interés mensual sobre el saldo, como una tarjeta de crédito. Puedes cambiar el pago real en cada quincena."
                    )
                }

                if mode == .revolving {
                    Section {
                        TextField("Pago esperado", text: $expectedPaymentText)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        if expectedPaymentTooLow {
                            // A11Y #24 (Sarah): color-only warnings are invisible to VoiceOver
                            // and to anyone who can't distinguish orange — icon + explicit
                            // "Advertencia" text so the label itself carries the meaning.
                            Label("Este pago no cubre el interés mensual estimado — el saldo nunca bajará con este monto.", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .accessibilityLabel("Advertencia: pago insuficiente para cubrir interés mensual")
                        }
                    } footer: {
                        Text("Puedes cambiar el pago real en cada quincena.")
                    }
                } else {
                    Section {
                        if !hasOverride {
                            HStack {
                                Text("Pago calculado")
                                Spacer()
                                Text("\(calculatedPayment.currencyString(currency: currency))/\(frequencyOption == .biweekly ? "quincena" : "mes")")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Button("Sobreescribir monto de pago") {
                                overrideText = calculatedPayment.twoDecimalString
                                hasOverride = true
                            }
                        } else {
                            TextField("Monto de pago", text: $overrideText)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                            if let overrideRecalculatedTermText {
                                Text(overrideRecalculatedTermText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Button("Volver al cálculo automático") {
                                hasOverride = false
                                overrideText = ""
                            }
                        }
                    }
                }

                Section {
                    LabToggleRow(title: "Activo", isOn: $isActive, config: PatternConfig(accentColor: .accentColor))
                }
            }
            .navigationTitle(loan == nil ? "Nuevo préstamo" : "Editar préstamo")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if let loan, loan.direction != direction {
                            showDirectionChangeConfirm = true
                        } else {
                            save()
                        }
                    }
                    .disabled(!isFormValid)
                }
            }
            .confirmationDialog(
                "¿Cambiar la dirección del préstamo?",
                isPresented: $showDirectionChangeConfirm,
                titleVisibility: .visible
            ) {
                Button("Cambiar de todos modos", role: .destructive) { save() }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Ya existen pagos generados para este préstamo. Cambiar la dirección afecta cómo se calculan en quincenas futuras.")
            }
        }
    }

    private func save() {
        let resolvedOverride: Decimal? = {
            guard hasOverride, let value = Decimal(string: overrideText, locale: Locale(identifier: "en_US_POSIX")), value > 0 else { return nil }
            return value
        }()
        // Persist termMonths consistent with the override, if any — termMonths stays the
        // single source of truth (TRD), the override just changes what value it resolves to.
        let resolvedTermMonths: Int = {
            guard let resolvedOverride else { return termMonths }
            let n = LoanEngine.numberOfPayments(forPayment: resolvedOverride, principal: principal, apr: apr, frequency: frequency)
            return frequencyOption == .biweekly ? max(1, n / 2) : n
        }()

        let target: Loan
        if let loan {
            loan.name = name
            loan.direction = direction
            loan.principal = principal
            loan.currency = currency
            loan.apr = apr
            loan.civilStartDate = CivilDate(from: startDate, calendar: .current)
            loan.termMonths = mode == .revolving ? loan.termMonths : resolvedTermMonths
            loan.frequency = frequency
            loan.paymentOverride = mode == .revolving ? nil : resolvedOverride
            loan.isActive = isActive
            loan.mode = mode
            loan.expectedPayment = mode == .revolving ? expectedPayment : nil
            target = loan
        } else {
            let newLoan = Loan(name: name, direction: direction, principal: principal, currency: currency, apr: apr, startDate: startDate, termMonths: mode == .revolving ? 1 : resolvedTermMonths, frequency: frequency, paymentOverride: mode == .revolving ? nil : resolvedOverride, isActive: isActive, mode: mode, expectedPayment: mode == .revolving ? expectedPayment : nil)
            context.insert(newLoan)
            target = newLoan
        }
        try? context.save()
        PeriodCoordinator.reprojectLoan(item: target, context: context, exchangeRate: rateStore.currentRate ?? 0)
        dismiss()
    }
}
