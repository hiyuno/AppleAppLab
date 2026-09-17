import SwiftUI

/// "Mandar" / "Next Month" — DESIGN_LIQUID.md § Bloques INCOME/EXPENSES (Figma
/// tSUzh4zfCpDPYT5A88otst, node 8:2). "Tipo de cambio" + its "Editar" button were removed
/// entirely; the manual override lives only in Ajustes → Preferencias now
/// (`ExchangeRateSettingsView`). "Mandar" sits loose directly on the background, same
/// "label/value pair over the background" pattern as TOTAL INCOME/EXPENSES. "Next Month" —
/// confirmed against Figma metadata (2026-09-15) — is its own card, same style as an
/// INCOME/EXPENSES line: `AppBackgroundSecondary` (#2A2A2A dark), 20pt continuous radius,
/// 16pt padding.
struct SummaryPanel: View {
    let mandar: Decimal
    let nextMonth: Decimal

    // Coordinator (2026-09-15, mockup round 4): "Next Month" takes the same solid
    // green/yellow/red treatment as SobranteBadge, keyed off its OWN value (it's a projected
    // sobrante for the next quincena, so the same threshold applies) — white text, black only
    // on the yellow variant.
    private var nextMonthStatus: SobranteStatus { SobranteStatus(sobrante: nextMonth) }

    private var nextMonthColor: Color {
        switch nextMonthStatus {
        case .positive: .green
        case .adjusted: .yellow
        case .negative: .red
        }
    }

    private var nextMonthTextColor: Color {
        nextMonthStatus == .adjusted ? .black : .white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(title: "Mandar", value: mandar.currencyString() + " USD")
                .padding(.horizontal, 16)

            HStack {
                Text("Next Month")
                    .font(.subheadline)
                    .foregroundStyle(nextMonthTextColor.opacity(0.8))
                Spacer()
                Text(nextMonth.currencyString())
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(nextMonthTextColor)
            }
            .padding(16)
            .background(nextMonthColor)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
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
