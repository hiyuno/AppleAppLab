import SwiftUI

public enum TogglesPattern: InspectablePattern {
    public static let name = "Toggles/segmented controls"
    public static let symbolName = "switch.2"

    public static let defaultConfig = PatternConfig(
        spacing: 12,
        accentColor: ColorTokens.accent
    )

    public static let inspectableProperties: [InspectableProperty] = [
        .spacing(label: "Row Spacing", keyPath: \.spacing, range: 4...24),
        .color(label: "Accent Color", keyPath: \.accentColor)
    ]

    public static func preview(config: PatternConfig) -> some View {
        TogglesPreview(config: config)
    }
}

private struct TogglesPreview: View {
    let config: PatternConfig
    @State private var notifications = true
    @State private var sound = false
    @State private var segment = 0

    var body: some View {
        VStack(spacing: config.spacing) {
            LabToggleRow(title: "Notifications", isOn: $notifications, config: config)
            LabToggleRow(title: "Sound", isOn: $sound, config: config)
            Picker("View", selection: $segment) {
                Text("Day").tag(0)
                Text("Week").tag(1)
                Text("Month").tag(2)
            }
            .pickerStyle(.segmented)
            .tint(config.accentColor)
        }
        .frame(maxWidth: 260)
    }
}

#Preview {
    TogglesPattern.preview(config: TogglesPattern.defaultConfig)
        .padding()
}
