import SwiftUI
import AppleAppLabUI

struct PatternDetailView: View {
    let entry: LabPatternEntry
    @State private var config: PatternConfig
    @Environment(AppSettings.self) private var appSettings
    @Environment(LabThemeStore.self) private var themeStore

    init(entry: LabPatternEntry) {
        self.entry = entry
        _config = State(initialValue: entry.defaultConfig)
    }

    var body: some View {
        HStack(spacing: 0) {
            previewArea
                .frame(minWidth: 240, maxWidth: .infinity, maxHeight: .infinity)

            if !entry.inspectableProperties.isEmpty {
                Divider()
                ScrollView {
                    LabPatternInspector(properties: entry.inspectableProperties, config: $config) {
                        themeStore.editingPatternConfig = config
                    }
                    .padding(16)
                }
                .background(.regularMaterial)
                .frame(minWidth: 260, idealWidth: 280, maxWidth: 280)
            }
        }
        // Guarantees the detail column of NavigationSplitView never shrinks below what
        // preview + inspector need — without this, the inspector can get clipped off
        // the right edge instead of the window/sidebar giving up space first.
        .frame(minWidth: entry.inspectableProperties.isEmpty ? 240 : 520)
        .navigationTitle(entry.name)
        .onAppear { applyThemeToInspector() }
        .onChange(of: themeStore.activeSavedID) { applyThemeToInspector() }
    }

    /// Pattern defaults + the global settings + any override saved for this
    /// pattern under the active theme — the same resolution `LabTheme.config(for:)`
    /// does inside an app, driven here by the live `AppSettings`.
    private func applyThemeToInspector() {
        var theme = appSettings.theme(named: themeStore.active.name)
        theme.patternOverrides = themeStore.active.patternOverrides
        config = theme.config(for: entry.name, base: entry.defaultConfig)
        themeStore.editingPatternName = entry.name
        themeStore.editingPatternConfig = config
    }

    private var previewArea: some View {
        ZStack {
            wallpaperBackground

            LabWindowFrame(
                backgroundColor: appSettings.backgroundColor,
                cornerStyle: appSettings.cornerStyle,
                material: appSettings.windowMaterial,
                titleBarStyle: appSettings.titleBarStyle,
                elevation: appSettings.elevation,
                blurIntensity: appSettings.blurIntensity,
                transparency: appSettings.transparency
            ) {
                entry.makePreview(config)
                    .fontDesign(appSettings.fontDesign.design)
                    .fontWeight(appSettings.fontWeight.weight)
                    .symbolRenderingMode(appSettings.iconRenderingMode.mode)
            }
            .frame(minWidth: 320, idealWidth: 640, maxWidth: 640, minHeight: 220, idealHeight: 420, maxHeight: 420)
            .padding(40)
        }
    }

    @ViewBuilder
    private var wallpaperBackground: some View {
        if let image = appSettings.wallpaper.image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
        } else {
            Color(nsColor: .underPageBackgroundColor)
        }
    }
}
