import SwiftUI

public struct LabButton: View {
    public enum Style {
        case primary
        case secondary
    }

    private let title: String
    private let style: Style
    private let config: PatternConfig
    private let action: () -> Void

    public init(title: String, style: Style, config: PatternConfig, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.config = config
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(TypographyTokens.buttonLabel)
                .frame(maxWidth: .infinity, minHeight: SpacingTokens.minTapTarget)
        }
        .buttonStyle(LabButtonStyle(style: style, config: config))
    }
}

private struct LabButtonStyle: ButtonStyle {
    let style: LabButton.Style
    let config: PatternConfig

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(style == .primary ? Color.white : config.accentColor)
            .background(
                LabShape(radius: config.cornerRadius, style: config.cornerStyle)
                    .fill(style == .primary ? config.accentColor : Color.clear)
                    .overlay(
                        LabShape(radius: config.cornerRadius, style: config.cornerStyle)
                            .strokeBorder(config.accentColor, lineWidth: style == .secondary ? config.borderWidth * 1.5 : 0)
                    )
                    .labShadow(style == .primary ? config.elevation : .flat)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(
                reduceMotion ? .none : .spring(response: config.duration, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}

#Preview {
    VStack(spacing: SpacingTokens.buttonSpacing) {
        LabButton(title: "Continue", style: .primary, config: PatternConfig()) {}
        LabButton(title: "Cancel", style: .secondary, config: PatternConfig()) {}
    }
    .padding()
}
