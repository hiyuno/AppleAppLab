import SwiftUI

/// Custom component — not in AppleAppLabUI's catalog (PATTERNS.md has no "large colored
/// total" component). Documented in PROJECT_LEARNINGS.md as a generalization candidate.
struct SobranteBadge: View {
    let sobrante: Decimal

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var status: SobranteStatus { SobranteStatus(sobrante: sobrante) }

    private var color: Color {
        switch status {
        case .positive: .green
        case .adjusted: .yellow
        case .negative: .red
        }
    }

    private var textColor: Color {
        // Yellow badge always uses black text (DESIGN_LIQUID.md — never white on yellow).
        status == .adjusted ? .black : color
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
        VStack(alignment: .leading, spacing: 4) {
            Text("SOBRANTE")
                .font(.caption2)
                .tracking(1.2)
                .foregroundStyle(.secondary)

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
                // A11Y #12 (Reduce Transparency): swap the tinted-translucent fill for a
                // more opaque one so the color/text contrast doesn't depend on what's behind it.
                .fill(color.opacity(reduceTransparency ? 0.24 : 0.12))
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
