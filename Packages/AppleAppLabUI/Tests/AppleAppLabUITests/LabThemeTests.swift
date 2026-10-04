import Foundation
import SwiftUI
import Testing
@testable import AppleAppLabUI

@Suite("LabTheme")
struct LabThemeTests {
    /// `Themes/*.json` at the repo root — the files setup.sh ships to every project.
    private static var themesDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // LabThemeTests.swift → AppleAppLabUITests/
            .deletingLastPathComponent() // → Tests/
            .deletingLastPathComponent() // → AppleAppLabUI/
            .deletingLastPathComponent() // → Packages/
            .deletingLastPathComponent() // → AppleAppLab/ (repo root)
            .appendingPathComponent("Themes", isDirectory: true)
    }

    @Test("Every shipped Themes/*.json decodes, re-encodes and decodes again unchanged")
    func shippedThemesRoundTrip() throws {
        let urls = try FileManager.default.contentsOfDirectory(at: Self.themesDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        #expect(!urls.isEmpty)

        for url in urls {
            let theme = try LabTheme.decode(try Data(contentsOf: url))
            let again = try LabTheme.decode(try theme.jsonData())
            #expect(again == theme, "\(url.lastPathComponent) changed across a round-trip")
        }
    }

    @Test("Fintrol keeps its accent, material and per-pattern overrides")
    func fintrolContents() throws {
        let theme = try LabTheme.decode(try Data(contentsOf: Self.themesDirectory.appendingPathComponent("fintrol.json")))
        #expect(theme.name == "Fintrol")
        #expect(theme.windowMaterial == .frost)
        #expect(theme.elevation == .flat)
        #expect(theme.accentColor.hexString == "#F14200")
        #expect(theme.patternOverrides["Botones y controles"] != nil)
    }

    @Test("Decoding tolerates a minimal theme with only name and accent")
    func minimalDecode() throws {
        let json = #"{"name":"Mini","accentColor":{"red":1,"green":0,"blue":0,"opacity":1}}"#
        let theme = try LabTheme.decode(Data(json.utf8))
        #expect(theme.cornerStyle == .squircle)
        #expect(theme.density == .regular)
        #expect(theme.patternOverrides.isEmpty)
    }

    @Test("config(for:) layers global tokens, density and motion over the pattern default")
    @MainActor
    func configResolution() {
        var theme = LabTheme(name: "T", accentColor: .red, cornerStyle: .sharp, elevation: .elevated, density: .compact, motionSpeedMultiplier: 2)
        let base = ButtonsPattern.defaultConfig

        let resolved = theme.config(for: ButtonsPattern.self)
        #expect(resolved.cornerStyle == .sharp)
        #expect(resolved.elevation == .elevated)
        #expect(resolved.spacing == base.spacing * 0.75)
        #expect(resolved.duration == base.duration / 2)
        #expect(resolved.cornerRadius == base.cornerRadius)

        var override = resolved
        override.cornerRadius = 4
        theme.setOverride(override, for: ButtonsPattern.name)
        #expect(theme.config(for: ButtonsPattern.self).cornerRadius == 4)

        theme.clearOverride(for: ButtonsPattern.name)
        #expect(theme.config(for: ButtonsPattern.self).cornerRadius == base.cornerRadius)
    }

    @Test("suggestedFileName follows the Themes/ convention")
    func fileName() {
        #expect(LabTheme(name: "ToDo Project").suggestedFileName == "todo-project.json")
        #expect(LabTheme(name: "  ").suggestedFileName == "theme.json")
    }
}

@Suite("LabThemeStore")
@MainActor
struct LabThemeStoreTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "AppleAppLabUITests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("Saving, applying and reloading persists the library and the active theme")
    func persistence() throws {
        let defaults = makeDefaults()
        let store = LabThemeStore(storageKey: "test.LabThemes", defaults: defaults)
        store.active.cornerStyle = .rounded
        let saved = store.saveActive(as: "Mine")
        #expect(store.saved.count == 1)
        #expect(store.activeSavedID == saved.id)

        let reloaded = LabThemeStore(storageKey: "test.LabThemes", defaults: defaults)
        #expect(reloaded.saved.map(\.name) == ["Mine"])
        #expect(reloaded.active.cornerStyle == .rounded)
        #expect(reloaded.activeSavedID == saved.id)
    }

    @Test("Bundled themes merge by name without overwriting a user's saved copy")
    func bundledMerge() {
        let defaults = makeDefaults()
        var mine = LabTheme(name: "Fintrol")
        mine.elevation = .elevated
        let first = LabThemeStore(storageKey: "test.LabThemes", defaults: defaults)
        first.apply(mine)
        _ = first.saveActive(as: "Fintrol")

        let bundled = LabTheme(name: "Fintrol", elevation: .flat)
        let second = LabThemeStore(storageKey: "test.LabThemes", defaults: defaults, bundledThemes: [bundled, LabTheme(name: "Todocky")])
        #expect(second.saved.map(\.name).sorted() == ["Fintrol", "Todocky"])
        #expect(second.saved.first { $0.name == "Fintrol" }?.elevation == .elevated)
    }

    @Test("Saving while a component inspector is open captures that override")
    func editingOverrideCaptured() {
        let store = LabThemeStore(storageKey: "test.LabThemes", defaults: makeDefaults())
        var config = ButtonsPattern.defaultConfig
        config.cornerRadius = 3
        store.editingPatternName = ButtonsPattern.name
        store.editingPatternConfig = config

        let saved = store.saveActive(as: "WithButtons")
        #expect(saved.patternOverrides[ButtonsPattern.name]?.cornerRadius == 3)
        #expect(store.config(for: ButtonsPattern.self).cornerRadius == 3)
    }

    @Test("Export produces JSON that imports back as an equivalent theme")
    func exportImport() throws {
        let store = LabThemeStore(storageKey: "test.LabThemes", defaults: makeDefaults())
        store.active.name = "Export Me"
        store.active.windowMaterial = .liquidGlass
        let data = try store.exportActiveJSON()
        let imported = try store.importJSON(data)
        #expect(imported.name == "Export Me")
        #expect(imported.windowMaterial == .liquidGlass)
        #expect(imported.id != store.active.id)
    }

    @Test("Reset returns to the default and clears the active saved link")
    func reset() {
        let store = LabThemeStore(storageKey: "test.LabThemes", defaults: makeDefaults())
        _ = store.saveActive(as: "X")
        store.reset()
        #expect(store.activeSavedID == nil)
        #expect(store.active == .default)
    }
}
