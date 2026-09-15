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
                List {
                    Section {
                        ForEach(activeLoans) { loan in
                            NavigationLink {
                                LoanDetailView(loan: loan)
                            } label: {
                                LoanRow(loan: loan)
                            }
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
                        }
                    }

                    if !liquidatedLoans.isEmpty {
                        DisclosureGroup("Liquidados", isExpanded: $liquidatedExpanded) {
                            ForEach(liquidatedLoans) { loan in
                                NavigationLink {
                                    LoanDetailView(loan: loan)
                                } label: {
                                    LoanRow(loan: loan)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Préstamos")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isPresentingNew = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $isPresentingNew) {
            LoanEditSheet(loan: nil)
        }
        .sheet(item: $editingLoan) { loan in
            LoanEditSheet(loan: loan)
        }
    }

    private func endDate(of loan: Loan) -> CivilDate {
        LoanEngine.endDate(startDate: loan.civilStartDate, termMonths: loan.termMonths, frequency: loan.frequency)
    }
}

/// Custom row — direction chip + progress bar don't fit `LabListRow`. Documented in
/// PROJECT_LEARNINGS.md as a generalization candidate.
private struct LoanRow: View {
    let loan: Loan

    private var snapshot: LoanSnapshot {
        LoanSnapshot(id: loan.id, name: loan.name, direction: loan.direction, principal: loan.principal, currency: loan.currency, apr: loan.apr, startDate: loan.civilStartDate, termMonths: loan.termMonths, frequency: loan.frequency, paymentOverride: loan.paymentOverride, isActive: loan.isActive)
    }

    private var schedule: [LoanInstallment] { LoanEngine.schedule(for: snapshot) }
    private var today: CivilDate { CivilDate.today() }
    private var lastPast: LoanInstallment? { schedule.last { $0.date <= today } }
    private var nextInstallment: LoanInstallment? { schedule.first { $0.date > today } }
    private var currentBalance: Decimal { lastPast?.remainingBalance ?? loan.principal }

    private var paidFraction: Double {
        guard loan.principal > 0 else { return 0 }
        let fraction = (loan.principal - currentBalance) / loan.principal
        return max(0, min(1, Double(truncating: fraction as NSDecimalNumber)))
    }

    private var isDebo: Bool { loan.direction == .borrowed }
    private var tintColor: Color { isDebo ? .orange : .blue }
    private var directionText: String { isDebo ? "Debo" : "Me deben" }
    private var directionIcon: String { isDebo ? "arrow.up.forward" : "arrow.down.forward" }

    private var endDateText: String {
        LoanEngine.endDate(startDate: loan.civilStartDate, termMonths: loan.termMonths, frequency: loan.frequency)
            .date(calendar: .current)
            .formatted(.dateTime.month(.abbreviated).year())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "banknote")
                    .foregroundStyle(.secondary)
                Text(loan.name)
                    .font(.body.weight(.semibold))
                Spacer()
                // Chip nunca depende solo del color — icono + texto siempre visibles (A11Y).
                HStack(spacing: 4) {
                    Image(systemName: directionIcon)
                    Text(directionText)
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(tintColor.opacity(0.15)))
                .foregroundStyle(tintColor)
            }

            Text("Saldo restante: \(currentBalance.currencyString(currency: loan.currency))")
                .font(.body.weight(.semibold))
                .monospacedDigit()

            if let nextInstallment {
                Text("Próximo pago: \(nextInstallment.payment.currencyString(currency: loan.currency)) · \(nextInstallment.date.date(calendar: .current).formatted(.dateTime.day().month(.abbreviated)))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Fecha fin: \(endDateText)")
                .font(.caption)
                .foregroundStyle(.secondary)

            ProgressView(value: paidFraction)
                .tint(tintColor)
                .accessibilityValue("\(Int((paidFraction * 100).rounded())) por ciento pagado")
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(directionText), \(loan.name), saldo restante \(currentBalance.currencyString(currency: loan.currency))")
    }
}

private enum LoanFrequencyOption: String, CaseIterable, Identifiable {
    case monthly = "Mensual, día X"
    case biweekly = "Cada quincena"
    var id: String { rawValue }
}

private struct LoanEditSheet: View {
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
    @State private var monthlyDay: Int
    @State private var hasOverride: Bool
    @State private var overrideText: String
    @State private var isActive: Bool
    @State private var showDirectionChangeConfirm = false

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
            _monthlyDay = State(initialValue: 1)
        } else if case .monthly(let day) = initialFrequency {
            _frequencyOption = State(initialValue: .monthly)
            _monthlyDay = State(initialValue: day)
        } else {
            _frequencyOption = State(initialValue: .monthly)
            _monthlyDay = State(initialValue: 1)
        }
        _hasOverride = State(initialValue: loan?.paymentOverride != nil)
        _overrideText = State(initialValue: loan?.paymentOverride?.twoDecimalString ?? "")
        _isActive = State(initialValue: loan?.isActive ?? true)
    }

    private var frequency: LoanFrequency {
        frequencyOption == .biweekly ? .biweekly : .monthly(day: monthlyDay)
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
        guard ValidationRange.termMonths.contains(termMonths) else { return false }
        guard ValidationRange.dayOfMonth.contains(monthlyDay) else { return false }
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
                        TextField("Monto original", value: $principal, format: .number.precision(.fractionLength(2)))
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Picker("Moneda", selection: $currency) {
                            Text("USD").tag(Currency.usd)
                            Text("MXN").tag(Currency.mxn)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }

                    HStack {
                        TextField("APR", value: $aprPercent, format: .number.precision(.fractionLength(2)))
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("%")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    DatePicker("Fecha de inicio", selection: $startDate, displayedComponents: .date)

                    Stepper("Plazo (meses): \(termMonths)", value: $termMonths, in: 1...600)

                    DatePicker("Fecha fin", selection: endDateBinding, displayedComponents: .date)

                    Picker("Frecuencia", selection: $frequencyOption) {
                        ForEach(LoanFrequencyOption.allCases) { Text($0.rawValue).tag($0) }
                    }
                    if frequencyOption == .monthly {
                        Stepper("Día del mes: \(monthlyDay)", value: $monthlyDay, in: 1...31)
                    }
                } footer: {
                    Text("Editar el plazo o la fecha fin recalcula el otro en vivo.")
                }

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
            loan.termMonths = resolvedTermMonths
            loan.frequency = frequency
            loan.paymentOverride = resolvedOverride
            loan.isActive = isActive
            target = loan
        } else {
            let newLoan = Loan(name: name, direction: direction, principal: principal, currency: currency, apr: apr, startDate: startDate, termMonths: resolvedTermMonths, frequency: frequency, paymentOverride: resolvedOverride, isActive: isActive)
            context.insert(newLoan)
            target = newLoan
        }
        try? context.save()
        PeriodCoordinator.reprojectLoan(item: target, context: context, exchangeRate: rateStore.currentRate ?? 0)
        dismiss()
    }
}
