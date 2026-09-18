import SwiftUI

/// Custom component — not in AppleAppLabUI's catalog (PATTERNS.md has no "large colored
/// total" component). Documented in PROJECT_LEARNINGS.md as a generalization candidate.
struct SobranteBadge: View {
    let sobrante: Decimal

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var status: SobranteStatus { SobranteStatus(sobrante: sobrante) }

    // Coordinator (2026-09-16): exact Figma hex for the positive/green state — neither
    // background nor text is a pure system color (a prior pass wrongly assumed white text).
    // Adjusted/negative are unchanged (`.yellow`/`.red` from mockup round 4).
    private static let positiveBackground = Color(red: 0x00 / 255.0, green: 0x63 / 255.0, blue: 0x38 / 255.0) // #006338
    private static let positiveText = Color(red: 0x01 / 255.0, green: 0xF9 / 255.0, blue: 0x8E / 255.0) // #01F98E

    private var color: Color {
        switch status {
        case .positive: Self.positiveBackground
        case .adjusted: .yellow
        case .negative: .red
        }
    }

    // Coordinator (2026-09-15, mockup round 4): the badge is now a SOLID color pill (fully
    // filled `.green`/`.yellow`/`.red`, not a tinted-translucent one) with contrasting text —
    // black on yellow (unreadable white-on-yellow stays forbidden), red stays white text.
    // Green (2026-09-16): exact Figma text color, not pure white — see `positiveText` above.
    private var textColor: Color {
        switch status {
        case .positive: Self.positiveText
        case .adjusted: .black
        case .negative: .white
        }
    }

    private var statusText: String {
        switch status {
        case .positive: String(localized: "sobrante_status_positive_a11y", defaultValue: "positive, green")
        case .adjusted: String(localized: "sobrante_status_adjusted_a11y", defaultValue: "adjusted, yellow")
        case .negative: String(localized: "sobrante_status_negative_a11y", defaultValue: "negative, red")
        }
    }

    private var animation: Animation? {
        reduceMotion ? .none : .smooth(duration: 0.3)
    }

    var body: some View {
        // Coordinator (2026-09-15, Figma tSUzh4zfCpDPYT5A88otst node 8:2): single horizontal
        // row instead of label-above-amount — label and amount both take the status color now
        // (previously the label stayed `.secondary` regardless of status).
        HStack(alignment: .center) {
            // Coordinator (2026-09-16): Title Case, not all-caps (Figma) — DESIGN_LIQUID.md
            // §"Badge de sobrante" (line ~519): 17pt Semibold, no longer `.caption2`/tracking.
            // Also unified with `SummaryPanel`'s "Next Month" label (coordinator, same round,
            // side-by-side comparison) — both use this exact token now. `.center` alignment
            // (was `.firstTextBaseline`) so the label sits centered against the large amount,
            // not pinned to its baseline.
            // Coordinator (2026-09-17): 8-style typography library — 17pt Semibold is `h3`
            // (`.headline`, already Semibold by default), not `.body` + a manual weight
            // override. Visually identical (both render 17pt Semibold), just the correct
            // semantic token per DESIGN_LIQUID.md's closed table.
            Text(String(localized: "sobrante_label", defaultValue: "Surplus"))
                .font(.headline)
                .foregroundStyle(textColor)

            Spacer()

            // HIG #2: `.largeTitle` scales with Dynamic Type — a fixed `.system(size: 44)`
            // does not, and there is no `relativeTo:` overload for `.system(size:)`.
            Text(sobrante.currencyString())
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(textColor)
                .contentTransition(.numericText(value: Double(truncating: sobrante as NSDecimalNumber)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            // Larry (2026-09-17): matches the rest of the app's cards (LineItemRow,
            // SummaryPanel, LoansView, InvestmentsView, LoanDetailView) — was a one-off 24pt.
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                // Solid fill now (mockup round 4, supersedes the earlier tinted-translucent
                // pill) — Reduce Transparency has nothing left to compensate for.
                .fill(color)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        .animation(animation, value: sobrante)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "sobrante_label", defaultValue: "Surplus"))
        .accessibilityValue("\(sobrante.currencyString()), \(statusText)")
    }
}

#Preview {
    VStack(spacing: 16) {
        SobranteBadge(sobrante: 1240.50)
        SobranteBadge(sobrante: 42.10)
        SobranteBadge(sobrante: -320.00)
    }
    .padding()
}
