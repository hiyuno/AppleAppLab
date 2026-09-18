import SwiftUI
import SwiftData

/// Same pattern as `CreditCardPaymentsSheet` (see that file): opens from the aggregated
/// "Investments" row in `PeriodView` — each row here is a full `LineItemRow` (editable amount,
/// palomita, the green-tint lock on `isPaid == true`), no reinvented editing UI. Unlike Credit
/// Cards, investments have no "suggested minimum payment" concept, so there's no caption above
/// each row.
struct InvestmentPaymentsSheet: View {
    let lines: [LineItem]
    let exchangeRate: Decimal?
    let onDelete: (LineItem) -> Void
    let onQuickCommit: () -> Void
    let onToggleActive: (LineItem) -> Void
    let onTogglePaid: (LineItem) -> Void

    @Environment(\.dismiss) private var dismiss

    private var total: Decimal {
        lines.filter(\.isActive).reduce(Decimal(0)) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(lines) { line in
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
            .navigationTitle("Investments")
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
