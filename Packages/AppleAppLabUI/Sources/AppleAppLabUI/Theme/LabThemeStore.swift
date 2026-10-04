import SwiftUI
import Observation

/// The single source of truth for an app's visual configuration.
///
/// `active` is the live theme every view reads from (via `\.labTheme` in the
/// environment). `saved` is the library of named themes — bundled `Themes/*.json`
/// plus whatever the user saved from the dev tools — persisted in `UserDefaults`.
///
/// In Release this is just a theme container; the editing UI (`LabDevTools`)
/// only exists in Debug.
@MainActor
@Observable
public final class LabThemeStore {
    public var active: LabTheme
    public private(set) var saved: [LabTheme] = []
    public private(set) var activeSavedID: UUID?

    /// Set by the dev tools while a component inspector is open, so "save theme"
    /// captures the override the user is adjusting right now.
    public var editingPatternName: String?
    public var editingPatternConfig: PatternConfig?

    private let storageKey: String
    private let activeKey: String
    private let defaults: UserDefaults

    /// - Parameters:
    ///   - storageKey: where saved themes live. Defaults to `<bundle id>.LabThemes`.
    ///     PatternLibrary passes its historical `mx.9866.PatternLibrary.SavedThemes`.
    ///   - bundledThemes: JSON themes shipped in the app bundle (the team's
    ///     `Themes/*.json`). They're merged into `saved` by name without
    ///     overwriting a user's edited copy.
    ///   - initial: the theme to activate on first launch when nothing is persisted.
    public init(
        storageKey: String? = nil,
        defaults: UserDefaults = .standard,
        bundledThemes: [LabTheme] = [],
        initial: LabTheme = .default
    ) {
        let base = storageKey ?? ((Bundle.main.bundleIdentifier ?? "AppleAppLab") + ".LabThemes")
        self.storageKey = base
        self.activeKey = base + ".active"
        self.defaults = defaults
        self.active = initial
        load()
        merge(bundled: bundledThemes)
        restoreActive(fallback: initial)
    }

    // MARK: - Resolving configs

    /// The config a `Lab*` component should use right now.
    public func config<P: InspectablePattern>(for pattern: P.Type) -> PatternConfig {
        active.config(for: pattern)
    }

    public func config(for patternName: String, base: PatternConfig) -> PatternConfig {
        active.config(for: patternName, base: base)
    }

    // MARK: - Library

    public func apply(_ theme: LabTheme) {
        active = theme
        activeSavedID = theme.id
        persistActive()
    }

    @discardableResult
    public func saveActive(as name: String) -> LabTheme {
        var theme = active
        theme.id = UUID()
        theme.name = name
        captureEditingOverride(into: &theme)
        saved.append(theme)
        activeSavedID = theme.id
        active = theme
        persist()
        return theme
    }

    /// Overwrites the saved theme the active one came from with the current state.
    public func updateActiveSavedTheme() {
        guard let id = activeSavedID, let index = saved.firstIndex(where: { $0.id == id }) else { return }
        var theme = active
        theme.id = id
        captureEditingOverride(into: &theme)
        saved[index] = theme
        active = theme
        persist()
    }

    /// Replaces a saved theme (matched by id) with `theme`, keeping `active` in
    /// sync if that theme is the active one.
    public func replace(_ theme: LabTheme) {
        guard let index = saved.firstIndex(where: { $0.id == theme.id }) else { return }
        saved[index] = theme
        if activeSavedID == theme.id { active = theme }
        persist()
    }

    public func rename(_ theme: LabTheme, to newName: String) {
        guard let index = saved.firstIndex(where: { $0.id == theme.id }) else { return }
        saved[index].name = newName
        if activeSavedID == theme.id { active.name = newName }
        persist()
    }

    public func delete(_ theme: LabTheme) {
        saved.removeAll { $0.id == theme.id }
        if activeSavedID == theme.id { activeSavedID = nil }
        persist()
    }

    /// Back to the pristine default — what the app looked like before any tuning.
    public func reset(to theme: LabTheme = .default) {
        active = theme
        activeSavedID = nil
        editingPatternName = nil
        editingPatternConfig = nil
        persistActive()
    }

    public func importJSON(_ data: Data) throws -> LabTheme {
        var theme = try LabTheme.decode(data)
        theme.id = UUID()
        saved.append(theme)
        persist()
        return theme
    }

    public func exportActiveJSON() throws -> Data {
        var theme = active
        captureEditingOverride(into: &theme)
        return try theme.jsonData()
    }

    // MARK: - Bundled themes

    /// Loads every `*.json` in `Themes/` (or the bundle root) that decodes as a theme.
    public static func bundledThemes(in bundle: Bundle = .main) -> [LabTheme] {
        var urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: "Themes") ?? []
        if urls.isEmpty { urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [] }
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? LabTheme.decode(data)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func merge(bundled: [LabTheme]) {
        for theme in bundled where !saved.contains(where: { $0.name == theme.name }) {
            saved.append(theme)
        }
        if !bundled.isEmpty { persist() }
    }

    // MARK: - Persistence

    private func captureEditingOverride(into theme: inout LabTheme) {
        if let name = editingPatternName, let config = editingPatternConfig {
            theme.setOverride(config, for: name)
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(saved) {
            defaults.set(data, forKey: storageKey)
        }
        persistActive()
    }

    private func persistActive() {
        if let data = try? JSONEncoder().encode(active) {
            defaults.set(data, forKey: activeKey)
        }
    }

    private func load() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([LabTheme].self, from: data) {
            saved = decoded
        }
    }

    private func restoreActive(fallback: LabTheme) {
        if let data = defaults.data(forKey: activeKey),
           let decoded = try? LabTheme.decode(data) {
            active = decoded
            activeSavedID = saved.first(where: { $0.id == decoded.id })?.id
        } else {
            active = fallback
        }
    }
}

// MARK: - Environment

private struct LabThemeKey: EnvironmentKey {
    static let defaultValue: LabTheme = .default
}

public extension EnvironmentValues {
    /// The active theme. Components and app views read tokens from here instead of
    /// hardcoding colors, radii, opacities or durations.
    var labTheme: LabTheme {
        get { self[LabThemeKey.self] }
        set { self[LabThemeKey.self] = newValue }
    }
}

public extension View {
    /// Injects the store's active theme into the environment and applies the
    /// app-wide parts of it — accent tint, font design/weight, symbol rendering,
    /// and the appearance override. Put it on the root view, once.
    func labTheme(_ store: LabThemeStore) -> some View {
        modifier(LabThemeModifier(store: store))
    }
}

private struct LabThemeModifier: ViewModifier {
    let store: LabThemeStore

    func body(content: Content) -> some View {
        let theme = store.active
        content
            .environment(store)
            .environment(\.labTheme, theme)
            .tint(theme.accentColor.color)
            .fontDesign(theme.fontDesign.design)
            .fontWeight(theme.fontWeight.weight)
            .symbolRenderingMode(theme.iconRenderingMode.mode)
            .preferredColorScheme(theme.appearanceMode.colorScheme)
    }
}
