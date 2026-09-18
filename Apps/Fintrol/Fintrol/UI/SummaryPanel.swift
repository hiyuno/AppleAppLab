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

    var body: some View {
        // Coordinator (2026-09-17): "Mandar" moves to AFTER "Next Month" (was between SOBRANTE
        // and Next Month, i.e. first in this column — now last).
        VStack(alignment: .leading, spacing: 8) {
            NextMonthCard(nextMonth: nextMonth)

            // Coordinator (2026-09-17, corrected — restored with the right value): loose
            // titles need an extra indent past the screen's outer padding to align with the
            // text INSIDE cards (their own internal padding starts further in than the card's
            // outer edge) — same +8pt as "TOTAL INCOME"/"TOTAL EXPENSES" and the section
            // headers in `PeriodView.swift`, not the +16pt this row carried before (that
            // overshot past the card-text alignment point).
            row(title: String(localized: "summary_send_label", defaultValue: "To Send"), value: mandar.currencyString() + " USD")
                .padding(.horizontal, 8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "summary_panel_a11y", defaultValue: "Summary panel"))
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

/// "Next Month" card — extracted (Woz, feature "Home", 2026-09-17) so `PeriodPreviewCard` can
/// reuse it verbatim; Jonny's design excludes "Mandar"/"To Send" from that preview (it's an
/// operational action, not a summary datum), so the whole panel isn't a fit there, only this
/// block. Behavior/visuals unchanged from what `SummaryPanel` inlined before.
struct NextMonthCard: View {
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
        HStack(alignment: .center) {
            // Coordinator (2026-09-16): unified with `SobranteBadge`'s "Sobrante" label —
            // same 17pt Semibold token, was `.subheadline` here (visibly different
            // size/weight side-by-side).
            // Coordinator (2026-09-17): 8-style library — that token is `h3` (`.headline`),
            // mirrors the same fix in `SobranteBadge`. The amount stays `p big` (`.body` +
            // Semibold) per the coordinator's explicit mapping for this element.
            Text(String(localized: "summary_next_month_label", defaultValue: "Next Month"))
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
}
