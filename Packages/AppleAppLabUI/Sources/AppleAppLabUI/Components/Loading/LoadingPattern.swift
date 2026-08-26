import SwiftUI

public enum LoadingPattern: InspectablePattern {
    public static let name = "Loading/progress"
    public static let symbolName = "arrow.triangle.2.circlepath"

    public static let defaultConfig = PatternConfig(
        accentColor: ColorTokens.accent,
        duration: 1.0
    )

    public static let inspectableProperties: [InspectableProperty] = [
        .color(label: "Spinner Color", keyPath: \.accentColor),
        .duration(label: "Rotation Duration", keyPath: \.duration, range: 0.4...2.5)
    ]

    public static func preview(config: PatternConfig) -> some View {
        LabProgressIndicator(config: config)
    }
}

#Preview {
    LoadingPattern.preview(config: LoadingPattern.defaultConfig)
        .padding()
}
