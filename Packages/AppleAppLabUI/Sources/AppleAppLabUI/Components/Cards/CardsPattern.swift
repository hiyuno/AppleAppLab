import SwiftUI

public enum CardsPattern: InspectablePattern {
    public static let name = "Cards"
    public static let symbolName = "rectangle.on.rectangle"

    public static let defaultConfig = PatternConfig(
        spacing: 10,
        cornerRadius: 24,
        accentColor: ColorTokens.accent,
        secondaryColor: .teal,
        tertiaryColor: .orange,
        accentOutlineColor: ColorTokens.accent,
        secondaryOutlineColor: .teal,
        tertiaryOutlineColor: .orange,
        variant: "Nested"
    )

    public static let inspectableProperties: [InspectableProperty] = [
        .spacing(label: "Inner Padding", keyPath: \.spacing, range: 6...50),
        .picker(label: "Card Type", keyPath: \.variant, options: ["Nested", "Nested (No Content)", "Dashboard"]),
        .spacing(label: "Border Width", keyPath: \.borderWidth, range: 0...3),
        .duration(label: "Surface Opacity", keyPath: \.surfaceOpacityMultiplier, range: 0.2...2.0),

        .section("Card 1"),
        .color(label: "Background Color", keyPath: \.accentColor),
        .color(label: "Outline Color", keyPath: \.accentOutlineColor),

        .section("Card 2"),
        .color(label: "Background Color", keyPath: \.secondaryColor),
        .color(label: "Outline Color", keyPath: \.secondaryOutlineColor),

        .section("Card 3"),
        .color(label: "Background Color", keyPath: \.tertiaryColor),
        .color(label: "Outline Color", keyPath: \.tertiaryOutlineColor)
    ]

    public static func preview(config: PatternConfig) -> some View {
        CardsPreview(config: config)
    }
}

private struct CardsPreview: View {
    let config: PatternConfig

    var body: some View {
        Group {
            switch config.variant {
            case "Dashboard":
                LabDashboardCards(
                    containerColor: config.accentColor,
                    listColor: config.secondaryColor,
                    featuredColor: config.tertiaryColor,
                    listOutlineColor: config.secondaryOutlineColor,
                    featuredOutlineColor: config.tertiaryOutlineColor,
                    config: config
                )
                .frame(width: 420, height: 260)
            case "Nested (No Content)":
                LabNestedCard(
                    title: "Golden Gate",
                    subtitle: "San Francisco, CA",
                    outerColor: config.accentColor,
                    middleColor: config.secondaryColor,
                    innerColor: config.tertiaryColor,
                    outerOutlineColor: config.accentOutlineColor,
                    middleOutlineColor: config.secondaryOutlineColor,
                    innerOutlineColor: config.tertiaryOutlineColor,
                    showImage: false,
                    showText: false,
                    config: config
                )
            default:
                LabNestedCard(
                    title: "Golden Gate",
                    subtitle: "San Francisco, CA",
                    outerColor: config.accentColor,
                    middleColor: config.secondaryColor,
                    innerColor: config.tertiaryColor,
                    outerOutlineColor: config.accentOutlineColor,
                    middleOutlineColor: config.secondaryOutlineColor,
                    innerOutlineColor: config.tertiaryOutlineColor,
                    config: config
                )
            }
        }
    }
}

#Preview {
    CardsPattern.preview(config: CardsPattern.defaultConfig)
        .padding()
}
