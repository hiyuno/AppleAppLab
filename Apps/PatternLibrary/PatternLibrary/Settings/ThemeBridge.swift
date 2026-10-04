import SwiftUI
import AppleAppLabUI

// PatternLibrary keeps `AppSettings` as its live, bindable UI state and uses the
// package's `LabThemeStore` as the persisted library. These bridges keep the
// existing views' call sites (`save(name:from:)`, `apply(_:to:)`, …) working.

extension AppSettings {
    /// A theme snapshot of the current settings.
    func theme(named name: String, id: UUID = UUID(), overrides: [String: PatternConfigSnapshot] = [:]) -> LabTheme {
        LabTheme(
            id: id,
            name: name,
            accentColor: accentColor,
            cornerStyle: cornerStyle,
            backgroundColor: backgroundColor,
            wallpaper: wallpaper,
            windowMaterial: windowMaterial,
            titleBarStyle: titleBarStyle,
            blurIntensity: blurIntensity,
            transparency: transparency,
            elevation: elevation,
            fontDesign: fontDesign,
            fontWeight: fontWeight,
            density: density,
            iconRenderingMode: iconRenderingMode,
            motionSpeedMultiplier: motionSpeedMultiplier,
            appearanceMode: appearanceMode,
            patternOverrides: overrides
        )
    }

    func apply(_ theme: LabTheme) {
        accentColor = theme.accentColor.color
        cornerStyle = theme.cornerStyle
        backgroundColor = theme.backgroundColor.color
        wallpaper = theme.wallpaper
        windowMaterial = theme.windowMaterial
        titleBarStyle = theme.titleBarStyle
        blurIntensity = theme.blurIntensity
        transparency = theme.transparency
        elevation = theme.elevation
        fontDesign = theme.fontDesign
        fontWeight = theme.fontWeight
        density = theme.density
        iconRenderingMode = theme.iconRenderingMode
        motionSpeedMultiplier = theme.motionSpeedMultiplier
        appearanceMode = theme.appearanceMode
    }
}

extension LabThemeStore {
    static let patternLibraryStorageKey = "mx.9866.PatternLibrary.SavedThemes"

    func save(name: String, from settings: AppSettings) {
        active = settings.theme(named: name)
        saveActive(as: name)
    }

    func update(_ theme: LabTheme, from settings: AppSettings) {
        var updated = settings.theme(named: theme.name, id: theme.id, overrides: theme.patternOverrides)
        if let patternName = editingPatternName, let config = editingPatternConfig {
            updated.setOverride(config, for: patternName)
        }
        replace(updated)
    }

    func apply(_ theme: LabTheme, to settings: AppSettings) {
        apply(theme)
        settings.apply(theme)
    }
}
