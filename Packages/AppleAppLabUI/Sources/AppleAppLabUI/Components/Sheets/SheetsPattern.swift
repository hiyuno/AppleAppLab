import SwiftUI

public enum SheetsPattern: InspectablePattern {
    public static let name = "Sheets/modales/alerts"
    public static let symbolName = "rectangle.portrait.on.rectangle.portrait"

    public static let defaultConfig = PatternConfig(
        spacing: 16,
        cornerRadius: 22,
        accentColor: ColorTokens.accent,
        duration: 0.3
    )

    public static let inspectableProperties: [InspectableProperty] = [
        .spacing(label: "Content Spacing", keyPath: \.spacing, range: 4...32),
        .cornerRadius(label: "Button Corner Radius", keyPath: \.cornerRadius, range: 8...28),
        .color(label: "Accent Color", keyPath: \.accentColor),
        .duration(label: "Button Response", keyPath: \.duration, range: 0.1...0.6)
    ]

    public static func preview(config: PatternConfig) -> some View {
        SheetsPreview(config: config)
    }
}

private struct SheetsPreview: View {
    let config: PatternConfig
    @State private var showingSheet = false

    var body: some View {
        LabButton(title: "Present Sheet", style: .primary, config: config) {
            showingSheet = true
        }
        .frame(maxWidth: 200)
        .sheet(isPresented: $showingSheet) {
            VStack(spacing: config.spacing) {
                Text("Sheet Title")
                    .font(.title2.bold())
                Text("This is a modal sheet preview — the same LabButton you tuned in the Botones pattern.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                LabButton(title: "Done", style: .primary, config: config) {
                    showingSheet = false
                }
            }
            .padding(24)
            .frame(width: 340, height: 220)
        }
    }
}

#Preview {
    SheetsPattern.preview(config: SheetsPattern.defaultConfig)
        .padding()
}
