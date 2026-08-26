import SwiftUI

public struct LabNestedCard: View {
    let title: String
    let subtitle: String
    let outerColor: Color
    let middleColor: Color
    let innerColor: Color
    let outerOutlineColor: Color
    let middleOutlineColor: Color
    let innerOutlineColor: Color
    let showOuterContainer: Bool
    let showImage: Bool
    let showText: Bool
    let config: PatternConfig

    public init(
        title: String,
        subtitle: String,
        outerColor: Color,
        middleColor: Color,
        innerColor: Color,
        outerOutlineColor: Color? = nil,
        middleOutlineColor: Color? = nil,
        innerOutlineColor: Color? = nil,
        showOuterContainer: Bool = true,
        showImage: Bool = true,
        showText: Bool = true,
        config: PatternConfig
    ) {
        self.title = title
        self.subtitle = subtitle
        self.outerColor = outerColor
        self.middleColor = middleColor
        self.innerColor = innerColor
        self.outerOutlineColor = outerOutlineColor ?? outerColor
        self.middleOutlineColor = middleOutlineColor ?? middleColor
        self.innerOutlineColor = innerOutlineColor ?? innerColor
        self.showOuterContainer = showOuterContainer
        self.showImage = showImage
        self.showText = showText
        self.config = config
    }

    private var padding: CGFloat {
        max(config.spacing, 8)
    }

    private var outerRadius: CGFloat {
        config.cornerRadius
    }

    private var middleRadius: CGFloat {
        max(outerRadius - 10, 4)
    }

    private var innerRadius: CGFloat {
        max(middleRadius - 8, 2)
    }

    public var body: some View {
        Group {
            if showOuterContainer {
                middleLayer
                    .padding(padding)
                    .background(layerBackground(fill: outerColor, outline: outerOutlineColor, radius: outerRadius, opacity: 0.10))
                    .background(
                        LabShape(radius: outerRadius, style: config.cornerStyle)
                            .fill(.background)
                            .labShadow(config.elevation)
                    )
            } else {
                middleLayer
            }
        }
        .frame(width: 240)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(showText ? "\(title), \(subtitle), nested card" : "Nested card")
    }

    private var middleLayer: some View {
        innerLayer
            .padding(padding * 0.75)
            .background(layerBackground(fill: middleColor, outline: middleOutlineColor, radius: middleRadius, opacity: 0.14))
    }

    private var innerLayer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showImage {
                LabShape(radius: max(innerRadius - 2, 2), style: config.cornerStyle)
                    .fill(innerColor.opacity(0.25 * config.surfaceOpacityMultiplier))
                    .frame(height: 60)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(innerColor)
                    )
            }

            if showText {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !showImage && !showText {
                // Keeps the nested layers legible as a pure layout/color showcase
                // instead of collapsing to a sliver with no content at all.
                Color.clear.frame(width: 140, height: 40)
            }
        }
        .padding(10)
        .background(layerBackground(fill: innerColor, outline: innerOutlineColor, radius: innerRadius, opacity: 0.10))
    }

    private func layerBackground(fill: Color, outline: Color, radius: CGFloat, opacity: Double) -> some View {
        LabShape(radius: radius, style: config.cornerStyle)
            .fill(fill.opacity(opacity * config.surfaceOpacityMultiplier))
            .overlay(
                LabShape(radius: radius, style: config.cornerStyle)
                    .strokeBorder(outline, lineWidth: config.borderWidth)
            )
    }
}

#Preview {
    LabNestedCard(
        title: "Golden Gate",
        subtitle: "San Francisco, CA",
        outerColor: .indigo,
        middleColor: .teal,
        innerColor: .orange,
        config: PatternConfig()
    )
    .padding()
}
