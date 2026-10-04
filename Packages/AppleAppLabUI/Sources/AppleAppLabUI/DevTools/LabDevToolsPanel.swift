#if DEBUG
import SwiftUI

/// The dev tools UI: three tabs that edit `LabThemeStore.active` live.
///
/// - **Tema**: global tokens — color, shape, elevation, typography, icons,
///   motion, density, window material.
/// - **Componentes**: one inspector per registered `InspectablePattern`; edits
///   become `patternOverrides` on the active theme.
/// - **Temas**: saved library, save/update/rename/delete, export JSON for
///   `Themes/`, import from clipboard, reset.
public struct LabDevToolsPanel: View {
    @Environment(LabThemeStore.self) private var store
    @State private var tab: Tab = .theme

    enum Tab: String, CaseIterable, Identifiable {
        case theme = "Tema", components = "Componentes", library = "Temas"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .theme: "paintpalette"
            case .components: "square.grid.2x2"
            case .library: "tray.full"
            }
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            Picker("Sección", selection: $tab) {
                ForEach(Tab.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)

            Divider()

            switch tab {
            case .theme: ThemeTab()
            case .components: ComponentsTab()
            case .library: LibraryTab()
            }
        }
        .navigationTitle("Dev Tools")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Tema

private struct ThemeTab: View {
    @Environment(LabThemeStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            Section("Color") {
                segmentedButtons(AppearanceMode.allCases, selection: $store.active.appearanceMode) { Image(systemName: $0.symbolName) } label: { $0.label }
                colorRow("Accent", $store.active.accentColor)
                colorRow("Fondo de ventana", $store.active.backgroundColor)
                AccentPaletteView(palette: AccentPalette(base: store.active.accentColor.color))
            }

            Section("Forma y elevación") {
                segmentedButtons(CornerStyle.allCases, selection: $store.active.cornerStyle) { style in
                    LabShape(radius: 8, style: style).fill(.secondary.opacity(0.4)).frame(width: 22, height: 22)
                } label: { $0.label }
                Picker("Elevación", selection: $store.active.elevation) {
                    ForEach(ElevationLevel.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Tipografía e iconos") {
                Picker("Diseño", selection: $store.active.fontDesign) {
                    ForEach(FontDesignOption.allCases) { Text($0.label).tag($0) }
                }
                Picker("Peso base", selection: $store.active.fontWeight) {
                    ForEach(FontWeightOption.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("SF Symbols", selection: $store.active.iconRenderingMode) {
                    ForEach(IconRenderingMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("The quick fox jumps")
                    .font(.title3)
                    .fontDesign(store.active.fontDesign.design)
                    .fontWeight(store.active.fontWeight.weight)
                    .accessibilityHidden(true)
            }

            Section("Densidad y motion") {
                Picker("Densidad", selection: $store.active.density) {
                    ForEach(Density.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                slider("Velocidad de animación", value: $store.active.motionSpeedMultiplier, in: 0.5...2.0, format: "%.1fx")
            }

            Section("Ventana") {
                segmentedButtons(WindowMaterial.allCases, selection: $store.active.windowMaterial) { Image(systemName: $0.symbolName) } label: { $0.label }
                slider("Blur", value: $store.active.blurIntensity, in: 0...1, format: "%.0f%%", scale: 100)
                    .disabled(store.active.windowMaterial == .solid)
                slider("Transparencia", value: $store.active.transparency, in: 0...1, format: "%.0f%%", scale: 100)
                    .disabled(store.active.windowMaterial == .solid)
                Picker("Barra de título", selection: $store.active.titleBarStyle) {
                    ForEach(WindowTitleBarStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                LabWindowFrame(
                    backgroundColor: store.active.backgroundColor.color,
                    cornerStyle: store.active.cornerStyle,
                    material: store.active.windowMaterial,
                    titleBarStyle: store.active.titleBarStyle,
                    elevation: store.active.elevation,
                    blurIntensity: store.active.blurIntensity,
                    transparency: store.active.transparency
                ) {
                    Text("Preview").font(.caption).foregroundStyle(.secondary)
                }
                .frame(height: 120)
                .padding(.vertical, 4)
                .background(LinearGradient(colors: [.green.opacity(0.6), .black.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .formStyle(.grouped)
    }

    private func colorRow(_ label: String, _ binding: Binding<CodableColor>) -> some View {
        HStack {
            ColorPicker(label, selection: Binding(get: { binding.wrappedValue.color }, set: { binding.wrappedValue = CodableColor($0) }))
            Text(binding.wrappedValue.hexString).font(.caption.monospaced()).foregroundStyle(.secondary)
        }
    }

    private func slider(_ label: String, value: Binding<Double>, in range: ClosedRange<Double>, format: String, scale: Double = 1) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text(String(format: format, value.wrappedValue * scale)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range).accessibilityLabel(label)
        }
    }

    private func segmentedButtons<T: Hashable & Identifiable, Icon: View>(
        _ options: [T], selection: Binding<T>, @ViewBuilder icon: @escaping (T) -> Icon, label: @escaping (T) -> String
    ) -> some View {
        HStack(spacing: 10) {
            ForEach(options) { option in
                let selected = selection.wrappedValue == option
                Button { selection.wrappedValue = option } label: {
                    VStack(spacing: 4) {
                        icon(option)
                            .frame(width: 44, height: 32)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.tint.opacity(selected ? 0.18 : 0.06)))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.tint, lineWidth: selected ? 2 : 0))
                        Text(label(option)).font(.caption2).foregroundStyle(selected ? .primary : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label(option))
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
    }
}

// MARK: - Componentes

private struct ComponentsTab: View {
    @Environment(LabThemeStore.self) private var store
    @State private var selected: LabPatternEntry?

    var body: some View {
        if let entry = selected {
            ComponentDetail(entry: entry) { selected = nil }
        } else {
            List(LabPatternRegistry.all) { entry in
                Button { selected = entry } label: {
                    HStack {
                        Label(entry.name, systemImage: entry.symbolName)
                        Spacer()
                        if store.active.patternOverrides[entry.name] != nil {
                            Image(systemName: "slider.horizontal.3").foregroundStyle(.tint).accessibilityLabel("Con override")
                        }
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }
}

private struct ComponentDetail: View {
    let entry: LabPatternEntry
    let onBack: () -> Void

    @Environment(LabThemeStore.self) private var store
    @State private var config: PatternConfig = PatternConfig()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button(action: onBack) { Label("Componentes", systemImage: "chevron.left") }.buttonStyle(.plain).foregroundStyle(.tint)
                    Spacer()
                    if store.active.patternOverrides[entry.name] != nil {
                        Button("Quitar override") {
                            store.active.clearOverride(for: entry.name)
                            config = store.config(for: entry.name, base: entry.defaultConfig)
                        }
                        .font(.caption)
                    }
                }
                Text(entry.name).font(.headline)

                entry.makePreview(config)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.background))

                LabPatternInspector(properties: entry.inspectableProperties, config: $config) {
                    store.active.setOverride(config, for: entry.name)
                    store.editingPatternName = entry.name
                    store.editingPatternConfig = config
                }
            }
            .padding(16)
        }
        .onAppear {
            config = store.config(for: entry.name, base: entry.defaultConfig)
            store.editingPatternName = entry.name
            store.editingPatternConfig = config
        }
        .onDisappear {
            store.editingPatternName = nil
            store.editingPatternConfig = nil
        }
    }
}

// MARK: - Temas

private struct LibraryTab: View {
    @Environment(LabThemeStore.self) private var store
    @State private var newName = ""
    @State private var renaming: LabTheme?
    @State private var renameText = ""
    @State private var status: String?
    @State private var exportURL: URL?

    var body: some View {
        Form {
            Section("Activo: \(store.active.name)") {
                HStack {
                    TextField("Guardar como…", text: $newName).onSubmit(saveNew)
                    Button("Guardar", action: saveNew).disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Button("Actualizar tema guardado", action: store.updateActiveSavedTheme).disabled(store.activeSavedID == nil)
                Button("Exportar JSON (copiar)", action: exportToClipboard)
                #if os(iOS)
                if let url = exportURL {
                    ShareLink(item: url) { Label("Compartir \(url.lastPathComponent)", systemImage: "square.and.arrow.up") }
                }
                #else
                Button("Guardar JSON en Themes/…", action: exportToFile)
                #endif
                Button("Importar JSON del portapapeles", action: importFromClipboard)
                Button("Reset al default", role: .destructive) { store.reset() }
                if let status { Text(status).font(.caption).foregroundStyle(.secondary) }
            }

            Section("Guardados") {
                if store.saved.isEmpty {
                    Text("Sin temas guardados. Los JSON de Themes/ aparecen aquí si la app los incluye en el bundle.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(store.saved) { theme in
                    HStack(spacing: 10) {
                        Circle().fill(theme.accentColor.color).frame(width: 14, height: 14)
                        Button(theme.name) { store.apply(theme) }.buttonStyle(.plain)
                        if store.activeSavedID == theme.id { Image(systemName: "checkmark").foregroundStyle(.tint) }
                        Spacer()
                        Button { renaming = theme; renameText = theme.name } label: { Image(systemName: "pencil") }.buttonStyle(.borderless)
                        Button(role: .destructive) { store.delete(theme) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .alert("Renombrar", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Nombre", text: $renameText)
            Button("Cancelar", role: .cancel) { renaming = nil }
            Button("Guardar") {
                if let theme = renaming { store.rename(theme, to: renameText.trimmingCharacters(in: .whitespaces)) }
                renaming = nil
            }
        }
    }

    private func saveNew() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        store.saveActive(as: name)
        newName = ""
        status = "Guardado \"\(name)\""
    }

    private func exportToClipboard() {
        do {
            let data = try store.exportActiveJSON()
            LabPasteboard.copy(String(decoding: data, as: UTF8.self))
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(store.active.suggestedFileName)
            try data.write(to: url)
            exportURL = url
            status = "JSON copiado. Pégalo en Themes/\(store.active.suggestedFileName) y Jonny lo adopta."
        } catch {
            status = "No se pudo exportar: \(error.localizedDescription)"
        }
    }

    #if os(macOS)
    private func exportToFile() {
        do {
            let data = try store.exportActiveJSON()
            let panel = NSSavePanel()
            panel.nameFieldStringValue = store.active.suggestedFileName
            panel.allowedContentTypes = [.json]
            if panel.runModal() == .OK, let url = panel.url {
                try data.write(to: url)
                status = "Guardado en \(url.lastPathComponent)"
            }
        } catch {
            status = "No se pudo guardar: \(error.localizedDescription)"
        }
    }
    #endif

    private func importFromClipboard() {
        guard let text = LabPasteboard.read(), let data = text.data(using: .utf8) else {
            status = "El portapapeles no tiene texto."
            return
        }
        do {
            let theme = try store.importJSON(data)
            status = "Importado \"\(theme.name)\""
        } catch {
            status = "JSON inválido: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack { LabDevToolsPanel() }
        .environment(LabThemeStore(storageKey: "preview.LabThemes", defaults: UserDefaults(suiteName: "preview")!))
        .frame(width: 360, height: 640)
}
#endif
