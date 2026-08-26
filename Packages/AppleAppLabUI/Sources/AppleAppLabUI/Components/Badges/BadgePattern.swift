import SwiftUI

public enum BadgePattern: InspectablePattern {
    public static let name = "Badges & Tags"
    public static let symbolName = "tag.fill"

    public static let defaultConfig = PatternConfig(
        spacing: 10,
        cornerRadius: 12,
        accentColor: ColorTokens.accent,
        secondaryColor: .green,
        tertiaryColor: .orange
    )

    public static let inspectableProperties: [InspectableProperty] = [
        .spacing(label: "Padding", keyPath: \.spacing, range: 4...16),
        .cornerRadius(label: "Corner Radius", keyPath: \.cornerRadius, range: 4...20),
        .color(label: "Badge 1 Color", keyPath: \.accentColor),
        .color(label: "Badge 2 Color", keyPath: \.secondaryColor),
        .color(label: "Badge 3 Color", keyPath: \.tertiaryColor)
    ]

    public static func preview(config: PatternConfig) -> some View {
        HStack(spacing: config.spacing) {
            LabBadge(text: "New", color: config.accentColor, config: config)
            LabBadge(text: "Active", color: config.secondaryColor, config: config)
            LabBadge(text: "Beta", color: config.tertiaryColor, config: config)
        }
    }
}

#Preview {
    BadgePattern.preview(config: BadgePattern.defaultConfig)
        .padding()
}
