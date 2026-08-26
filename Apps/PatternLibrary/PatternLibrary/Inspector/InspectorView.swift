import SwiftUI
import AppKit
import AppleAppLabUI

struct InspectorView: View {
    let properties: [InspectableProperty]
    var viewModel: InspectorViewModel

    @Environment(ThemeStore.self) private var themeStore
    @State private var didCopy = false

    // Keeps the theme store's live snapshot of the on-screen pattern's config in
    // sync, so saving a theme from the sidebar captures whatever was just moved
    // here — the sidebar has no other way to see this view's local state.
    private func syncActivePatternConfig() {
        themeStore.activePatternConfig = viewModel.config
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(properties) { property in
                    propertyControl(for: property)
                }

                if !colorProperties.isEmpty {
                    Divider()
                    colorPromptSection
                }
            }
            .padding(16)
        }
        .background(.regularMaterial)
    }

    private var colorProperties: [(label: String, color: Color)] {
        var currentSection: String?
        var result: [(label: String, color: Color)] = []
        for property in properties {
            switch property {
            case .section(let label):
                currentSection = label
            case .color(let label, let keyPath):
                let fullLabel = currentSection.map { "\($0) \(label)" } ?? label
                result.append((fullLabel, viewModel.config[keyPath: keyPath]))
            default:
                break
            }
        }
        return result
    }

    private var colorPrompt: String {
        let lines = colorProperties.map { "- \($0.label): \(hexString(for: $0.color))" }
        return "Aplica esta paleta de colores a las tarjetas:\n" + lines.joined(separator: "\n")
    }

    private var colorPromptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Código")
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    copyPrompt()
                } label: {
                    Label(didCopy ? "Copiado" : "Copiar", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            Text(colorPrompt)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.quaternary.opacity(0.3))
                )
        }
    }

    private func hexString(for color: Color) -> String {
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    private func copyPrompt() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(colorPrompt, forType: .string)
        didCopy = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            didCopy = false
        }
    }

    @ViewBuilder
    private func propertyControl(for property: InspectableProperty) -> some View {
        switch property {
        case .spacing(let label, let keyPath, let range):
            floatSlider(label: label, keyPath: keyPath, range: range, format: "%.0f")
        case .cornerRadius(let label, let keyPath, let range):
            floatSlider(label: label, keyPath: keyPath, range: range, format: "%.0f")
        case .duration(let label, let keyPath, let range):
            doubleSlider(label: label, keyPath: keyPath, range: range, format: "%.2f")
        case .color(let label, let keyPath):
            colorControl(label: label, keyPath: keyPath)
        case .picker(let label, let keyPath, let options):
            pickerControl(label: label, keyPath: keyPath, options: options)
        case .section(let label):
            sectionHeader(label)
        }
    }

    private func sectionHeader(_ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.bottom, 4)
            Text(label)
                .font(.subheadline.bold())
        }
        .padding(.top, 4)
        .accessibilityAddTraits(.isHeader)
    }

    private func floatSlider(
        label: String,
        keyPath: WritableKeyPath<PatternConfig, CGFloat>,
        range: ClosedRange<CGFloat>,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            controlHeader(label: label, value: String(format: format, viewModel.config[keyPath: keyPath]))
            Slider(
                value: Binding(
                    get: { viewModel.config[keyPath: keyPath] },
                    set: { viewModel.config[keyPath: keyPath] = $0; syncActivePatternConfig() }
                ),
                in: range
            )
            .accessibilityLabel(label)
        }
    }

    private func doubleSlider(
        label: String,
        keyPath: WritableKeyPath<PatternConfig, Double>,
        range: ClosedRange<Double>,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            controlHeader(label: label, value: String(format: format, viewModel.config[keyPath: keyPath]))
            Slider(
                value: Binding(
                    get: { viewModel.config[keyPath: keyPath] },
                    set: { viewModel.config[keyPath: keyPath] = $0; syncActivePatternConfig() }
                ),
                in: range
            )
            .accessibilityLabel(label)
        }
    }

    private func colorControl(label: String, keyPath: WritableKeyPath<PatternConfig, Color>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            ColorPicker(
                "",
                selection: Binding(
                    get: { viewModel.config[keyPath: keyPath] },
                    set: { viewModel.config[keyPath: keyPath] = $0; syncActivePatternConfig() }
                )
            )
            .labelsHidden()
            .accessibilityLabel(label)
        }
    }

    private func pickerControl(
        label: String,
        keyPath: WritableKeyPath<PatternConfig, String>,
        options: [String]
    ) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Picker(
                label,
                selection: Binding(
                    get: { viewModel.config[keyPath: keyPath] },
                    set: { viewModel.config[keyPath: keyPath] = $0; syncActivePatternConfig() }
                )
            ) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .accessibilityLabel("\(label) picker")
        }
    }

    private func controlHeader(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
