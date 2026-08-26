import SwiftUI

public struct LabTextField: View {
    let placeholder: String
    @Binding var text: String
    let config: PatternConfig

    @FocusState private var isFocused: Bool

    public init(placeholder: String, text: Binding<String>, config: PatternConfig) {
        self.placeholder = placeholder
        self._text = text
        self.config = config
    }

    public var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .padding(12)
            .background(
                LabShape(radius: config.cornerRadius, style: config.cornerStyle)
                    .fill(.quaternary.opacity(0.3 * config.surfaceOpacityMultiplier))
                    .overlay(
                        LabShape(radius: config.cornerRadius, style: config.cornerStyle)
                            .strokeBorder(isFocused ? config.accentColor : .clear, lineWidth: config.borderWidth * 2)
                    )
            )
            .focused($isFocused)
            .animation(.easeOut(duration: config.duration), value: isFocused)
    }
}

#Preview {
    LabTextField(placeholder: "Email", text: .constant(""), config: PatternConfig())
        .padding()
        .frame(width: 280)
}
