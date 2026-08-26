import Foundation
import AppleAppLabUI

struct Theme: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String

    var accentColor: CodableColor
    var cornerStyle: CornerStyle
    var backgroundColor: CodableColor
    var wallpaper: WallpaperOption
    var windowMaterial: WindowMaterial
    var titleBarStyle: WindowTitleBarStyle
    var blurIntensity: Double
    var transparency: Double
    var elevation: ElevationLevel
    var fontDesign: FontDesignOption
    var fontWeight: FontWeightOption
    var density: Density
    var iconRenderingMode: IconRenderingMode
    var motionSpeedMultiplier: Double
    var appearanceMode: AppearanceMode
    var patternOverrides: [String: PatternConfigSnapshot] = [:]

    // Every case here must correspond to a stored property, or Encodable synthesis
    // breaks — that's why the legacy `showTrafficLights` key lives in its own enum
    // below instead of here.
    private enum CodingKeys: String, CodingKey {
        case id, name, accentColor, cornerStyle, backgroundColor, wallpaper, windowMaterial
        case titleBarStyle, blurIntensity, transparency, elevation, fontDesign, fontWeight
        case density, iconRenderingMode, motionSpeedMultiplier, appearanceMode, patternOverrides
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case showTrafficLights
    }

    // Custom decode so themes saved before `patternOverrides` existed still load —
    // the synthesized initializer would otherwise fail on the missing key.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        accentColor = try container.decode(CodableColor.self, forKey: .accentColor)
        cornerStyle = try container.decode(CornerStyle.self, forKey: .cornerStyle)
        backgroundColor = try container.decode(CodableColor.self, forKey: .backgroundColor)
        wallpaper = try container.decode(WallpaperOption.self, forKey: .wallpaper)
        windowMaterial = try container.decode(WindowMaterial.self, forKey: .windowMaterial)
        // Themes saved before `titleBarStyle` existed only have the old
        // `showTrafficLights` bool — map it forward (true→full, false→compact).
        if let style = try container.decodeIfPresent(WindowTitleBarStyle.self, forKey: .titleBarStyle) {
            titleBarStyle = style
        } else {
            let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
            let legacyShowTrafficLights = try legacyContainer.decodeIfPresent(Bool.self, forKey: .showTrafficLights) ?? true
            titleBarStyle = legacyShowTrafficLights ? .full : .compact
        }
        blurIntensity = try container.decode(Double.self, forKey: .blurIntensity)
        transparency = try container.decode(Double.self, forKey: .transparency)
        elevation = try container.decode(ElevationLevel.self, forKey: .elevation)
        fontDesign = try container.decode(FontDesignOption.self, forKey: .fontDesign)
        fontWeight = try container.decode(FontWeightOption.self, forKey: .fontWeight)
        density = try container.decode(Density.self, forKey: .density)
        iconRenderingMode = try container.decode(IconRenderingMode.self, forKey: .iconRenderingMode)
        motionSpeedMultiplier = try container.decode(Double.self, forKey: .motionSpeedMultiplier)
        appearanceMode = try container.decode(AppearanceMode.self, forKey: .appearanceMode)
        patternOverrides = try container.decodeIfPresent([String: PatternConfigSnapshot].self, forKey: .patternOverrides) ?? [:]
    }

    @MainActor
    init(id: UUID = UUID(), name: String, settings: AppSettings) {
        self.id = id
        self.name = name
        accentColor = CodableColor(settings.accentColor)
        cornerStyle = settings.cornerStyle
        backgroundColor = CodableColor(settings.backgroundColor)
        wallpaper = settings.wallpaper
        windowMaterial = settings.windowMaterial
        titleBarStyle = settings.titleBarStyle
        blurIntensity = settings.blurIntensity
        transparency = settings.transparency
        elevation = settings.elevation
        fontDesign = settings.fontDesign
        fontWeight = settings.fontWeight
        density = settings.density
        iconRenderingMode = settings.iconRenderingMode
        motionSpeedMultiplier = settings.motionSpeedMultiplier
        appearanceMode = settings.appearanceMode
    }

    @MainActor
    func apply(to settings: AppSettings) {
        settings.accentColor = accentColor.color
        settings.cornerStyle = cornerStyle
        settings.backgroundColor = backgroundColor.color
        settings.wallpaper = wallpaper
        settings.windowMaterial = windowMaterial
        settings.titleBarStyle = titleBarStyle
        settings.blurIntensity = blurIntensity
        settings.transparency = transparency
        settings.elevation = elevation
        settings.fontDesign = fontDesign
        settings.fontWeight = fontWeight
        settings.density = density
        settings.iconRenderingMode = iconRenderingMode
        settings.motionSpeedMultiplier = motionSpeedMultiplier
        settings.appearanceMode = appearanceMode
    }

    @MainActor
    mutating func updateSnapshot(from settings: AppSettings) {
        accentColor = CodableColor(settings.accentColor)
        cornerStyle = settings.cornerStyle
        backgroundColor = CodableColor(settings.backgroundColor)
        wallpaper = settings.wallpaper
        windowMaterial = settings.windowMaterial
        titleBarStyle = settings.titleBarStyle
        blurIntensity = settings.blurIntensity
        transparency = settings.transparency
        elevation = settings.elevation
        fontDesign = settings.fontDesign
        fontWeight = settings.fontWeight
        density = settings.density
        iconRenderingMode = settings.iconRenderingMode
        motionSpeedMultiplier = settings.motionSpeedMultiplier
        appearanceMode = settings.appearanceMode
    }

    mutating func setPatternOverride(_ config: PatternConfig, for patternName: String) {
        patternOverrides[patternName] = PatternConfigSnapshot(config)
    }
}
