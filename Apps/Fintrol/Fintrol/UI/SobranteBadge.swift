import SwiftUI

/// Custom component — not in AppleAppLabUI's catalog (PATTERNS.md has no "large colored
/// total" component). Documented in PROJECT_LEARNINGS.md as a generalization candidate.
struct SobranteBadge: View {
    let sobrante: Decimal

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var status: SobranteStatus { SobranteStatus(sobrante: sobrante) }

    private var color: Color {
        switch status {
        case .positive: .green
        case .adjusted: .yellow
        case .negative: .red
        }
    }

    // Coordinator (2026-09-15, mockup round 4): the badge is now a SOLID color pill (fully
    // filled `.green`/`.yellow`/`.red`, not a tinted-translucent one) with contrasting text —
    // white on green/red, black on yellow (unreadable white-on-yellow stays forbidden).
    private var textColor: Color {
        status == .adjusted ? .black : .white
    }

    private var statusText: String {
        switch status {
        case .positive: "positivo, verde"
        case .adjusted: "ajustado, amarillo"
        case .negative: "negativo, rojo"
        }
    }

    private var animation: Animation? {
        reduceMotion ? .none : .smooth(duration: 0.3)
    }

    var body: some View {
        // Coordinator (2026-09-15, Figma tSUzh4zfCpDPYT5A88otst node 8:2): single horizontal
        // row instead of label-above-amount — label and amount both take the status color now
        // (previously the label stayed `.secondary` regardless of status).
        HStack(alignment: .firstTextBaseline) {
            Text("SOBRANTE")
                .font(.caption2)
                .tracking(1.2)
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
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                // Solid fill now (mockup round 4, supersedes the earlier tinted-translucent
                // pill) — Reduce Transparency has nothing left to compensate for.
                .fill(color)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        .animation(animation, value: sobrante)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sobrante")
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
