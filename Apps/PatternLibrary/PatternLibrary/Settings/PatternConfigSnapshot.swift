import SwiftUI
import AppleAppLabUI

/// Captures the fields a pattern's inspector controls actually touch (spacing,
/// corner radius, colors, duration, border width, surface opacity, variant).
/// `cornerStyle` and `elevation` are excluded — they're driven by the active
/// theme's global settings, not the per-pattern inspector.
struct PatternConfigSnapshot: Codable, Hashable {
    var spacing: Double
    var cornerRadius: Double
    var accentColor: CodableColor
    var secondaryColor: CodableColor
    var tertiaryColor: CodableColor
    var accentOutlineColor: CodableColor
    var secondaryOutlineColor: CodableColor
    var tertiaryOutlineColor: CodableColor
    var duration: Double
    var borderWidth: Double
    var surfaceOpacityMultiplier: Double
    var variant: String

    private enum CodingKeys: String, CodingKey {
        case spacing, cornerRadius, accentColor, secondaryColor, tertiaryColor
        case accentOutlineColor, secondaryOutlineColor, tertiaryOutlineColor
        case duration, borderWidth, surfaceOpacityMultiplier, variant
    }

    init(_ config: PatternConfig) {
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

    // Custom decode so overrides saved before the outline colors existed still
    // load — falling back to each card's fill color, matching the look before.
    init(from decoder: Decoder) throws {
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

    func apply(to config: inout PatternConfig) {
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
