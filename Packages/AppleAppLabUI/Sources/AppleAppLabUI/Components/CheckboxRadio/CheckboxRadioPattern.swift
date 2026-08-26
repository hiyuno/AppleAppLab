import SwiftUI

public enum CheckboxRadioPattern: InspectablePattern {
    public static let name = "Checkbox & Radio"
    public static let symbolName = "checklist"

    public static let defaultConfig = PatternConfig(
        spacing: 12,
        accentColor: ColorTokens.accent
    )

    public static let inspectableProperties: [InspectableProperty] = [
        .spacing(label: "Item Spacing", keyPath: \.spacing, range: 4...24),
        .color(label: "Accent Color", keyPath: \.accentColor)
    ]

    public static func preview(config: PatternConfig) -> some View {
        CheckboxRadioPreview(config: config)
    }
}

private struct CheckboxRadioPreview: View {
    let config: PatternConfig

    @State private var options = [
        LabCheckboxOption(title: "Enable notifications", isOn: true),
        LabCheckboxOption(title: "Sound effects"),
        LabCheckboxOption(title: "Auto-update")
    ]
    @State private var frequency = "Daily"

    var body: some View {
        VStack(alignment: .leading, spacing: config.spacing * 1.5) {
            LabCheckboxGroup(options: $options, config: config)
            LabRadioGroup(
                title: "Frequency",
                options: ["Daily", "Weekly", "Monthly"],
                selection: $frequency,
                config: config
            )
        }
        .frame(maxWidth: 260)
    }
}

#Preview {
    CheckboxRadioPattern.preview(config: CheckboxRadioPattern.defaultConfig)
        .padding()
}
