import SwiftUI

public struct LabToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let config: PatternConfig

    public init(title: String, isOn: Binding<Bool>, config: PatternConfig) {
        self.title = title
        self._isOn = isOn
        self.config = config
    }

    public var body: some View {
        Toggle(title, isOn: $isOn)
            .tint(config.accentColor)
    }
}

#Preview {
    LabToggleRow(title: "Enable Notifications", isOn: .constant(true), config: PatternConfig())
        .padding()
        .frame(width: 260)
}
