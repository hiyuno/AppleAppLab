import SwiftUI

public enum EmptyStatesPattern: InspectablePattern {
    public static let name = "Empty states"
    public static let symbolName = "tray"

    public static let defaultConfig = PatternConfig(
        spacing: 12,
        accentColor: ColorTokens.accent
    )

    public static let inspectableProperties: [InspectableProperty] = [
        .spacing(label: "Content Spacing", keyPath: \.spacing, range: 4...32)
    ]

    public static func preview(config: PatternConfig) -> some View {
        LabEmptyState(icon: "tray", title: "No Items", message: "Nothing here yet.", config: config)
    }
}

#Preview {
    EmptyStatesPattern.preview(config: EmptyStatesPattern.defaultConfig)
        .padding()
}
