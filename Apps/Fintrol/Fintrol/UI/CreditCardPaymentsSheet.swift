import SwiftUI
import SwiftData

/// DESIGN_LIQUID.md § "Sheet de detalle — Credit Cards Payments": opens from the aggregated
/// "Credit Cards Payments" row in `PeriodView` — each row here is a full `LineItemRow` (same
/// pattern already documented: editable amount, palomita, the green-tint lock on
/// `isPaid == true`), no reinvented editing UI. The "Sugerido: $X" reference sits as a caption
/// above each row, `.caption`/`.secondary`, read-only.
struct CreditCardPaymentsSheet: View {
    let lines: [LineItem]
    let exchangeRate: Decimal?
    let onDelete: (LineItem) -> Void
    let onQuickCommit: () -> Void
    let onToggleActive: (LineItem) -> Void
    let onTogglePaid: (LineItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    // Bug fix (2026-09-21, user report on the sibling Investments sheet — same mixed-currency
    // sum bug applies here too): a card's line can be in MXN (manually switched via
    // contextMenu) — the Total is presented in plain USD, so each line must convert through
    // `CurrencyConversion.toUSD` first, same as `CarryOverEngine.total` does everywhere else.
    private var total: Decimal {
        lines.filter(\.isActive).reduce(Decimal(0)) { partial, line in
            partial + CurrencyConversion.toUSD(amount: line.amount, currency: line.currency, rate: exchangeRate ?? 0)
        }
    }

    private func suggestedText(for line: LineItem) -> String? {
        guard let cardID = line.sourceCreditCardID,
              let card = try? context.fetch(FetchDescriptor<CreditCard>(predicate: #Predicate { $0.id == cardID })).first
        else { return nil }
        let suggested = CreditCardEngine.suggestedMinimumPayment(balance: card.balance, apr: card.apr)
        return "Sugerido: \(suggested.currencyString(currency: .usd))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(lines) { line in
                        VStack(alignment: .leading, spacing: 4) {
                            if let suggestedText = suggestedText(for: line) {
                                Text(suggestedText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                            }
                            LineItemRow(
                                line: line,
                                exchangeRate: exchangeRate,
                                onStartEditing: {},
                                onDelete: line.origin == .manual ? { onDelete(line) } : nil,
                                onQuickCommit: onQuickCommit,
                                onToggleActive: { onToggleActive(line) },
                                onTogglePaid: { onTogglePaid(line) }
                            )
                        }
                    }

                    HStack {
                        Text("Total")
                            .font(.body.weight(.semibold))
                        Spacer()
                        Text(total.currencyString())
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                }
                .padding(16)
            }
            .navigationTitle("Credit Cards Payments")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
