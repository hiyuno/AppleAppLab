import SwiftUI

public struct AccentPaletteView: View {
    let palette: AccentPalette

    public init(palette: AccentPalette) {
        self.palette = palette
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                ForEach(palette.swatches) { swatch in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(swatch.color)
                            .frame(height: 32)
                        Text(swatch.label)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 14) {
                semanticSwatch("Subtle", palette.accentSubtle)
                semanticSwatch("Border", palette.accentBorder)
                semanticSwatch("Pressed", palette.accentPressed)
                semanticSwatch("Foreground", palette.accentForeground)
                semanticSwatch("Disabled", palette.accentDisabled)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Generated accent palette, 10 tones from 50 to 900, plus semantic tokens")
    }

    private func semanticSwatch(_ name: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    AccentPaletteView(palette: AccentPalette(base: ColorTokens.accent))
        .padding()
        .frame(width: 420)
}
