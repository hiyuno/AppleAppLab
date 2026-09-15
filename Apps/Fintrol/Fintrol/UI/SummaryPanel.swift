import SwiftUI

/// "Mandar" / tipo de cambio / "Next Month" panel. Custom component (not in catalog).
struct SummaryPanel: View {
    let mandar: Decimal
    let exchangeRate: Decimal?
    let isRateStale: Bool
    let nextMonth: Decimal
    let onEditRate: () -> Void

    // A11Y #6: `.legibilityWeight == .bold` is what "Aumentar contraste" sets — fall back to
    // an opaque fill instead of Frost so text contrast doesn't depend on what's behind it.
    @Environment(\.legibilityWeight) private var legibilityWeight

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            row(title: "Mandar", value: mandar.currencyString() + " USD")

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tipo de cambio")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(exchangeRate.map { $0.twoDecimalString } ?? "—")
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                    if isRateStale {
                        Text("Usando el último conocido")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Advertencia: usando tipo de cambio anterior")
                    }
                }
                Spacer()
                Button("Editar", action: onEditRate)
                    .font(.body)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .accessibilityLabel("Editar tipo de cambio")
            }

            Divider()

            row(title: "Next Month", value: nextMonth.currencyString(), isSecondary: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(legibilityWeight == .bold ? AnyShapeStyle(Color("AppBackgroundSecondary")) : AnyShapeStyle(.ultraThinMaterial.opacity(0.5)))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Panel de resumen")
    }

    private func row(title: String, value: String, isSecondary: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body.weight(isSecondary ? .regular : .semibold))
                .monospacedDigit()
                .foregroundStyle(isSecondary ? .secondary : .primary)
        }
    }
}
