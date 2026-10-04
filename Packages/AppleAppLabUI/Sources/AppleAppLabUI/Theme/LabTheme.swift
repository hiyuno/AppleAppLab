import SwiftUI

/// One complete visual configuration for an app: global tokens (accent, shape,
/// window material, typography, density, motion, appearance) plus optional
/// per-component overrides keyed by `InspectablePattern.name`.
///
/// JSON keys are the ones PatternLibrary has always written, so the files in
/// `Themes/*.json` (Fintrol, Todocky, ToDo Project, Test) decode as-is.
public struct LabTheme: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String

    public var accentColor: CodableColor
    public var cornerStyle: CornerStyle
    public var backgroundColor: CodableColor
    public var wallpaper: WallpaperOption
    public var windowMaterial: WindowMaterial
    public var titleBarStyle: WindowTitleBarStyle
    public var blurIntensity: Double
    public var transparency: Double
    public var elevation: ElevationLevel
    public var fontDesign: FontDesignOption
    public var fontWeight: FontWeightOption
    public var density: Density
    public var iconRenderingMode: IconRenderingMode
    public var motionSpeedMultiplier: Double
    public var appearanceMode: AppearanceMode
    public var patternOverrides: [String: PatternConfigSnapshot]

    public init(
        id: UUID = UUID(),
        name: String,
        accentColor: Color = ColorTokens.accent,
        cornerStyle: CornerStyle = .squircle,
        backgroundColor: Color = LabTheme.systemWindowBackground,
        wallpaper: WallpaperOption = .none,
        windowMaterial: WindowMaterial = .solid,
        titleBarStyle: WindowTitleBarStyle = .full,
        blurIntensity: Double = 0.5,
        transparency: Double = 0.5,
        elevation: ElevationLevel = .subtle,
        fontDesign: FontDesignOption = .standard,
        fontWeight: FontWeightOption = .regular,
        density: Density = .regular,
        iconRenderingMode: IconRenderingMode = .monochrome,
        motionSpeedMultiplier: Double = 1.0,
        appearanceMode: AppearanceMode = .system,
        patternOverrides: [String: PatternConfigSnapshot] = [:]
    ) {
        self.id = id
        self.name = name
        self.accentColor = CodableColor(accentColor)
        self.cornerStyle = cornerStyle
        self.backgroundColor = CodableColor(backgroundColor)
        self.wallpaper = wallpaper
        self.windowMaterial = windowMaterial
        self.titleBarStyle = titleBarStyle
        self.blurIntensity = blurIntensity
        self.transparency = transparency
        self.elevation = elevation
        self.fontDesign = fontDesign
        self.fontWeight = fontWeight
        self.density = density
        self.iconRenderingMode = iconRenderingMode
        self.motionSpeedMultiplier = motionSpeedMultiplier
        self.appearanceMode = appearanceMode
        self.patternOverrides = patternOverrides
    }

    /// The team's neutral starting point — what a brand-new app looks like before
    /// Steve's visual-style phase picks a theme.
    public static let `default` = LabTheme(name: "Default")

    public static var systemWindowBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    // MARK: - Codable (tolerant of older theme files)

    private enum CodingKeys: String, CodingKey {
        case id, name, accentColor, cornerStyle, backgroundColor, wallpaper, windowMaterial
        case titleBarStyle, blurIntensity, transparency, elevation, fontDesign, fontWeight
        case density, iconRenderingMode, motionSpeedMultiplier, appearanceMode, patternOverrides
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case showTrafficLights
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        accentColor = try c.decode(CodableColor.self, forKey: .accentColor)
        cornerStyle = try c.decodeIfPresent(CornerStyle.self, forKey: .cornerStyle) ?? .squircle
        backgroundColor = try c.decodeIfPresent(CodableColor.self, forKey: .backgroundColor) ?? CodableColor(Self.systemWindowBackground)
        wallpaper = try c.decodeIfPresent(WallpaperOption.self, forKey: .wallpaper) ?? .none
        windowMaterial = try c.decodeIfPresent(WindowMaterial.self, forKey: .windowMaterial) ?? .solid
        if let style = try c.decodeIfPresent(WindowTitleBarStyle.self, forKey: .titleBarStyle) {
            titleBarStyle = style
        } else {
            let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
            titleBarStyle = (try legacy.decodeIfPresent(Bool.self, forKey: .showTrafficLights) ?? true) ? .full : .compact
        }
        blurIntensity = try c.decodeIfPresent(Double.self, forKey: .blurIntensity) ?? 0.5
        transparency = try c.decodeIfPresent(Double.self, forKey: .transparency) ?? 0.5
        elevation = try c.decodeIfPresent(ElevationLevel.self, forKey: .elevation) ?? .subtle
        fontDesign = try c.decodeIfPresent(FontDesignOption.self, forKey: .fontDesign) ?? .standard
        fontWeight = try c.decodeIfPresent(FontWeightOption.self, forKey: .fontWeight) ?? .regular
        density = try c.decodeIfPresent(Density.self, forKey: .density) ?? .regular
        iconRenderingMode = try c.decodeIfPresent(IconRenderingMode.self, forKey: .iconRenderingMode) ?? .monochrome
        motionSpeedMultiplier = try c.decodeIfPresent(Double.self, forKey: .motionSpeedMultiplier) ?? 1.0
        appearanceMode = try c.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? .system
        patternOverrides = try c.decodeIfPresent([String: PatternConfigSnapshot].self, forKey: .patternOverrides) ?? [:]
    }

    // MARK: - Resolving component configs

    /// The `PatternConfig` a component should render with under this theme:
    /// the pattern's own defaults, with the theme's global tokens layered on
    /// (accent, corner style, elevation, density-scaled spacing, motion-scaled
    /// duration), and finally any override the user saved for that pattern.
    public func config(for patternName: String, base: PatternConfig) -> PatternConfig {
        var config = base
        config.accentColor = accentColor.color
        config.cornerStyle = cornerStyle
        config.elevation = elevation
        config.spacing = base.spacing * density.scale
        config.duration = base.duration / max(motionSpeedMultiplier, 0.01)
        if let override = patternOverrides[patternName] {
            override.apply(to: &config)
        }
        return config
    }

    @MainActor
    public func config<P: InspectablePattern>(for pattern: P.Type) -> PatternConfig {
        config(for: P.name, base: P.defaultConfig)
    }

    public mutating func setOverride(_ config: PatternConfig, for patternName: String) {
        patternOverrides[patternName] = PatternConfigSnapshot(config)
    }

    public mutating func clearOverride(for patternName: String) {
        patternOverrides[patternName] = nil
    }

    // MARK: - JSON

    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> LabTheme {
        try JSONDecoder().decode(LabTheme.self, from: data)
    }

    /// File name the team convention expects under `Themes/`: lowercase, hyphenated.
    public var suggestedFileName: String {
        let slug = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return (slug.isEmpty ? "theme" : slug) + ".json"
    }
}
