import SwiftUI

/// Opens from the aggregated "Essentials"/"Payments"/"Servicios" row in `PeriodView` — same
/// pattern as `CreditCardPaymentsSheet`: each row here is a full `LineItemRow` for a REAL
/// `LineItem` (2026-09-21, per-item refactor — user's explicit request: editing or deactivating
/// one of these in a single quincena must never touch another quincena or the recurring
/// `Subscription` itself). `onStartEditing` routes to the same `LineCaptureSheet` every other
/// generated line uses, so editing here creates a per-period override (`isManuallyEdited`)
/// instead of mutating the source `Subscription`; there's no `onDelete` for the same reason
/// `LineItemRow` never offers one for generated lines — "remove from this quincena only" is
/// `onToggleActive` (swipe/contextMenu "Desactivar"), not a delete. A true permanent removal of
/// the recurring item itself happens from `RecurringListView`, not from here.
struct SubscriptionBreakdownSheet: View {
    let title: String
    let lines: [LineItem]
    let exchangeRate: Decimal?
    let onStartEditing: (LineItem) -> Void
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
                            onStartEditing: { onStartEditing(line) },
                            onDelete: nil,
                            onQuickCommit: onQuickCommit,
                            onToggleActive: { onToggleActive(line) },
                            onTogglePaid: { onTogglePaid(line) }
                        )
                    }

                    HStack {
                        Text(String(localized: "breakdown_total", defaultValue: "Total"))
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
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action_done", defaultValue: "Listo")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
