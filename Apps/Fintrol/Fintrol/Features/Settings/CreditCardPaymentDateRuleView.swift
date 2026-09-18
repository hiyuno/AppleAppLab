import SwiftUI

/// Ajustes → Preferencias → "Regla de pago de tarjetas". DESIGN_LIQUID.md § "Ajustes →
/// Preferencias — regla de fecha de pago": the ONLY English text in the whole app, by explicit
/// user decision — the rest of Fintrol's UI is Spanish. `.pickerStyle(.inline)`, not `.menu`,
/// because each option needs room for its own explanation line.
struct CreditCardPaymentDateRuleView: View {
    @AppStorage("fintrol.creditCardPaymentDateRuleKind") private var kindRaw = 2
    @AppStorage("fintrol.creditCardPaymentDateRuleDays") private var days = 5

    var body: some View {
        Form {
            Section {
                Picker("Payment Date Rule", selection: $kindRaw) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("On the payment date")
                        Text("Only avoids interest. Simplest option, no credit score benefit.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(0)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("On the statement/cutoff date")
                        Text("Almost as good as paying early, with no buffer if something goes wrong.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("N days before the cutoff date")
                        Text("Reduces the balance your card issuer reports to the credit bureau — often the best practice for your credit score.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(2)
                }
                .pickerStyle(.inline)

                if kindRaw == 2 {
                    Stepper("\(days) \(days == 1 ? "day" : "days") before cutoff", value: $days, in: 1...15)
                }
            }
        }
        .navigationTitle("Payment Date Rule")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
