import SwiftUI

public enum CornerStyle: String, CaseIterable, Identifiable, Sendable, Codable, Hashable {
    case sharp
    case rounded
    case squircle

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .sharp: "Sharp"
        case .rounded: "Rounded"
        case .squircle: "Squircle"
        }
    }

    public var symbolName: String {
        switch self {
        case .sharp: "square"
        case .rounded: "circle"
        case .squircle: "app"
        }
    }
}

public struct LabShape: InsettableShape {
    public var radius: CGFloat
    public var style: CornerStyle
    private var insetAmount: CGFloat = 0

    public init(radius: CGFloat, style: CornerStyle) {
        self.radius = radius
        self.style = style
    }

    public func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let insetRadius = max(radius - insetAmount, 0)
        switch style {
        case .sharp:
            return Rectangle().path(in: insetRect)
        case .rounded:
            return RoundedRectangle(cornerRadius: insetRadius, style: .circular).path(in: insetRect)
        case .squircle:
            return RoundedRectangle(cornerRadius: insetRadius, style: .continuous).path(in: insetRect)
        }
    }

    public func inset(by amount: CGFloat) -> some InsettableShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach(CornerStyle.allCases) { style in
            VStack {
                LabShape(radius: 20, style: style)
                    .fill(ColorTokens.accent)
                    .frame(width: 80, height: 80)
                Text(style.label).font(.caption)
            }
        }
    }
    .padding()
}
