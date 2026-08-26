import SwiftUI

public enum ListsPattern: InspectablePattern {
    public static let name = "Listas/tablas"
    public static let symbolName = "list.bullet"

    public static let defaultConfig = PatternConfig(
        spacing: 8,
        cornerRadius: 10,
        accentColor: ColorTokens.accent
    )

    public static let inspectableProperties: [InspectableProperty] = [
        .spacing(label: "Row Spacing", keyPath: \.spacing, range: 0...24),
        .cornerRadius(label: "Row Corner Radius", keyPath: \.cornerRadius, range: 0...20),
        .color(label: "Icon Color", keyPath: \.accentColor)
    ]

    public static func preview(config: PatternConfig) -> some View {
        LabList(
            rows: [
                LabListRow(title: "Downloads", subtitle: "128 items", symbolName: "arrow.down.circle"),
                LabListRow(title: "Documents", subtitle: "56 items", symbolName: "doc"),
                LabListRow(title: "Photos", subtitle: "1,204 items", symbolName: "photo")
            ],
            config: config
        )
        .frame(maxWidth: 320)
    }
}

#Preview {
    ListsPattern.preview(config: ListsPattern.defaultConfig)
        .padding()
}
