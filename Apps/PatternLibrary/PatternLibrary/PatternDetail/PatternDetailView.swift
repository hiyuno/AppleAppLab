import SwiftUI
import AppleAppLabUI

struct PatternDetailView: View {
    let entry: PatternEntry
    @State private var inspector: InspectorViewModel
    @Environment(AppSettings.self) private var appSettings
    @Environment(ThemeStore.self) private var themeStore

    init(entry: PatternEntry) {
        self.entry = entry
        _inspector = State(initialValue: InspectorViewModel(config: entry.defaultConfig))
    }

    var body: some View {
        HStack(spacing: 0) {
            previewArea
                .frame(minWidth: 240, maxWidth: .infinity, maxHeight: .infinity)

            if !entry.inspectableProperties.isEmpty {
                Divider()
                InspectorView(properties: entry.inspectableProperties, viewModel: inspector)
                    .frame(minWidth: 260, idealWidth: 280, maxWidth: 280)
                    .fixedSize(horizontal: false, vertical: false)
            }
        }
        // Guarantees the detail column of NavigationSplitView never shrinks below what
        // preview + inspector need — without this, the inspector can get clipped off
        // the right edge instead of the window/sidebar giving up space first.
        .frame(minWidth: entry.inspectableProperties.isEmpty ? 240 : 520)
        .navigationTitle(entry.name)
        .onAppear { applyThemeToInspector() }
        .onChange(of: themeStore.activeThemeID) { applyThemeToInspector() }
    }

    private func applyThemeToInspector() {
        let base = entry.defaultConfig
        inspector.config.accentColor = appSettings.accentColor
        inspector.config.cornerStyle = appSettings.cornerStyle
        inspector.config.elevation = appSettings.elevation
        inspector.config.spacing = base.spacing * appSettings.density.scale
        inspector.config.duration = base.duration / appSettings.motionSpeedMultiplier

        // Layer any settings saved for this specific pattern under the active
        // theme on top of the global ones above.
        if let activeTheme = themeStore.themes.first(where: { $0.id == themeStore.activeThemeID }),
           let override = activeTheme.patternOverrides[entry.name] {
            override.apply(to: &inspector.config)
        }

        themeStore.activePatternName = entry.name
        themeStore.activePatternConfig = inspector.config
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
                entry.makePreview(inspector.config)
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
