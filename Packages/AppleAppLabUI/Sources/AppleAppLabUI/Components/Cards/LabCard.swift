import SwiftUI

public struct LabCard: View {
    let title: String
    let subtitle: String
    let config: PatternConfig

    public init(title: String, subtitle: String, config: PatternConfig) {
        self.title = title
        self.subtitle = subtitle
        self.config = config
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: config.spacing) {
            LabShape(radius: max(config.cornerRadius - 8, 4), style: config.cornerStyle)
                .fill(config.accentColor.opacity(0.15 * config.surfaceOpacityMultiplier))
                .frame(height: 100)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundStyle(config.accentColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(config.spacing)
        .background(
            LabShape(radius: config.cornerRadius, style: config.cornerStyle)
                .fill(.background)
                .labShadow(config.elevation)
        )
        .frame(width: 240)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    LabCard(title: "Golden Gate", subtitle: "San Francisco, CA", config: PatternConfig())
        .padding()
}
