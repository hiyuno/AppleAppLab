import SwiftUI

public struct PatternConfig {
    public var spacing: CGFloat
    public var cornerRadius: CGFloat
    public var cornerStyle: CornerStyle
    public var accentColor: Color
    public var secondaryColor: Color
    public var tertiaryColor: Color
    public var accentOutlineColor: Color
    public var secondaryOutlineColor: Color
    public var tertiaryOutlineColor: Color
    public var duration: Double
    public var elevation: ElevationLevel
    public var borderWidth: CGFloat
    public var surfaceOpacityMultiplier: Double
    public var variant: String
    public var custom: [String: AnyHashable]

    public init(
        spacing: CGFloat = SpacingTokens.buttonSpacing,
        cornerRadius: CGFloat = RadiusTokens.pill,
        cornerStyle: CornerStyle = .squircle,
        accentColor: Color = ColorTokens.accent,
        secondaryColor: Color = .teal,
        tertiaryColor: Color = .orange,
        accentOutlineColor: Color = ColorTokens.accent,
        secondaryOutlineColor: Color = .teal,
        tertiaryOutlineColor: Color = .orange,
        duration: Double = 0.2,
        elevation: ElevationLevel = .subtle,
        borderWidth: CGFloat = 1.0,
        surfaceOpacityMultiplier: Double = 1.0,
        variant: String = "",
        custom: [String: AnyHashable] = [:]
    ) {
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.cornerStyle = cornerStyle
        self.accentColor = accentColor
        self.secondaryColor = secondaryColor
        self.tertiaryColor = tertiaryColor
        self.accentOutlineColor = accentOutlineColor
        self.secondaryOutlineColor = secondaryOutlineColor
        self.tertiaryOutlineColor = tertiaryOutlineColor
        self.duration = duration
        self.elevation = elevation
        self.borderWidth = borderWidth
        self.surfaceOpacityMultiplier = surfaceOpacityMultiplier
        self.variant = variant
        self.custom = custom
    }
}
