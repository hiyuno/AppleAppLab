import SwiftUI

public struct LabDashboardCards: View {
    let containerColor: Color
    let listColor: Color
    let featuredColor: Color
    let listOutlineColor: Color
    let featuredOutlineColor: Color
    let listCount: Int
    let config: PatternConfig

    public init(
        containerColor: Color,
        listColor: Color,
        featuredColor: Color,
        listOutlineColor: Color? = nil,
        featuredOutlineColor: Color? = nil,
        listCount: Int = 5,
        config: PatternConfig
    ) {
        self.containerColor = containerColor
        self.listColor = listColor
        self.featuredColor = featuredColor
        self.listOutlineColor = listOutlineColor ?? listColor
        self.featuredOutlineColor = featuredOutlineColor ?? featuredColor
        self.listCount = listCount
        self.config = config
    }

    private var padding: CGFloat {
        max(config.spacing, 8)
    }

    private var outerRadius: CGFloat {
        config.cornerRadius
    }

    private var innerRadius: CGFloat {
        max(outerRadius - 10, 4)
    }

    public var body: some View {
        HStack(spacing: config.spacing) {
            container {
                VStack(spacing: 8) {
                    ForEach(0..<listCount, id: \.self) { _ in
                        subcard(fill: listColor, outline: listOutlineColor)
                            .frame(height: 36)
                    }
                }
            }
            .accessibilityLabel("Card list, \(listCount) items")

            container {
                subcard(fill: featuredColor, outline: featuredOutlineColor)
                    .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Featured card")
        }
    }

    private func container<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(padding)
            .background(
                LabShape(radius: outerRadius, style: config.cornerStyle)
                    .fill(.background)
                    .labShadow(config.elevation)
            )
    }

    private func subcard(fill: Color, outline: Color) -> some View {
        LabShape(radius: innerRadius, style: config.cornerStyle)
            .fill(fill.opacity(0.15 * config.surfaceOpacityMultiplier))
            .overlay(
                LabShape(radius: innerRadius, style: config.cornerStyle)
                    .strokeBorder(outline, lineWidth: config.borderWidth)
            )
    }
}

#Preview {
    LabDashboardCards(
        containerColor: .indigo,
        listColor: .teal,
        featuredColor: .orange,
        config: PatternConfig()
    )
    .frame(width: 420, height: 260)
    .padding()
}
