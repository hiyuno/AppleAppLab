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

    // Coordinator (2026-09-16): same exact Figma hex as `SobranteBadge`'s positive state —
    // neither background nor text is pure white/green. Adjusted/negative unchanged.
    private static let positiveBackground = Color(red: 0x00 / 255.0, green: 0x63 / 255.0, blue: 0x38 / 255.0) // #006338
    private static let positiveText = Color(red: 0x01 / 255.0, green: 0xF9 / 255.0, blue: 0x8E / 255.0) // #01F98E

    private var nextMonthColor: Color {
        switch nextMonthStatus {
        case .positive: Self.positiveBackground
        case .adjusted: .yellow
        case .negative: .red
        }
    }

    private var nextMonthTextColor: Color {
        switch nextMonthStatus {
        case .positive: Self.positiveText
        case .adjusted: .black
        case .negative: .white
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(title: "Mandar", value: mandar.currencyString() + " USD")
                .padding(.horizontal, 16)

            HStack(alignment: .center) {
                // Coordinator (2026-09-16): unified with `SobranteBadge`'s "Sobrante" label —
                // same 17pt Semibold token, was `.subheadline` here (visibly different
                // size/weight side-by-side).
                // Coordinator (2026-09-17): 8-style library — that token is `h3` (`.headline`),
                // mirrors the same fix in `SobranteBadge`. The amount stays `p big` (`.body` +
                // Semibold) per the coordinator's explicit mapping for this element.
                Text("Next Month")
                    .font(.headline)
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
