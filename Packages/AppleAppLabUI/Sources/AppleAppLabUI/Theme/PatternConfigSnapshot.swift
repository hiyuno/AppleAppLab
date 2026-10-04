import SwiftUI

/// The subset of `PatternConfig` a component's inspector actually edits, in a
/// Codable form. `cornerStyle` and `elevation` are deliberately excluded — those
/// come from the theme's global settings, not from per-component overrides.
public struct PatternConfigSnapshot: Codable, Hashable, Sendable {
    public var spacing: Double
    public var cornerRadius: Double
    public var accentColor: CodableColor
    public var secondaryColor: CodableColor
    public var tertiaryColor: CodableColor
    public var accentOutlineColor: CodableColor
    public var secondaryOutlineColor: CodableColor
    public var tertiaryOutlineColor: CodableColor
    public var duration: Double
    public var borderWidth: Double
    public var surfaceOpacityMultiplier: Double
    public var variant: String

    private enum CodingKeys: String, CodingKey {
        case spacing, cornerRadius, accentColor, secondaryColor, tertiaryColor
        case accentOutlineColor, secondaryOutlineColor, tertiaryOutlineColor
        case duration, borderWidth, surfaceOpacityMultiplier, variant
    }

    public init(_ config: PatternConfig) {
        spacing = Double(config.spacing)
        cornerRadius = Double(config.cornerRadius)
        accentColor = CodableColor(config.accentColor)
        secondaryColor = CodableColor(config.secondaryColor)
        tertiaryColor = CodableColor(config.tertiaryColor)
        accentOutlineColor = CodableColor(config.accentOutlineColor)
        secondaryOutlineColor = CodableColor(config.secondaryOutlineColor)
        tertiaryOutlineColor = CodableColor(config.tertiaryOutlineColor)
        duration = config.duration
        borderWidth = Double(config.borderWidth)
        surfaceOpacityMultiplier = config.surfaceOpacityMultiplier
        variant = config.variant
    }

    // Overrides saved before the outline colors existed fall back to each fill color.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        spacing = try container.decode(Double.self, forKey: .spacing)
        cornerRadius = try container.decode(Double.self, forKey: .cornerRadius)
        accentColor = try container.decode(CodableColor.self, forKey: .accentColor)
        secondaryColor = try container.decode(CodableColor.self, forKey: .secondaryColor)
        tertiaryColor = try container.decode(CodableColor.self, forKey: .tertiaryColor)
        accentOutlineColor = try container.decodeIfPresent(CodableColor.self, forKey: .accentOutlineColor) ?? accentColor
        secondaryOutlineColor = try container.decodeIfPresent(CodableColor.self, forKey: .secondaryOutlineColor) ?? secondaryColor
        tertiaryOutlineColor = try container.decodeIfPresent(CodableColor.self, forKey: .tertiaryOutlineColor) ?? tertiaryColor
        duration = try container.decode(Double.self, forKey: .duration)
        borderWidth = try container.decode(Double.self, forKey: .borderWidth)
        surfaceOpacityMultiplier = try container.decode(Double.self, forKey: .surfaceOpacityMultiplier)
        variant = try container.decode(String.self, forKey: .variant)
    }

    public func apply(to config: inout PatternConfig) {
        config.spacing = CGFloat(spacing)
        config.cornerRadius = CGFloat(cornerRadius)
        config.accentColor = accentColor.color
        config.secondaryColor = secondaryColor.color
        config.tertiaryColor = tertiaryColor.color
        config.accentOutlineColor = accentOutlineColor.color
        config.secondaryOutlineColor = secondaryOutlineColor.color
        config.tertiaryOutlineColor = tertiaryOutlineColor.color
        config.duration = duration
        config.borderWidth = CGFloat(borderWidth)
        config.surfaceOpacityMultiplier = surfaceOpacityMultiplier
        config.variant = variant
    }
}
