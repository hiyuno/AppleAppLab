import SwiftUI
import SwiftData
import AppleAppLabUI

struct SubscriptionsView: View {
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore
    @Query(sort: \Subscription.name) private var allSubscriptions: [Subscription]

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
            Image(systemName: iconName(for: subscription.category))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name)
                    .foregroundStyle(.primary)
                Text("Día \(subscription.paymentDay) · \(subscription.category.rawValue)")
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

    private func iconName(for category: SubscriptionCategory) -> String {
        switch category {
        case .tools: "wrench.and.screwdriver"
        case .entertainment: "play.tv"
        case .apartment: "house"
        case .work: "briefcase"
        case .personal: "person"
        case .hobby: "paintpalette"
        case .investment: "chart.line.uptrend.xyaxis"
        }
    }
}

private struct SubscriptionEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore
    @Environment(\.dismiss) private var dismiss

    let subscription: Subscription?

    @State private var name: String
    @State private var price: Decimal
    @State private var currency: Currency
    @State private var paymentDay: Int
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var card: String
    @State private var category: SubscriptionCategory

    init(subscription: Subscription?) {
        self.subscription = subscription
        _name = State(initialValue: subscription?.name ?? "")
        _price = State(initialValue: subscription?.price ?? 0)
        _currency = State(initialValue: subscription?.currency ?? .usd)
        _paymentDay = State(initialValue: subscription?.paymentDay ?? 1)
        _startDate = State(initialValue: subscription?.startDate ?? .now)
        _hasEndDate = State(initialValue: subscription?.endDate != nil)
        _endDate = State(initialValue: subscription?.endDate ?? .now)
        _card = State(initialValue: subscription?.card ?? "")
        _category = State(initialValue: subscription?.category ?? .tools)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $name)
                    HStack {
                        TextField("Precio", value: $price, format: .number.precision(.fractionLength(2)))
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
                    Stepper("Día de pago: \(paymentDay)", value: $paymentDay, in: 1...31)
                }

                Section {
                    DatePicker("Inicio", selection: $startDate, displayedComponents: .date)
                    Toggle("Tiene fecha de fin", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("Fin", selection: $endDate, displayedComponents: .date)
                    }
                }

                Section {
                    TextField("Tarjeta", text: $card)
                    Picker("Categoría", selection: $category) {
                        ForEach(SubscriptionCategory.allCases, id: \.self) { Text($0.rawValue).tag($0) }
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
                        .disabled(name.isEmpty || !ValidationRange.amount.contains(price) || !ValidationRange.dayOfMonth.contains(paymentDay))
                }
            }
        }
    }

    private func save() {
        let resolvedEndDate = hasEndDate ? endDate : nil
        if let subscription {
            subscription.name = name
            subscription.price = price
            subscription.currency = currency
            subscription.paymentDay = paymentDay
            // Normalize at the DatePicker→model boundary (TRD "Decisiones de Swift" —
            // Fechas): every save goes through `civilStartDate`/`civilEndDate`.
            subscription.civilStartDate = CivilDate(from: startDate, calendar: .current)
            subscription.civilEndDate = resolvedEndDate.map { CivilDate(from: $0, calendar: .current) }
            subscription.card = card
            subscription.category = category
        } else {
            let newSubscription = Subscription(name: name, price: price, currency: currency, paymentDay: paymentDay, startDate: startDate, endDate: resolvedEndDate, card: card, kind: .subscription, category: category)
            context.insert(newSubscription)
        }
        try? context.save()
        // Bug fixed (Avie): recompute the combined "Payments" line across every
        // already-materialized quincena, then propagate the carry-over chain.
        PeriodCoordinator.reprojectSubscription(kind: .subscription, context: context, exchangeRate: rateStore.currentRate ?? 0)
        dismiss()
    }
}
