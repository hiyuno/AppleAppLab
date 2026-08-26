import SwiftUI
import AppleAppLabUI
import Observation

@MainActor
@Observable
final class AppSettings {
    var accentColor: Color = ColorTokens.accent
    var cornerStyle: CornerStyle = .squircle
    var backgroundColor: Color = Color(nsColor: .windowBackgroundColor)
    var wallpaper: WallpaperOption = .none
    var windowMaterial: WindowMaterial = .solid
    var titleBarStyle: WindowTitleBarStyle = .full
    var blurIntensity: Double = 0.5
    var transparency: Double = 0.5

    // Elevation — flows into PatternConfig
    var elevation: ElevationLevel = .subtle

    // Typography — cascade via environment modifiers, not PatternConfig
    var fontDesign: FontDesignOption = .standard
    var fontWeight: FontWeightOption = .regular

    // Density — scales PatternConfig.spacing relative to each pattern's own default
    var density: Density = .regular

    // Iconography — cascades via environment modifier
    var iconRenderingMode: IconRenderingMode = .monochrome

    // Motion — scales PatternConfig.duration relative to each pattern's own default
    var motionSpeedMultiplier: Double = 1.0

    // Appearance override for the whole app window
    var appearanceMode: AppearanceMode = .system
}
