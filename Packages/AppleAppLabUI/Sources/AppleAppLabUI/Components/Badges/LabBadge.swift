import SwiftUI

public struct LabBadge: View {
    let text: String
    let color: Color
    let config: PatternConfig

    public init(text: String, color: Color, config: PatternConfig) {
        self.text = text
        self.color = color
        self.config = config
    }

    public var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, config.spacing)
            .padding(.vertical, config.spacing * 0.4)
            .foregroundStyle(color)
            .background(
                LabShape(radius: config.cornerRadius, style: config.cornerStyle)
                    .fill(color.opacity(0.15 * config.surfaceOpacityMultiplier))
                    .overlay(
                        LabShape(radius: config.cornerRadius, style: config.cornerStyle)
                            .strokeBorder(color.opacity(0.4), lineWidth: config.borderWidth)
                    )
            )
            .accessibilityLabel(text)
    }
}

#Preview {
    LabBadge(text: "New", color: .indigo, config: PatternConfig(cornerRadius: 12))
        .padding()
}
