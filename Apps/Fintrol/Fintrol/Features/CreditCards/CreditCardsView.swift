import SwiftUI
import SwiftData
import AppleAppLabUI

/// "Credit Cards" — sixth entry of the "Recurrentes y pagos" hub, section EXPENSES
/// (DESIGN_LIQUID.md § "Tarjetas de crédito"). Revolving debt — no direction (always
/// `.expense`, unlike `Loan`), no fixed term, its own `CreditCardEngine`.
struct CreditCardsView: View {
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore
    @Query(sort: \CreditCard.name) private var allCards: [CreditCard]

    @AppStorage("fintrol.creditCardPaymentDateRuleKind") private var dateRuleKind = 2
    @AppStorage("fintrol.creditCardPaymentDateRuleDays") private var dateRuleDays = 5
    private var dateRule: CreditCardPaymentDateRule { .resolve(kindRaw: dateRuleKind, days: dateRuleDays) }

    @State private var editingCard: CreditCard?
    @State private var isPresentingNew = false

    var body: some View {
        Group {
            if allCards.isEmpty {
                LabEmptyState(
                    icon: "creditcard.fill",
                    title: "Sin tarjetas todavía",
                    message: "Registra una tarjeta para ver su saldo, utilización y pago mínimo sugerido automáticamente",
                    config: PatternConfig(accentColor: .accentColor)
                )
            } else {
                List {
                    ForEach(allCards) { card in
                        cardRow(for: card)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Credit Cards")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isPresentingNew = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Agregar tarjeta")
            }
        }
        .sheet(isPresented: $isPresentingNew) {
            CreditCardEditSheet(card: nil)
        }
        .sheet(item: $editingCard) { card in
            CreditCardEditSheet(card: card)
        }
    }

    @ViewBuilder
    private func cardRow(for card: CreditCard) -> some View {
        // Coordinator (2026-09-17): the user asked for the native disclosure chevron gone —
        // a `NavigationLink` used as a List row's label always draws one. Standard fix: the
        // NavigationLink becomes an invisible `.background` (still drives the tap-to-push,
        // still gets the row's full tap area), and `CreditCardRow` alone is the visible label.
        CreditCardRow(card: card)
            .background(
                NavigationLink(destination: CreditCardDetailView(card: card)) { EmptyView() }
                    .opacity(0)
            )
        .swipeActions {
            Button(role: .destructive) {
                PeriodCoordinator.deleteCreditCard(card, context: context, exchangeRate: rateStore.currentRate ?? 0)
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
            Button {
                editingCard = card
            } label: {
                Label("Editar", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

/// Custom row — coordinator (2026-09-17): restyled to match `LoanRow`'s card layout (name
/// title, a payment-lines block, then a bold remaining/available-credit line + progress bar)
/// instead of everything cramped on 3 tight lines — same 8pt internal spacing, same 18pt
/// card radius. Utilization uses its own 3-tier `UtilizationProgressBar` (green/yellow/red),
/// not `LoanProgressBar`'s fixed green.
private struct CreditCardRow: View {
    let card: CreditCard
    @Environment(\.modelContext) private var context

    @AppStorage("fintrol.creditCardPaymentDateRuleKind") private var dateRuleKind = 2
    @AppStorage("fintrol.creditCardPaymentDateRuleDays") private var dateRuleDays = 5
    private var dateRule: CreditCardPaymentDateRule { .resolve(kindRaw: dateRuleKind, days: dateRuleDays) }

    private var today: CivilDate { CivilDate.today() }

    private var utilization: Double {
        guard card.creditLimit > 0 else { return 0 }
        let fraction = card.balance / card.creditLimit
        return max(0, min(1, Double(truncating: fraction as NSDecimalNumber)))
    }

    private var utilizationLevel: CreditCardEngine.UtilizationLevel {
        CreditCardEngine.utilizationLevel(balance: card.balance, creditLimit: card.creditLimit)
    }

    private var availableCredit: Decimal {
        max(0, card.creditLimit - card.balance)
    }

    private var suggestedMinimum: Decimal {
        CreditCardEngine.suggestedMinimumPayment(balance: card.balance, apr: card.apr)
    }

    /// This quincena's payment date for the card, per the global date rule — same formula
    /// `reprojectCreditCard`/`CreditCardDetailView` use, not a second one.
    private var nextDueDate: CivilDate {
        let due = CreditCardEngine.paymentDate(cutoffDay: card.cutoffDay, paymentDay: card.paymentDay, year: today.year, month: today.month, rule: dateRule)
        return due >= today ? due : due.addingMonths(1)
    }

    /// "Bank of America •••• 4400" — coordinator (2026-09-17): last 4 digits only, safe to show.
    private var nameWithLastFour: String {
        guard let lastFour = card.lastFourDigits, !lastFour.isEmpty else { return card.name }
        return "\(card.name) •••• \(lastFour)"
    }

    private static let mutedLabelColor = Color(red: 0xC7 / 255.0, green: 0xC7 / 255.0, blue: 0xCC / 255.0) // #C7C7CC

    private var balanceText: Text {
        Text("Saldo actual  ").font(.system(size: 14)).foregroundStyle(Self.mutedLabelColor)
            + Text(card.balance.currencyString(currency: .usd))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
    }

    private var nextPaymentText: Text {
        Text("Próximo pago  ").font(.system(size: 14)).foregroundStyle(Self.mutedLabelColor)
            + Text("\(suggestedMinimum.currencyString(currency: .usd)) · \(nextDueDate.date(calendar: .current).formatted(.dateTime.day().month(.abbreviated)))")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
    }

    private var availableCreditText: Text {
        Text("Límite disponible  ").font(.system(size: 14)).foregroundStyle(Self.mutedLabelColor)
            + Text(availableCredit.currencyString(currency: .usd))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(nameWithLastFour)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 8) {
                balanceText
                if card.isActive, card.balance > 0 {
                    nextPaymentText
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                availableCreditText
                // Coordinator (2026-09-17): replaced the single-threshold "Alta utilización
                // ≥30%" orange caption with a real 3-tier semaphore (green <10%, yellow
                // 10–29.99%, red ≥30%) on the bar itself — researched against myFICO/
                // Experian/CFPB/NerdWallet.
                UtilizationProgressBar(value: utilization, level: utilizationLevel)
            }
            .padding(.top, 10)
        }
        .padding(16)
        .background(Color("AppBackgroundSecondary"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.name), saldo \(card.balance.currencyString(currency: .usd)), utilización \(Int((utilization * 100).rounded())) por ciento")
    }
}

/// Coordinator (2026-09-17): 3-tier utilization semaphore — green (`< 10%`, ideal for credit
/// score), yellow (`10–29.99%`, acceptable), red (`≥ 30%`, starts hurting the score
/// noticeably) — researched against myFICO/Experian/CFPB/NerdWallet. Same track/height/radius
/// as `LoanProgressBar`, just a dynamic fill color instead of a fixed green.
struct UtilizationProgressBar: View {
    let value: Double
    let level: CreditCardEngine.UtilizationLevel

    private static let trackColor = Color.white.opacity(0.12)

    private var fillColor: Color {
        switch level {
        case .low: .green
        case .medium: .yellow
        case .high: .red
        }
    }

    private var levelDescription: String {
        switch level {
        case .low: "baja"
        case .medium: "media"
        case .high: "alta"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Self.trackColor)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(fillColor)
                    .frame(width: max(0, geometry.size.width * CGFloat(value)))
            }
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityValue("\(Int((value * 100).rounded())) por ciento, utilización \(levelDescription)")
    }
}

struct CreditCardEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let card: CreditCard?

    @AppStorage("fintrol.creditCardPaymentDateRuleKind") private var dateRuleKind = 2
    @AppStorage("fintrol.creditCardPaymentDateRuleDays") private var dateRuleDays = 5
    private var dateRule: CreditCardPaymentDateRule { .resolve(kindRaw: dateRuleKind, days: dateRuleDays) }

    @State private var name: String
    @State private var balance: Decimal
    @State private var aprPercent: Decimal
    @State private var creditLimit: Decimal
    @State private var cutoffDay: Int
    @State private var paymentDay: Int
    @State private var expectedPaymentText: String
    @State private var isActive: Bool
    @State private var lastFourDigits: String

    /// Backing state for the day-of-month pickers' sheets — see `dayOfMonthPicker`. A `Menu`
    /// hosting a `.wheel` `Picker` (the first attempt at this control) does not render the
    /// wheel's rows at all on iOS, only an empty popover header — confirmed on-device via
    /// `device-interaction` (2026-09-17). A small `.sheet` with `.presentationDetents` is the
    /// reliable idiom instead.
    @State private var isPickingCutoffDay = false
    @State private var isPickingPaymentDay = false

    init(card: CreditCard?) {
        self.card = card
        _name = State(initialValue: card?.name ?? "")
        _balance = State(initialValue: card?.balance ?? 0)
        _aprPercent = State(initialValue: (card?.apr ?? 0) * 100)
        _creditLimit = State(initialValue: card?.creditLimit ?? 0)
        _cutoffDay = State(initialValue: card?.cutoffDay ?? 1)
        _paymentDay = State(initialValue: card?.paymentDay ?? 1)
        _expectedPaymentText = State(initialValue: card?.expectedPayment?.twoDecimalString ?? "")
        _isActive = State(initialValue: card?.isActive ?? true)
        _lastFourDigits = State(initialValue: card?.lastFourDigits ?? "")
    }

    /// 4 characters, digits only — `nil` if left blank.
    private var lastFourDigitsIsValid: Bool {
        lastFourDigits.isEmpty || (lastFourDigits.count == 4 && lastFourDigits.allSatisfy(\.isNumber))
    }

    private var apr: Decimal { aprPercent / 100 }

    private var expectedPayment: Decimal? {
        Decimal(string: expectedPaymentText, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// "El placeholder muestra en vivo el mínimo sugerido" (DESIGN_LIQUID.md) — recalculated
    /// from the fields as the user types, not the card's stale persisted value.
    private var suggestedMinimumPreview: Decimal {
        CreditCardEngine.suggestedMinimumPayment(balance: balance, apr: apr)
    }

    private var isFormValid: Bool {
        guard !name.isEmpty else { return false }
        guard ValidationRange.amount.contains(balance) || balance == 0 else { return false }
        guard aprPercent >= 0, aprPercent <= 100 else { return false }
        guard ValidationRange.dayOfMonth.contains(cutoffDay), ValidationRange.dayOfMonth.contains(paymentDay) else { return false }
        guard lastFourDigitsIsValid else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabTextField(placeholder: "Nombre", text: $name, config: PatternConfig(accentColor: .accentColor))

                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Últimos 4 dígitos (opcional)", text: $lastFourDigits)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .onChange(of: lastFourDigits) { _, newValue in
                                let digitsOnly = newValue.filter(\.isNumber)
                                lastFourDigits = String(digitsOnly.prefix(4))
                            }
                        if !lastFourDigitsIsValid {
                            Text("Debe ser vacío o exactamente 4 dígitos.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    // Coordinator (2026-09-17): a bare `TextField("Saldo actual", value:)`
                    // only shows that string as a placeholder — invisible once the field has a
                    // real value (which it does immediately, defaulting to 0.00). Same labeled
                    // pattern as `LineCaptureSheet`'s "Monto" field: a persistent `.caption`
                    // `.secondary` label above the field, not a placeholder.
                    labeledNumberField("Saldo actual", value: $balance, unit: "USD")
                    labeledNumberField("APR", value: $aprPercent, unit: "%")
                    labeledNumberField("Límite de crédito", value: $creditLimit, unit: "USD")
                }

                Section {
                    dayOfMonthPicker("Día de corte", day: $cutoffDay, isPresented: $isPickingCutoffDay)
                    dayOfMonthPicker("Día de pago", day: $paymentDay, isPresented: $isPickingPaymentDay)
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pago esperado")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("", text: $expectedPaymentText, prompt: Text(suggestedMinimumPreview.currencyString(currency: .usd)))
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                } footer: {
                    Text("Vacío usa el mínimo sugerido recalculado cada quincena: MAX($25, saldo × 1% + interés del mes).")
                }

                Section {
                    LabToggleRow(title: "Activa", isOn: $isActive, config: PatternConfig(accentColor: .accentColor))
                }
            }
            .navigationTitle(card == nil ? "Nueva tarjeta" : "Editar tarjeta")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(!isFormValid)
                }
            }
        }
    }

    /// Same labeled-field pattern as `LineCaptureSheet`'s "Monto" — a persistent `.caption`
    /// `.secondary` label above the field (not a placeholder, which disappears once the field
    /// has a real value). Coordinator (2026-09-17): `LabDecimalField` instead of a raw
    /// `TextField(value:)` — centralized fix for the "0.00 isn't a placeholder, you have to
    /// delete it by hand" bug.
    private func labeledNumberField(_ label: String, value: Binding<Decimal>, unit: String) -> some View {
        // Thousands grouping only for money fields ("USD"), never for the "%" (APR) field.
        let isCurrency = unit != "%"
        return VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                LabDecimalField(placeholder: "0.00", value: value, isCurrency: isCurrency)
                Text(unit).foregroundStyle(.secondary)
            }
        }
    }

    /// Día de corte / pago: rango 1-31 (`ValidationRange.dayOfMonth`). Reemplaza el `Stepper`
    /// −/+ original (2026-09-17, decisión del usuario junto a Steve) — llegar del 1 al 28
    /// tomaba 27 taps. Mismo patrón que Reminders/Calendar para "day of month": una pill
    /// compacta con el día actual que despliega un `Picker` de rueda completo (1...31) al
    /// tocarla, así se salta directo al día sin repetir el gesto.
    ///
    /// iOS: la pill abre un `.sheet` pequeño (`.presentationDetents`) con el wheel — probado
    /// primero como `Menu { Picker(...).pickerStyle(.wheel) }`, que en dispositivo no dibuja
    /// ninguna fila del wheel (solo un header vacío, confirmado con `device-interaction`); un
    /// `Menu` no hospeda bien un control interactivo tan alto como un wheel picker completo.
    ///
    /// macOS: `.wheel` no existe como `pickerStyle` — ahí el equivalente nativo es un popup
    /// button (`.menu`), que ya se ve como una pill dentro del `Form` y es el patrón que usan
    /// las apps de Apple en Mac para el mismo dato, así que no rompe la paridad visual.
    @ViewBuilder
    private func dayOfMonthPicker(_ label: String, day: Binding<Int>, isPresented: Binding<Bool>) -> some View {
        HStack {
            Text(label)
            Spacer()
            #if os(iOS)
            Button {
                isPresented.wrappedValue = true
            } label: {
                dayPill(day.wrappedValue)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: isPresented) {
                dayPickerSheet(label, day: day, isPresented: isPresented)
            }
            #else
            Picker(label, selection: day) {
                ForEach(1...31, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            #endif
        }
        .onChange(of: day.wrappedValue) { _, _ in
            HapticFeedback.lightImpact(reduceMotion: reduceMotion)
        }
    }

    #if os(iOS)
    /// Misma forma de pill compacta (Capsule + `.fill.tertiary`) que el resto de controles
    /// pequeños de Fintrol — ver `DESIGN_LIQUID.md` §Chips/badges.
    private func dayPill(_ day: Int) -> some View {
        Text("\(day)")
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
            .frame(minWidth: 32)
            .padding(.vertical, 6)
            .padding(.horizontal, 14)
            .background(.fill.tertiary, in: Capsule())
    }

    /// Sheet chico y bajo (280pt) — suficiente para el wheel completo sin ocupar la pantalla,
    /// el mismo tamaño que usan los date pickers compactos de Apple para un solo componente.
    private func dayPickerSheet(_ label: String, day: Binding<Int>, isPresented: Binding<Bool>) -> some View {
        NavigationStack {
            Picker(label, selection: day) {
                ForEach(1...31, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .navigationTitle(label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { isPresented.wrappedValue = false }
                }
            }
        }
        .presentationDetents([.height(280)])
    }
    #endif

    private func save() {
        let target: CreditCard
        if let card {
            card.name = name
            card.balance = balance
            card.apr = apr
            card.creditLimit = creditLimit
            card.cutoffDay = cutoffDay
            card.paymentDay = paymentDay
            card.expectedPayment = expectedPayment
            card.isActive = isActive
            card.lastFourDigits = lastFourDigits.isEmpty ? nil : lastFourDigits
            target = card
        } else {
            let newCard = CreditCard(name: name, balance: balance, apr: apr, creditLimit: creditLimit, cutoffDay: cutoffDay, paymentDay: paymentDay, expectedPayment: expectedPayment, isActive: isActive, lastFourDigits: lastFourDigits.isEmpty ? nil : lastFourDigits)
            context.insert(newCard)
            target = newCard
        }
        try? context.save()
        PeriodCoordinator.reprojectCreditCard(item: target, context: context, exchangeRate: rateStore.currentRate ?? 0, dateRule: dateRule)
        dismiss()
    }
}
