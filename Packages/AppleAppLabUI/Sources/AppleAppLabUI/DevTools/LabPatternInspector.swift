import SwiftUI

/// Renders a pattern's `inspectableProperties` as live controls bound to a
/// `PatternConfig`. Shared by the in-app dev tools and PatternLibrary.
public struct LabPatternInspector: View {
    let properties: [InspectableProperty]
    @Binding var config: PatternConfig
    var onChange: (() -> Void)? = nil

    @State private var didCopy = false

    public init(properties: [InspectableProperty], config: Binding<PatternConfig>, onChange: (() -> Void)? = nil) {
        self.properties = properties
        self._config = config
        self.onChange = onChange
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(properties) { property in
                control(for: property)
            }
            if !colorProperties.isEmpty {
                Divider()
                colorPromptSection
            }
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private func control(for property: InspectableProperty) -> some View {
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
            VStack(alignment: .leading, spacing: 0) {
                Divider().padding(.bottom, 4)
                Text(label).font(.subheadline.bold())
            }
            .padding(.top, 4)
            .accessibilityAddTraits(.isHeader)
        }
    }

    private func floatSlider(label: String, keyPath: WritableKeyPath<PatternConfig, CGFloat>, range: ClosedRange<CGFloat>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            header(label, value: String(format: format, config[keyPath: keyPath]))
            Slider(value: Binding(get: { config[keyPath: keyPath] }, set: { config[keyPath: keyPath] = $0; onChange?() }), in: range)
                .accessibilityLabel(label)
        }
    }

    private func doubleSlider(label: String, keyPath: WritableKeyPath<PatternConfig, Double>, range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            header(label, value: String(format: format, config[keyPath: keyPath]))
            Slider(value: Binding(get: { config[keyPath: keyPath] }, set: { config[keyPath: keyPath] = $0; onChange?() }), in: range)
                .accessibilityLabel(label)
        }
    }

    private func colorControl(label: String, keyPath: WritableKeyPath<PatternConfig, Color>) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            ColorPicker("", selection: Binding(get: { config[keyPath: keyPath] }, set: { config[keyPath: keyPath] = $0; onChange?() }))
                .labelsHidden()
                .accessibilityLabel(label)
        }
    }

    private func pickerControl(label: String, keyPath: WritableKeyPath<PatternConfig, String>, options: [String]) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Picker(label, selection: Binding(get: { config[keyPath: keyPath] }, set: { config[keyPath: keyPath] = $0; onChange?() })) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .accessibilityLabel("\(label) picker")
        }
    }

    private func header(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text(value).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    // MARK: - Color prompt (paste into Jonny / Pen / Figma)

    private var colorProperties: [(label: String, color: Color)] {
        var section: String?
        var result: [(String, Color)] = []
        for property in properties {
            switch property {
            case .section(let label): section = label
            case .color(let label, let keyPath): result.append((section.map { "\($0) \(label)" } ?? label, config[keyPath: keyPath]))
            default: break
            }
        }
        return result
    }

    private var colorPrompt: String {
        "Aplica esta paleta:\n" + colorProperties.map { "- \($0.label): \(CodableColor($0.color).hexString)" }.joined(separator: "\n")
    }

    private var colorPromptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Colores").font(.subheadline.bold())
                Spacer()
                Button {
                    LabPasteboard.copy(colorPrompt)
                    didCopy = true
                    Task { try? await Task.sleep(for: .seconds(1.2)); didCopy = false }
                } label: {
                    Label(didCopy ? "Copiado" : "Copiar", systemImage: didCopy ? "checkmark" : "doc.on.doc").font(.caption)
                }
                .buttonStyle(.plain)
            }
            Text(colorPrompt)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.quaternary.opacity(0.3)))
        }
    }
}

enum LabPasteboard {
    static func copy(_ string: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = string
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }

    static func read() -> String? {
        #if canImport(UIKit)
        UIPasteboard.general.string
        #elseif canImport(AppKit)
        NSPasteboard.general.string(forType: .string)
        #else
        nil
        #endif
    }
}
