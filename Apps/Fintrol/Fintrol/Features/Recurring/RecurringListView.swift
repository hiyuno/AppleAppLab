import SwiftUI
import SwiftData
import AppleAppLabUI

/// "Income" / "Expenses" — DESIGN_LIQUID.md: two screens, each filtering `RecurringItem` by
/// `kind`. Coordinator (2026-09-21, user's request): Expenses is no longer just plain
/// `RecurringItem` rows — Services and Subscriptions (both `Subscription` records) live inline
/// here too, as their own sections, instead of behind separate navigation. The "+" button on
/// Expenses asks which of the three a new entry is; Income has no such picker (Services/
/// Subscriptions are expense-only).
struct RecurringListView: View {
    let kind: LineKind

    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore
    @Query(sort: \RecurringItem.title) private var allItems: [RecurringItem]
    @Query(sort: \Subscription.name) private var allSubscriptions: [Subscription]
    @Query(sort: \SubscriptionCategoryItem.sortOrder) private var categories: [SubscriptionCategoryItem]

    @State private var editingItem: RecurringItem?
    @State private var isPresentingNewItem = false
    @State private var editingService: Subscription?
    @State private var isPresentingNewService = false
    @State private var editingSubscription: Subscription?
    @State private var isPresentingNewSubscription = false
    @State private var editingEssential: Subscription?
    @State private var isPresentingNewEssential = false
    @State private var isPresentingNewChoice = false

    // "Inversiones" (feature #12) reuses `RecurringItem` but has its own screen (`InvestmentsView`)
    // — excluded here per TRD.
    private var items: [RecurringItem] { allItems.filter { $0.kind == kind && $0.category != .investment } }
    private var services: [Subscription] { allSubscriptions.filter { $0.kind == .service } }
    private var subscriptions: [Subscription] { allSubscriptions.filter { $0.kind == .subscription } }
    private var essentials: [Subscription] { allSubscriptions.filter { $0.kind == .essential } }

    private var title: String { kind == .income ? "Income" : "Expenses" }
    private var emptyIcon: String { kind == .income ? "arrow.down.circle" : "arrow.up.circle" }

    private var isCompletelyEmpty: Bool {
        kind == .income ? items.isEmpty : (items.isEmpty && services.isEmpty && subscriptions.isEmpty && essentials.isEmpty)
    }

    var body: some View {
        Group {
            if isCompletelyEmpty {
                LabEmptyState(
                    icon: emptyIcon,
                    title: kind == .income ? "Sin ingresos recurrentes todavía" : "Sin gastos recurrentes todavía",
                    message: kind == .income
                        ? "Agrega tu sueldo u otro ingreso fijo para proyectarlo automáticamente"
                        : "Agrega un servicio, una suscripción u otro gasto fijo para proyectarlo automáticamente",
                    config: PatternConfig(accentColor: .accentColor)
                )
            } else {
                List {
                    if kind == .expense {
                        // Coordinator (2026-09-21, user's request): Essentials first — the
                        // section order users see most often should lead, ahead of Services/
                        // Subscriptions.
                        if !essentials.isEmpty {
                            Section("Essentials") {
                                ForEach(essentials) { essential in
                                    Button {
                                        editingEssential = essential
                                    } label: {
                                        essentialRow(for: essential)
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            PeriodCoordinator.deleteSubscription(essential, context: context, exchangeRate: rateStore.currentRate ?? 0)
                                        } label: {
                                            Label("Eliminar", systemImage: "trash")
                                        }
                                        Button {
                                            editingEssential = essential
                                        } label: {
                                            Label("Editar", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                }
                            }
                        }

                        if !services.isEmpty {
                            Section("Services") {
                                ForEach(services) { service in
                                    Button {
                                        editingService = service
                                    } label: {
                                        serviceRow(for: service)
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            PeriodCoordinator.deleteSubscription(service, context: context, exchangeRate: rateStore.currentRate ?? 0)
                                        } label: {
                                            Label("Eliminar", systemImage: "trash")
                                        }
                                        Button {
                                            editingService = service
                                        } label: {
                                            Label("Editar", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                }
                            }
                        }

                        if !subscriptions.isEmpty {
                            Section("Subscriptions") {
                                ForEach(subscriptions) { subscription in
                                    Button {
                                        editingSubscription = subscription
                                    } label: {
                                        subscriptionRow(for: subscription)
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            PeriodCoordinator.deleteSubscription(subscription, context: context, exchangeRate: rateStore.currentRate ?? 0)
                                        } label: {
                                            Label("Eliminar", systemImage: "trash")
                                        }
                                        Button {
                                            editingSubscription = subscription
                                        } label: {
                                            Label("Editar", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                }
                            }
                        }
                    }

                    if !items.isEmpty {
                        Section {
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
                        } header: {
                            if kind == .expense {
                                Text("Others")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if kind == .expense {
                        isPresentingNewChoice = true
                    } else {
                        isPresentingNewItem = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        // Coordinator (2026-09-21): Expenses' "+" is a type picker, not a direct create — three
        // different models/sheets live on this one screen now, so the user says up front which
        // one a new entry is instead of navigating to a separate screen per type first.
        .confirmationDialog("Nuevo gasto", isPresented: $isPresentingNewChoice, titleVisibility: .visible) {
            Button("Service") { isPresentingNewService = true }
            Button("Subscription") { isPresentingNewSubscription = true }
            Button("Essential") { isPresentingNewEssential = true }
            Button("Other") { isPresentingNewItem = true }
            Button("Cancelar", role: .cancel) {}
        }
        .sheet(isPresented: $isPresentingNewItem) {
            RecurringEditSheet(item: nil, fixedKind: kind)
        }
        .sheet(item: $editingItem) { item in
            RecurringEditSheet(item: item, fixedKind: kind)
        }
        .sheet(isPresented: $isPresentingNewService) {
            ServiceEditSheet(service: nil)
        }
        .sheet(item: $editingService) { service in
            ServiceEditSheet(service: service)
        }
        .sheet(isPresented: $isPresentingNewSubscription) {
            SubscriptionEditSheet(subscription: nil)
        }
        .sheet(item: $editingSubscription) { subscription in
            SubscriptionEditSheet(subscription: subscription)
        }
        .sheet(isPresented: $isPresentingNewEssential) {
            EssentialEditSheet(essential: nil)
        }
        .sheet(item: $editingEssential) { essential in
            EssentialEditSheet(essential: essential)
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

    private func serviceRow(for service: Subscription) -> some View {
        HStack(spacing: 12) {
            Image(systemName: serviceIconName(for: service.homeServiceCategory))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(service.name).foregroundStyle(.primary)
                Text("Día \(service.paymentDay) · \(service.homeServiceCategory.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(service.price.currencyString(currency: service.currency))
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
    }

    private func subscriptionRow(for subscription: Subscription) -> some View {
        HStack(spacing: 12) {
            Image(systemName: subscriptionIconName(for: subscription.categoryRaw))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name).foregroundStyle(.primary)
                Text("Día \(subscription.paymentDay) · \(subscription.categoryRaw)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(subscription.price.currencyString(currency: subscription.currency))
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
    }

    private func essentialRow(for essential: Subscription) -> some View {
        HStack(spacing: 12) {
            Image(systemName: essential.essentialCategory.iconName)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(essential.name).foregroundStyle(.primary)
                Text("\(essential.isBiweekly ? "Cada quincena" : "Día \(essential.paymentDay)") · \(essential.essentialCategory.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(essential.price.currencyString(currency: essential.currency))
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
    }

    private func serviceIconName(for category: HomeServiceCategory) -> String {
        switch category {
        case .rent: "house"
        case .electricity: "bolt.fill"
        case .internet: "wifi"
        case .water: "drop.fill"
        case .gas: "flame.fill"
        case .insurance: "shield.fill"
        }
    }

    /// Categories are user-editable (`SubscriptionCategoryItem`) — `categoryRaw` matches a live
    /// category by `name`, not a fixed enum case. Fallback ("tag") covers a `Subscription` whose
    /// category was renamed/deleted since it was saved.
    private func subscriptionIconName(for categoryRaw: String) -> String {
        categories.first { $0.name == categoryRaw }?.iconName ?? "tag"
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
            _onceDate = State(initialValue: .now)
        case .monthlyOnDay:
            _frequencyKind = State(initialValue: .monthlyOnDay)
            _onceDate = State(initialValue: .now)
        case .once(let date):
            _frequencyKind = State(initialValue: .once)
            _onceDate = State(initialValue: date)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabTextField(placeholder: "Descripción", text: $title, config: PatternConfig(accentColor: .accentColor))
                    HStack {
                        // Coordinator (2026-09-17): `LabDecimalField` — centralized fix for
                        // "0.00 isn't a placeholder, has to be deleted by hand".
                        LabDecimalField(placeholder: "Monto", value: $amount)
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
                        EmptyView()
                    case .once:
                        DatePicker("Fecha", selection: $onceDate, displayedComponents: .date)
                    }
                }

                Section {
                    // El día de pago mensual se deriva del día del mes de "Inicio" — no hay
                    // un campo separado que pueda desincronizarse (feedback del usuario).
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
                        .disabled(title.isEmpty || !ValidationRange.amount.contains(amount))
                }
            }
        }
    }

    private var resolvedFrequency: RecurringFrequency {
        switch frequencyKind {
        case .biweekly: .biweekly
        // El día de pago mensual se deriva del día del mes de "Inicio" (feedback del usuario).
        case .monthlyOnDay: .monthlyOnDay(Calendar.current.component(.day, from: startDate))
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

/// Coordinator (2026-09-21, user's request): "Essentials" — everyday budgeted spend (food, gas/
/// transportation, clothing, tech, furniture, fun). Mirrors `ServiceEditSheet` in
/// `ServicesView.swift` exactly — same `Subscription`-backed mechanic (payment day derived from
/// "Inicio", one aggregated line per half) — just an `EssentialCategory` picker instead of
/// `HomeServiceCategory`, and no card field (matches Service, not Subscription — essentials
/// aren't tied to a specific credit card the way a subscription can be).
struct EssentialEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore
    @Environment(\.dismiss) private var dismiss

    let essential: Subscription?

    @State private var name: String
    @State private var price: Decimal
    @State private var currency: Currency
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var category: EssentialCategory
    @State private var isBiweekly: Bool

    init(essential: Subscription?) {
        self.essential = essential
        _name = State(initialValue: essential?.name ?? "")
        _price = State(initialValue: essential?.price ?? 0)
        _currency = State(initialValue: essential?.currency ?? .usd)
        _isBiweekly = State(initialValue: essential?.isBiweekly ?? false)
        _startDate = State(initialValue: essential?.startDate ?? .now)
        _hasEndDate = State(initialValue: essential?.endDate != nil)
        _endDate = State(initialValue: essential?.endDate ?? .now)
        _category = State(initialValue: essential?.essentialCategory ?? .food)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $name)
                    HStack {
                        LabDecimalField(placeholder: "Precio", value: $price)
                        Picker("Moneda", selection: $currency) {
                            Text("USD").tag(Currency.usd)
                            Text("MXN").tag(Currency.mxn)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }
                }

                Section {
                    Picker("Frecuencia", selection: $isBiweekly) {
                        Text("Cada mes").tag(false)
                        Text("Cada quincena").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    // El día de pago se deriva del día del mes de "Inicio" — mismo patrón que
                    // Service/Subscription. Con "Cada quincena" el día solo ancla cuándo empieza
                    // a contar (`isVigente`); ya no determina en qué mitad aparece.
                    DatePicker("Inicio", selection: $startDate, displayedComponents: .date)
                    Toggle("Tiene fecha de fin", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("Fin", selection: $endDate, displayedComponents: .date)
                    }
                }

                Section {
                    Picker("Categoría", selection: $category) {
                        ForEach(EssentialCategory.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
            }
            .navigationTitle(essential == nil ? "Nuevo essential" : "Editar essential")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(name.isEmpty || !ValidationRange.amount.contains(price))
                }
            }
        }
    }

    private func save() {
        let resolvedEndDate = hasEndDate ? endDate : nil
        let derivedPaymentDay = Calendar.current.component(.day, from: startDate)
        let resolvedItem: Subscription
        if let essential {
            essential.name = name
            essential.price = price
            essential.currency = currency
            essential.paymentDay = derivedPaymentDay
            essential.civilStartDate = CivilDate(from: startDate, calendar: .current)
            essential.civilEndDate = resolvedEndDate.map { CivilDate(from: $0, calendar: .current) }
            essential.essentialCategory = category
            essential.isBiweekly = isBiweekly
            resolvedItem = essential
        } else {
            let newEssential = Subscription(name: name, price: price, currency: currency, paymentDay: derivedPaymentDay, startDate: startDate, endDate: resolvedEndDate, essentialCategory: category, isBiweekly: isBiweekly)
            context.insert(newEssential)
            resolvedItem = newEssential
        }
        try? context.save()
        PeriodCoordinator.reprojectSubscription(item: resolvedItem, context: context, exchangeRate: rateStore.currentRate ?? 0)
        dismiss()
    }
}
