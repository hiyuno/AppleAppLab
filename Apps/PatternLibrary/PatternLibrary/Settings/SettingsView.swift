import SwiftUI
import AppleAppLabUI

struct SettingsView: View {
    let category: SettingsCategory

    @Environment(AppSettings.self) private var appSettings
    @Environment(ThemeStore.self) private var themeStore

    @State private var newThemeName = ""
    @State private var themeToRename: Theme?
    @State private var renameText = ""

    private static let suggestedAccents: [(name: String, color: Color)] = [
        ("Indigo", Color(nsColor: .systemIndigo)),
        ("Blue", Color(nsColor: .systemBlue)),
        ("Teal", Color(nsColor: .systemTeal)),
        ("Purple", Color(nsColor: .systemPurple)),
        ("Pink", Color(nsColor: .systemPink))
    ]

    var body: some View {
        Form {
            switch category {
            case .themes: themesSection()
            case .color: colorSection()
            case .typography: typographySection()
            case .shape: shapeSection()
            case .elevation: elevationSection()
            case .iconography: iconographySection()
            case .motion: motionSection()
            case .density: densitySection()
            case .window: windowSection()
            }
        }
        .formStyle(.grouped)
        .navigationTitle(category.label)
        .frame(maxWidth: 760)
    }

    // MARK: - Themes

    @ViewBuilder
    private func themesSection() -> some View {
        @Bindable var appSettings = appSettings

        Section("Temas") {
            if themeStore.themes.isEmpty {
                Text("No hay temas guardados todavía.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(themeStore.themes) { theme in
                    HStack(spacing: 12) {
                        Button {
                            themeStore.apply(theme, to: appSettings)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: themeStore.activeThemeID == theme.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(themeStore.activeThemeID == theme.id ? appSettings.accentColor : .secondary)
                                Text(theme.name)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Apply theme \(theme.name)")

                        Button {
                            themeStore.update(theme, from: appSettings)
                        } label: {
                            Image(systemName: "tray.and.arrow.down.fill")
                        }
                        .buttonStyle(.borderless)
                        .help("Update this theme with the current settings")
                        .accessibilityLabel("Update theme \(theme.name)")

                        Button {
                            themeToRename = theme
                            renameText = theme.name
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .help("Rename")
                        .accessibilityLabel("Rename theme \(theme.name)")

                        Button(role: .destructive) {
                            themeStore.delete(theme)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Delete")
                        .accessibilityLabel("Delete theme \(theme.name)")
                    }
                }
            }

            HStack {
                TextField("New theme name", text: $newThemeName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(saveNewTheme)
                Button("Save Current", action: saveNewTheme)
                    .disabled(newThemeName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Text("Guarda el estado completo de Settings — accent, forma, ventana, wallpaper, tipografía, densidad, motion, etc. — para poder volver a él después. El ícono de guardar sobrescribe el tema con los settings actuales.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .alert(
            "Rename Theme",
            isPresented: Binding(
                get: { themeToRename != nil },
                set: { if !$0 { themeToRename = nil } }
            )
        ) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { themeToRename = nil }
            Button("Save") {
                if let theme = themeToRename {
                    themeStore.rename(theme, to: renameText.trimmingCharacters(in: .whitespaces))
                }
                themeToRename = nil
            }
        }
    }

    // MARK: - Color (Mode + Accent + Suggested)

    @ViewBuilder
    private func colorSection() -> some View {
        @Bindable var appSettings = appSettings

        Section("Modo") {
            HStack(spacing: 16) {
                ForEach(AppearanceMode.allCases) { mode in
                    Button {
                        appSettings.appearanceMode = mode
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: mode.symbolName)
                                .font(.title3)
                                .frame(width: 56, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(appSettings.accentColor.opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .strokeBorder(
                                                    appSettings.accentColor,
                                                    lineWidth: appSettings.appearanceMode == mode ? 2 : 1
                                                )
                                        )
                                )
                                .foregroundStyle(appSettings.accentColor)
                            Text(mode.label)
                                .font(.caption2)
                                .foregroundStyle(appSettings.appearanceMode == mode ? .primary : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Use \(mode.label) appearance")
                    .accessibilityAddTraits(appSettings.appearanceMode == mode ? [.isSelected] : [])
                }
            }
            Text("Fuerza Light o Dark para toda la app sin cambiar la configuración de macOS. System sigue la apariencia del sistema.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("Apariencia") {
            ColorPicker("Accent Color", selection: $appSettings.accentColor)
                .accessibilityLabel("Global accent color")

            AccentPaletteView(palette: AccentPalette(base: appSettings.accentColor))
                .padding(.vertical, 4)

            Text("Este color es el default con el que arranca cada pattern al seleccionarlo. La paleta de arriba (tonos 50–900 y tokens semánticos) se genera automáticamente desde este accent, igual que documenta DESIGN_LIQUID.md.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("Sugeridos") {
            HStack(spacing: 12) {
                ForEach(Self.suggestedAccents, id: \.name) { suggestion in
                    Button {
                        appSettings.accentColor = suggestion.color
                    } label: {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(suggestion.color)
                                .frame(width: 28, height: 28)
                            Text(suggestion.name)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Use \(suggestion.name) as accent color")
                }
            }
            Text("Colores dinámicos del sistema de Apple: evitan choque con rojo/verde/naranja (reservados para error/éxito/advertencia) y mantienen contraste correcto en Light, Dark y Increase Contrast.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Typography

    @ViewBuilder
    private func typographySection() -> some View {
        @Bindable var appSettings = appSettings

        Section("Tipografía") {
            Picker("Font Design", selection: $appSettings.fontDesign) {
                ForEach(FontDesignOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Font design")

            Picker("Base Weight", selection: $appSettings.fontWeight) {
                ForEach(FontWeightOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Base font weight")

            VStack(alignment: .leading, spacing: 6) {
                Text("The quick fox")
                    .font(.title2.bold())
                    .fontDesign(appSettings.fontDesign.design)
                Text("Body text sample, no explicit weight — this is what Base Weight actually changes.")
                    .font(.body)
                    .fontDesign(appSettings.fontDesign.design)
                    .fontWeight(appSettings.fontWeight.weight)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .accessibilityHidden(true)

            Text("Font Design cambia toda la tipografía. Base Weight solo afecta texto que no define su propio peso explícito (body, captions) — labels con peso fijo como los botones no cambian.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Shape

    @ViewBuilder
    private func shapeSection() -> some View {
        @Bindable var appSettings = appSettings

        Section("Forma") {
            HStack(spacing: 16) {
                ForEach(CornerStyle.allCases) { style in
                    Button {
                        appSettings.cornerStyle = style
                    } label: {
                        VStack(spacing: 6) {
                            LabShape(radius: 14, style: style)
                                .fill(appSettings.accentColor.opacity(0.2))
                                .overlay(
                                    LabShape(radius: 14, style: style)
                                        .strokeBorder(
                                            appSettings.accentColor,
                                            lineWidth: appSettings.cornerStyle == style ? 2 : 1
                                        )
                                )
                                .frame(width: 56, height: 56)
                            Text(style.label)
                                .font(.caption2)
                                .foregroundStyle(appSettings.cornerStyle == style ? .primary : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Use \(style.label) corners")
                    .accessibilityAddTraits(appSettings.cornerStyle == style ? [.isSelected] : [])
                }
            }
            Text("Sharp usa esquinas rectas, Rounded el arco circular clásico, Squircle la superelipse continua que recomienda Apple HIG. Se aplica a todos los patterns.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Elevation

    @ViewBuilder
    private func elevationSection() -> some View {
        @Bindable var appSettings = appSettings

        Section("Elevación") {
            twoColumn {
                HStack(spacing: 16) {
                    ForEach(ElevationLevel.allCases) { level in
                        Button {
                            appSettings.elevation = level
                        } label: {
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .frame(width: 56, height: 40)
                                    .shadow(
                                        color: .black.opacity(level == .flat ? 0 : level == .subtle ? 0.2 : 0.4),
                                        radius: level == .flat ? 0 : level == .subtle ? 4 : 10,
                                        y: level == .flat ? 0 : level == .subtle ? 2 : 5
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(
                                                appSettings.accentColor,
                                                lineWidth: appSettings.elevation == level ? 2 : 0
                                            )
                                    )
                                Text(level.label)
                                    .font(.caption2)
                                    .foregroundStyle(appSettings.elevation == level ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Use \(level.label) elevation")
                        .accessibilityAddTraits(appSettings.elevation == level ? [.isSelected] : [])
                    }
                }
            } example: {
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(appSettings.accentColor.opacity(0.15))
                        .frame(height: 50)
                    Text("Card title")
                        .font(.caption.bold())
                }
                .padding(12)
                .frame(width: 150)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .labShadow(appSettings.elevation)
                )
                .padding(20)
            }
            Text("Intensidad de sombra en cards, la ventana simulada y el botón primario. Flat elimina la sombra por completo.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Iconography

    @ViewBuilder
    private func iconographySection() -> some View {
        @Bindable var appSettings = appSettings

        Section("Iconografía") {
            twoColumn {
                Picker("Symbol Rendering", selection: $appSettings.iconRenderingMode) {
                    ForEach(IconRenderingMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("SF Symbols rendering mode")
            } example: {
                HStack(spacing: 20) {
                    ForEach(["cloud.sun.fill", "star.fill", "flag.fill"], id: \.self) { symbol in
                        Image(systemName: symbol)
                            .font(.system(size: 30))
                            .symbolRenderingMode(appSettings.iconRenderingMode.mode)
                            .foregroundStyle(appSettings.accentColor)
                    }
                }
                .padding(20)
            }
            Text("Modo de renderizado de todos los SF Symbols dentro de la ventana simulada.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Motion

    @ViewBuilder
    private func motionSection() -> some View {
        @Bindable var appSettings = appSettings

        Section("Motion") {
            twoColumn {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Motion Speed")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1fx", appSettings.motionSpeedMultiplier))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $appSettings.motionSpeedMultiplier, in: 0.5...2.0)
                        .accessibilityLabel("Global motion speed multiplier")
                }
            } example: {
                MotionSpeedExample(speed: appSettings.motionSpeedMultiplier, color: appSettings.accentColor)
                    .padding(20)
            }
            Text("Multiplica la velocidad de todas las animaciones de todos los patterns a la vez, además del ajuste individual que sigue disponible en cada inspector.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Density

    @ViewBuilder
    private func densitySection() -> some View {
        @Bindable var appSettings = appSettings

        Section("Densidad") {
            Picker("Density", selection: $appSettings.density) {
                ForEach(Density.allCases) { density in
                    Text(density.label).tag(density)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Layout density")

            VStack(spacing: 8 * appSettings.density.scale) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(appSettings.accentColor.opacity(0.15))
                        .frame(height: 22)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .accessibilityHidden(true)

            Text("Escala el spacing de cada pattern relativo a su propio default — Compact para densidad tipo Xcode, Comfortable para más aire tipo Notes.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Window (Material/Background/Blur/Transparency/Traffic Lights + Wallpaper)

    @ViewBuilder
    private func windowSection() -> some View {
        @Bindable var appSettings = appSettings

        Section("Ventana") {
            twoColumn {
                HStack(spacing: 16) {
                    ForEach(WindowMaterial.allCases) { material in
                        Button {
                            appSettings.windowMaterial = material
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: material.symbolName)
                                    .font(.title3)
                                    .frame(width: 56, height: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(appSettings.accentColor.opacity(0.15))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .strokeBorder(
                                                        appSettings.accentColor,
                                                        lineWidth: appSettings.windowMaterial == material ? 2 : 1
                                                    )
                                            )
                                    )
                                    .foregroundStyle(appSettings.accentColor)
                                Text(material.label)
                                    .font(.caption2)
                                    .foregroundStyle(appSettings.windowMaterial == material ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Use \(material.label) window material")
                        .accessibilityAddTraits(appSettings.windowMaterial == material ? [.isSelected] : [])
                    }
                }

                ColorPicker("Background Color", selection: $appSettings.backgroundColor)
                    .accessibilityLabel("Preview window background color")

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Blur Intensity")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.0f%%", appSettings.blurIntensity * 100))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $appSettings.blurIntensity, in: 0...1)
                        .accessibilityLabel("Frost and Liquid Glass blur intensity")
                    Text("Solo afecta Frost y Liquid Glass — Solid no tiene blur.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .disabled(appSettings.windowMaterial == .solid)
                .opacity(appSettings.windowMaterial == .solid ? 0.4 : 1)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Transparency")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.0f%%", appSettings.transparency * 100))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $appSettings.transparency, in: 0...1)
                        .accessibilityLabel("Frost and Liquid Glass transparency")
                    Text("Qué tanto se ve el fondo a través de la ventana — separado de Blur Intensity, que controla qué tan difuminado se ve.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .disabled(appSettings.windowMaterial == .solid)
                .opacity(appSettings.windowMaterial == .solid ? 0.4 : 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Title Bar")
                        .font(.subheadline)
                    Picker("Title Bar", selection: $appSettings.titleBarStyle) {
                        ForEach(WindowTitleBarStyle.allCases) { style in
                            Text(style.label).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel("Window title bar style")
                    Text("Full muestra los traffic lights. Compact deja la barra sin puntos. None quita la barra por completo — útil para paneles o popovers sin chrome.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } example: {
                ZStack {
                    windowExampleBackground
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    LabWindowFrame(
                        backgroundColor: appSettings.backgroundColor,
                        cornerStyle: appSettings.cornerStyle,
                        material: appSettings.windowMaterial,
                        titleBarStyle: appSettings.titleBarStyle,
                        elevation: appSettings.elevation,
                        blurIntensity: appSettings.blurIntensity,
                        transparency: appSettings.transparency
                    ) {
                        Text("Preview")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 200, height: 130)
                }
                .frame(width: 240, height: 170)
            }
            Text("Solid es un fondo opaco. Frost usa el material estándar de macOS (blur moderado). Liquid Glass es una aproximación visual al material de macOS 26 Tahoe — más luminoso y translúcido — hasta que ese SDK esté disponible aquí. Traffic lights son de la ventana simulada — independientes del corner style que aplica a los patterns.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("Wallpaper") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(WallpaperOption.all) { wallpaper in
                        Button {
                            appSettings.wallpaper = wallpaper
                        } label: {
                            VStack(spacing: 6) {
                                thumbnail(for: wallpaper)
                                    .frame(width: 72, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(
                                                appSettings.wallpaper == wallpaper ? appSettings.accentColor : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                Text(wallpaper.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(appSettings.wallpaper == wallpaper ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Use \(wallpaper.displayName) as wallpaper")
                        .accessibilityAddTraits(appSettings.wallpaper == wallpaper ? [.isSelected] : [])
                    }
                }
                .padding(.vertical, 4)
            }
            Text("El wallpaper se ve detrás de la ventana simulada — así previsualizas la ventana sobre un fondo real, no solo un color plano.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func saveNewTheme() {
        let name = newThemeName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        themeStore.save(name: name, from: appSettings)
        newThemeName = ""
    }

    @ViewBuilder
    private func twoColumn<Setting: View, Example: View>(
        @ViewBuilder setting: () -> Setting,
        @ViewBuilder example: () -> Example
    ) -> some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Setting")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                setting()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Example")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                example()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func thumbnail(for wallpaper: WallpaperOption) -> some View {
        if let image = wallpaper.image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Color(nsColor: .controlBackgroundColor)
                Image(systemName: "slash.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var windowExampleBackground: some View {
        if let image = appSettings.wallpaper.image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
        } else {
            LinearGradient(
                colors: [.green, .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct MotionSpeedExample: View {
    let speed: Double
    let color: Color

    @State private var moved = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 20, height: 20)
            .offset(x: moved ? 90 : 0)
            .frame(width: 110, height: 30, alignment: .leading)
            .task(id: speed) {
                moved = false
                try? await Task.sleep(nanoseconds: 50_000_000)
                withAnimation(.easeInOut(duration: 0.6 / speed).repeatForever(autoreverses: true)) {
                    moved = true
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    SettingsView(category: .color)
        .environment(AppSettings())
        .environment(ThemeStore())
}
