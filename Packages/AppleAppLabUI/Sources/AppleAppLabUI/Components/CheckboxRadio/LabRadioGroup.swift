import SwiftUI

public struct LabRadioGroup: View {
    let title: String
    let options: [String]
    @Binding var selection: String
    let config: PatternConfig

    public init(title: String, options: [String], selection: Binding<String>, config: PatternConfig) {
        self.title = title
        self.options = options
        self._selection = selection
        self.config = config
    }

    public var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(option).tag(option)
            }
        }
        .pickerStyle(.radioGroup)
        .tint(config.accentColor)
    }
}

#Preview {
    @Previewable @State var selection = "Daily"

    LabRadioGroup(
        title: "Frequency",
        options: ["Daily", "Weekly", "Monthly"],
        selection: $selection,
        config: PatternConfig()
    )
    .padding()
}
