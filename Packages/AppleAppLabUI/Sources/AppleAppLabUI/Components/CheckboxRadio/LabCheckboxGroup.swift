import SwiftUI

public struct LabCheckboxOption: Identifiable {
    public let id = UUID()
    public var title: String
    public var isOn: Bool

    public init(title: String, isOn: Bool = false) {
        self.title = title
        self.isOn = isOn
    }
}

public struct LabCheckboxGroup: View {
    @Binding var options: [LabCheckboxOption]
    let config: PatternConfig

    public init(options: Binding<[LabCheckboxOption]>, config: PatternConfig) {
        self._options = options
        self.config = config
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: config.spacing) {
            ForEach($options) { $option in
                Toggle(option.title, isOn: $option.isOn)
                    .toggleStyle(.checkbox)
            }
        }
        .tint(config.accentColor)
    }
}

#Preview {
    @Previewable @State var options = [
        LabCheckboxOption(title: "Enable notifications", isOn: true),
        LabCheckboxOption(title: "Sound effects"),
        LabCheckboxOption(title: "Auto-update")
    ]

    LabCheckboxGroup(options: $options, config: PatternConfig())
        .padding()
}
