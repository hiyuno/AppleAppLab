import SwiftUI

public enum FormsPattern: InspectablePattern {
    public static let name = "Formularios/inputs"
    public static let symbolName = "square.and.pencil"

    public static let defaultConfig = PatternConfig(
        spacing: 12,
        cornerRadius: 12,
        accentColor: ColorTokens.accent,
        duration: 0.15
    )

    public static let inspectableProperties: [InspectableProperty] = [
        .spacing(label: "Field Spacing", keyPath: \.spacing, range: 4...24),
        .cornerRadius(label: "Corner Radius", keyPath: \.cornerRadius, range: 0...20),
        .color(label: "Focus Border Color", keyPath: \.accentColor),
        .duration(label: "Focus Transition", keyPath: \.duration, range: 0.05...0.4)
    ]

    public static func preview(config: PatternConfig) -> some View {
        FormsPreview(config: config)
    }
}

private struct FormsPreview: View {
    let config: PatternConfig
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: config.spacing) {
            LabTextField(placeholder: "Email", text: $email, config: config)
            LabTextField(placeholder: "Password", text: $password, config: config)
        }
        .frame(maxWidth: 280)
    }
}

#Preview {
    FormsPattern.preview(config: FormsPattern.defaultConfig)
        .padding()
}
