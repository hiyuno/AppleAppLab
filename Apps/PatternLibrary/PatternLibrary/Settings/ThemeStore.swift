import Foundation
import Observation
import AppleAppLabUI

@MainActor
@Observable
final class ThemeStore {
    private static let storageKey = "mx.9866.PatternLibrary.SavedThemes"

    var themes: [Theme] = []
    var activeThemeID: UUID?

    // Tracks whatever pattern screen is currently on-screen and its live inspector
    // config, so a save from the theme switcher (which lives in the sidebar, not
    // the pattern detail view) can snapshot the settings the user just adjusted.
    var activePatternName: String?
    var activePatternConfig: PatternConfig?

    init() {
        load()
    }

    func save(name: String, from settings: AppSettings) {
        var theme = Theme(name: name, settings: settings)
        applyActivePatternOverride(to: &theme)
        themes.append(theme)
        activeThemeID = theme.id
        persist()
    }

    func update(_ theme: Theme, from settings: AppSettings) {
        guard let index = themes.firstIndex(where: { $0.id == theme.id }) else { return }
        themes[index].updateSnapshot(from: settings)
        applyActivePatternOverride(to: &themes[index])
        persist()
    }

    private func applyActivePatternOverride(to theme: inout Theme) {
        guard let name = activePatternName, let config = activePatternConfig else { return }
        theme.setPatternOverride(config, for: name)
    }

    func rename(_ theme: Theme, to newName: String) {
        guard let index = themes.firstIndex(where: { $0.id == theme.id }) else { return }
        themes[index].name = newName
        persist()
    }

    func delete(_ theme: Theme) {
        themes.removeAll { $0.id == theme.id }
        if activeThemeID == theme.id {
            activeThemeID = nil
        }
        persist()
    }

    func apply(_ theme: Theme, to settings: AppSettings) {
        theme.apply(to: settings)
        activeThemeID = theme.id
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(themes) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([Theme].self, from: data) else {
            return
        }
        themes = decoded
    }
}
