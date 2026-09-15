import SwiftUI
import SwiftData
import AppleAppLabUI

/// "Servicios" — home/utility payments (renta, luz, internet, agua, gas, seguro). Same
/// mechanic as Suscripciones (day-of-payment, TRD `Subscription`), own screen/icon/categories
/// (DESIGN_LIQUID.md). Modeled as `Subscription.kind == .service` — see
/// PROJECT_LEARNINGS.md for the modeling decision.
struct ServicesView: View {
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore
    @Query(sort: \Subscription.name) private var allSubscriptions: [Subscription]

    @State private var editingService: Subscription?
    @State private var isPresentingNew = false

    private var services: [Subscription] { allSubscriptions.filter { $0.kind == .service } }

    var body: some View {
        Group {
            if services.isEmpty {
                LabEmptyState(
                    icon: "house.fill",
                    title: "Sin servicios todavía",
                    message: "Agrega renta, luz u otro pago del hogar para que se calcule solo en cada quincena",
                    config: PatternConfig(accentColor: .accentColor)
                )
            } else {
                List {
                    ForEach(services) { service in
                        Button {
                            editingService = service
                        } label: {
                            row(for: service)
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
        }
        .navigationTitle("Servicios")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isPresentingNew = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $isPresentingNew) {
            ServiceEditSheet(service: nil)
        }
        .sheet(item: $editingService) { service in
            ServiceEditSheet(service: service)
        }
    }

    private func row(for service: Subscription) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName(for: service.homeServiceCategory))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .foregroundStyle(.primary)
                Text("Día \(service.paymentDay) · \(service.homeServiceCategory.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(service.price.currencyString(currency: service.currency))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }

    private func iconName(for category: HomeServiceCategory) -> String {
        switch category {
        case .rent: "house"
        case .electricity: "bolt.fill"
        case .internet: "wifi"
        case .water: "drop.fill"
        case .gas: "flame.fill"
        case .insurance: "shield.fill"
        }
    }
}

private struct ServiceEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore
    @Environment(\.dismiss) private var dismiss

    let service: Subscription?

    @State private var name: String
    @State private var price: Decimal
    @State private var currency: Currency
    @State private var paymentDay: Int
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var category: HomeServiceCategory

    init(service: Subscription?) {
        self.service = service
        _name = State(initialValue: service?.name ?? "")
        _price = State(initialValue: service?.price ?? 0)
        _currency = State(initialValue: service?.currency ?? .usd)
        _paymentDay = State(initialValue: service?.paymentDay ?? 1)
        _startDate = State(initialValue: service?.startDate ?? .now)
        _hasEndDate = State(initialValue: service?.endDate != nil)
        _endDate = State(initialValue: service?.endDate ?? .now)
        _category = State(initialValue: service?.homeServiceCategory ?? .rent)
    }

    var body: some View {
        NavigationStack {
            Form {
                // No card field — a home service is never paid by a specific card the way
                // a subscription is (DESIGN_LIQUID.md).
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
                    Picker("Categoría", selection: $category) {
                        ForEach(HomeServiceCategory.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }
            }
            .navigationTitle(service == nil ? "Nuevo servicio" : "Editar servicio")
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
        if let service {
            service.name = name
            service.price = price
            service.currency = currency
            service.paymentDay = paymentDay
            // Normalize at the DatePicker→model boundary (TRD "Decisiones de Swift" —
            // Fechas): every save goes through `civilStartDate`/`civilEndDate`.
            service.civilStartDate = CivilDate(from: startDate, calendar: .current)
            service.civilEndDate = resolvedEndDate.map { CivilDate(from: $0, calendar: .current) }
            service.homeServiceCategory = category
        } else {
            let newService = Subscription(name: name, price: price, currency: currency, paymentDay: paymentDay, startDate: startDate, endDate: resolvedEndDate, homeServiceCategory: category)
            context.insert(newService)
        }
        try? context.save()
        // Bug fixed (Avie): recompute the combined "Servicios" line across every
        // already-materialized quincena, then propagate the carry-over chain.
        PeriodCoordinator.reprojectSubscription(kind: .service, context: context, exchangeRate: rateStore.currentRate ?? 0)
        dismiss()
    }
}
