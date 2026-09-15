import SwiftUI
import SwiftData
import AppleAppLabUI

/// "Ingresos recurrentes" / "Gastos recurrentes" — DESIGN_LIQUID.md: two screens, each
/// filtering `RecurringItem` by `kind`; the "+" button creates that kind directly, no picker.
struct RecurringListView: View {
    let kind: LineKind

    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore
    @Query(sort: \RecurringItem.title) private var allItems: [RecurringItem]

    @State private var editingItem: RecurringItem?
    @State private var isPresentingNew = false

    // "Inversiones" (feature #12) reuses `RecurringItem` but has its own screen (`InvestmentsView`)
    // — excluded here per TRD.
    private var items: [RecurringItem] { allItems.filter { $0.kind == kind && $0.category != .investment } }

    private var title: String { kind == .income ? "Ingresos recurrentes" : "Gastos recurrentes" }
    private var emptyIcon: String { kind == .income ? "arrow.down.circle" : "arrow.up.circle" }

    var body: some View {
        Group {
            if items.isEmpty {
                LabEmptyState(
                    icon: emptyIcon,
                    title: kind == .income ? "Sin ingresos recurrentes todavía" : "Sin gastos recurrentes todavía",
                    message: kind == .income
                        ? "Agrega tu sueldo u otro ingreso fijo para proyectarlo automáticamente"
                        : "Agrega renta, un préstamo u otro gasto fijo para proyectarlo automáticamente",
                    config: PatternConfig(accentColor: .accentColor)
                )
            } else {
                List {
                    ForEach(items) { item in
                        Button {
                            editingItem = item
                        } label: {
                            row(for: item)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                PeriodCoordinator.deleteRecurring(item, context: context, exchangeRate: rateStore.currentRate ?? 0)
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                            Button {
                                editingItem = item
                            } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isPresentingNew = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $isPresentingNew) {
            RecurringEditSheet(item: nil, fixedKind: kind)
        }
        .sheet(item: $editingItem) { item in
            RecurringEditSheet(item: item, fixedKind: kind)
        }
    }

    private func row(for item: RecurringItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: emptyIcon)
                .foregroundStyle(kind == .income ? .green : .red)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).foregroundStyle(.primary)
                Text(frequencyDescription(item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.amount.currencyString(currency: item.currency))
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
    }

    private func frequencyDescription(_ item: RecurringItem) -> String {
        let base: String
        switch item.frequency {
        case .biweekly: base = "Cada quincena"
        case .monthlyOnDay(let day): base = "Día \(day)"
        case .once(let date): base = "Una vez, \(date.formatted(date: .abbreviated, time: .omitted))"
        }
        if let endDate = item.endDate {
            return "\(base) · hasta \(endDate.formatted(.dateTime.month(.abbreviated).year()))"
        }
        return base
    }
}

private enum FrequencyKind: String, CaseIterable, Identifiable {
    case biweekly = "Cada quincena"
    case monthlyOnDay = "Mensual"
    case once = "Una sola vez"
    var id: String { rawValue }
}

private struct RecurringEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore
    @Environment(\.dismiss) private var dismiss

    let item: RecurringItem?
    /// Preselected and hidden from the form — the caller (Ingresos/Gastos recurrentes) is
    /// itself the type picker; showing a second one inside the sheet would be redundant.
    let fixedKind: LineKind

    @State private var title: String
    @State private var amount: Decimal
    @State private var currency: Currency
    @State private var frequencyKind: FrequencyKind
    @State private var monthlyDay: Int
    @State private var onceDate: Date
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var isActive: Bool

    init(item: RecurringItem?, fixedKind: LineKind) {
        self.item = item
        self.fixedKind = fixedKind
        _title = State(initialValue: item?.title ?? "")
        _amount = State(initialValue: item?.amount ?? 0)
        _currency = State(initialValue: item?.currency ?? .usd)
        _startDate = State(initialValue: item?.startDate ?? .now)
        _hasEndDate = State(initialValue: item?.endDate != nil)
        _endDate = State(initialValue: item?.endDate ?? .now)
        _isActive = State(initialValue: item?.isActive ?? true)

        switch item?.frequency ?? .biweekly {
        case .biweekly:
            _frequencyKind = State(initialValue: .biweekly)
            _monthlyDay = State(initialValue: 1)
            _onceDate = State(initialValue: .now)
        case .monthlyOnDay(let day):
            _frequencyKind = State(initialValue: .monthlyOnDay)
            _monthlyDay = State(initialValue: day)
            _onceDate = State(initialValue: .now)
        case .once(let date):
            _frequencyKind = State(initialValue: .once)
            _monthlyDay = State(initialValue: 1)
            _onceDate = State(initialValue: date)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabTextField(placeholder: "Descripción", text: $title, config: PatternConfig(accentColor: .accentColor))
                    HStack {
                        TextField("Monto", value: $amount, format: .number.precision(.fractionLength(2)))
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
                }

                Section("Frecuencia") {
                    Picker("Frecuencia", selection: $frequencyKind) {
                        ForEach(FrequencyKind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    switch frequencyKind {
                    case .biweekly:
                        EmptyView()
                    case .monthlyOnDay:
                        Stepper("Día del mes: \(monthlyDay)", value: $monthlyDay, in: 1...31)
                    case .once:
                        DatePicker("Fecha", selection: $onceDate, displayedComponents: .date)
                    }
                }

                Section {
                    DatePicker("Inicio", selection: $startDate, displayedComponents: .date)
                    Toggle("Tiene fecha de fin", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("Fin", selection: $endDate, displayedComponents: .date)
                    }
                    Toggle("Activo", isOn: $isActive)
                }
            }
            .navigationTitle(item == nil ? "Nuevo" : "Editar")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(title.isEmpty || !ValidationRange.amount.contains(amount) || !ValidationRange.dayOfMonth.contains(monthlyDay))
                }
            }
        }
    }

    private var resolvedFrequency: RecurringFrequency {
        switch frequencyKind {
        case .biweekly: .biweekly
        case .monthlyOnDay: .monthlyOnDay(monthlyDay)
        case .once: .once(onceDate)
        }
    }

    private func save() {
        let resolvedEndDate = hasEndDate ? endDate : nil
        let target: RecurringItem
        if let item {
            item.title = title
            item.amount = amount
            item.currency = currency
            item.frequency = resolvedFrequency
            // Normalize at the DatePicker→model boundary (TRD "Decisiones de Swift" —
            // Fechas): every save goes through `civilStartDate`/`civilEndDate` so the
            // persisted `Date` is always local-midnight for its civil day, never carrying
            // a stray time-of-day component forward.
            item.civilStartDate = CivilDate(from: startDate, calendar: .current)
            item.civilEndDate = resolvedEndDate.map { CivilDate(from: $0, calendar: .current) }
            item.isActive = isActive
            target = item
        } else {
            let newItem = RecurringItem(kind: fixedKind, title: title, amount: amount, currency: currency, frequency: resolvedFrequency, startDate: startDate, endDate: resolvedEndDate, isActive: isActive)
            context.insert(newItem)
            target = newItem
        }
        try? context.save()
        // Bug fixed (Avie): reproject onto every already-materialized quincena — not just
        // update lines that already existed — and recompute the carry-over chain.
        PeriodCoordinator.reprojectRecurring(item: target, context: context, exchangeRate: rateStore.currentRate ?? 0)
        dismiss()
    }
}
