import SwiftUI

public enum ButtonsPattern: InspectablePattern {
    public static let name = "Botones y controles"
    public static let symbolName = "button.programmable"

    public static let defaultConfig = PatternConfig(
        spacing: SpacingTokens.buttonSpacing,
        cornerRadius: 22,
        accentColor: ColorTokens.accent,
        duration: 0.3
    )

    public static let inspectableProperties: [InspectableProperty] = [
        .spacing(label: "Spacing", keyPath: \.spacing, range: 0...32),
        .cornerRadius(label: "Corner Radius", keyPath: \.cornerRadius, range: 0...28),
        .color(label: "Accent Color", keyPath: \.accentColor),
        .duration(label: "Press Response", keyPath: \.duration, range: 0.1...0.6)
    ]

    public static func preview(config: PatternConfig) -> some View {
        VStack(spacing: config.spacing) {
            LabButton(title: "Continue", style: .primary, config: config) {}
            LabButton(title: "Cancel", style: .secondary, config: config) {}
        }
        .frame(maxWidth: 280)
    }
}

#Preview {
    ButtonsPattern.preview(config: ButtonsPattern.defaultConfig)
        .padding()
}
