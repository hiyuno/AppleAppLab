import SwiftUI
import SwiftData
import AppleAppLabUI

struct SubscriptionsView: View {
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore
    @Query(sort: \Subscription.name) private var allSubscriptions: [Subscription]
    @Query(sort: \SubscriptionCategoryItem.sortOrder) private var categories: [SubscriptionCategoryItem]

    @State private var editingSubscription: Subscription?
    @State private var isPresentingNew = false

    private var subscriptions: [Subscription] { allSubscriptions.filter { $0.kind == .subscription } }

    var body: some View {
        Group {
            if subscriptions.isEmpty {
                LabEmptyState(
                    icon: "repeat",
                    title: "Sin suscripciones todavía",
                    message: "Agrega tu primera suscripción para que se calcule sola en cada quincena",
                    config: PatternConfig(accentColor: .accentColor)
                )
            } else {
                List {
                    ForEach(subscriptions) { subscription in
                        Button {
                            editingSubscription = subscription
                        } label: {
                            row(for: subscription)
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
        .navigationTitle("Suscripciones")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingNew = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingNew) {
            SubscriptionEditSheet(subscription: nil)
        }
        .sheet(item: $editingSubscription) { subscription in
            SubscriptionEditSheet(subscription: subscription)
        }
    }

    private func row(for subscription: Subscription) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName(for: subscription.categoryRaw))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name)
                    .foregroundStyle(.primary)
                Text("Día \(subscription.paymentDay) · \(categoryDisplayName(for: subscription.categoryRaw))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(subscription.price.currencyString(currency: subscription.currency))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }

    /// Categories are now user-editable (`SubscriptionCategoryItem`) — `categoryRaw` matches a
    /// live category by `name`, not a fixed enum case anymore. Fallback ("tag") covers a
    /// `Subscription` whose category was renamed/deleted since it was saved.
    private func iconName(for categoryRaw: String) -> String {
        categories.first { $0.name == categoryRaw }?.iconName ?? "tag"
    }

    private func categoryDisplayName(for categoryRaw: String) -> String {
        categories.first { $0.name == categoryRaw }?.name ?? categoryRaw
    }
}

/// Coordinator (2026-09-21): no longer `private` — the unified "Expenses" screen
/// (`RecurringListView(kind: .expense)`) reuses this sheet directly for its own Subscriptions
/// section instead of only being reachable through `SubscriptionsView` (still the Mac sidebar's
/// own screen, untouched).
struct SubscriptionEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SubscriptionCategoryItem.sortOrder) private var categories: [SubscriptionCategoryItem]
    @Query(sort: \CreditCard.name) private var allCards: [CreditCard]

    let subscription: Subscription?

    @State private var name: String
    @State private var price: Decimal
    @State private var currency: Currency
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var creditCardID: UUID?
    @State private var categoryRaw: String

    init(subscription: Subscription?) {
        self.subscription = subscription
        _name = State(initialValue: subscription?.name ?? "")
        _price = State(initialValue: subscription?.price ?? 0)
        _currency = State(initialValue: subscription?.currency ?? .usd)
        _startDate = State(initialValue: subscription?.startDate ?? .now)
        _hasEndDate = State(initialValue: subscription?.endDate != nil)
        _endDate = State(initialValue: subscription?.endDate ?? .now)
        _creditCardID = State(initialValue: subscription?.creditCardID)
        _categoryRaw = State(initialValue: subscription?.categoryRaw ?? SubscriptionCategory.tools.rawValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $name)
                    HStack {
                        // Coordinator (2026-09-17): `LabDecimalField` — centralized fix for
                        // "0.00 isn't a placeholder, has to be deleted by hand".
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
                    // El día de pago se deriva del día del mes de "Inicio" — no hay un
                    // campo separado que pueda desincronizarse (feedback del usuario).
                    DatePicker("Inicio", selection: $startDate, displayedComponents: .date)
                    Toggle("Tiene fecha de fin", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("Fin", selection: $endDate, displayedComponents: .date)
                    }
                }

                Section {
                    Picker("Tarjeta", selection: $creditCardID) {
                        Text("Ninguna").tag(UUID?.none)
                        ForEach(allCards) { card in
                            Text(card.name).tag(card.id as UUID?)
                        }
                    }
                    Picker("Categoría", selection: $categoryRaw) {
                        ForEach(categories) { item in
                            Text(item.name).tag(item.name)
                        }
                    }
                }
            }
            .navigationTitle(subscription == nil ? "Nueva suscripción" : "Editar suscripción")
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

    /// `card: String` stays the persisted, human-readable value `BackupService`/
    /// `SubscriptionImportService` round-trip (see `Subscription.card` doc) — coordinator
    /// (2026-09-17) decision: derive it from the selected `CreditCard.name` so export/backup
    /// keeps a legible value instead of going blank now that the field is a picker, not free
    /// text. Empty when "Ninguna" (nil) is selected.
    private var resolvedCardName: String {
        guard let creditCardID else { return "" }
        return allCards.first { $0.id == creditCardID }?.name ?? ""
    }

    private func save() {
        let resolvedEndDate = hasEndDate ? endDate : nil
        // El stepper "Día de pago" se eliminó (feedback del usuario): el día del mes de
        // "Inicio" es la única fuente de verdad para `paymentDay`.
        let derivedPaymentDay = Calendar.current.component(.day, from: startDate)
        let resolvedItem: Subscription
        if let subscription {
            subscription.name = name
            subscription.price = price
            subscription.currency = currency
            subscription.paymentDay = derivedPaymentDay
            // Normalize at the DatePicker→model boundary (TRD "Decisiones de Swift" —
            // Fechas): every save goes through `civilStartDate`/`civilEndDate`.
            subscription.civilStartDate = CivilDate(from: startDate, calendar: .current)
            subscription.civilEndDate = resolvedEndDate.map { CivilDate(from: $0, calendar: .current) }
            subscription.creditCardID = creditCardID
            subscription.card = resolvedCardName
            subscription.categoryRaw = categoryRaw
            resolvedItem = subscription
        } else {
            let newSubscription = Subscription(name: name, price: price, currency: currency, paymentDay: derivedPaymentDay, startDate: startDate, endDate: resolvedEndDate, card: resolvedCardName, kind: .subscription, category: .tools)
            newSubscription.creditCardID = creditCardID
            newSubscription.categoryRaw = categoryRaw
            context.insert(newSubscription)
            resolvedItem = newSubscription
        }
        try? context.save()
        // Bug fixed (Avie): recompute this subscription's own line across every
        // already-materialized quincena, then propagate the carry-over chain.
        PeriodCoordinator.reprojectSubscription(item: resolvedItem, context: context, exchangeRate: rateStore.currentRate ?? 0)
        dismiss()
    }
}
