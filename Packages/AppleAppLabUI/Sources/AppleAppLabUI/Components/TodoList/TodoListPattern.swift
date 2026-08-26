import SwiftUI

public enum TodoListPattern: InspectablePattern {
    public static let name = "Todo list (drag & drop)"
    public static let symbolName = "checklist"

    public static let defaultConfig = PatternConfig(
        spacing: 8,
        cornerRadius: 10,
        accentColor: ColorTokens.accent,
        duration: 0.35
    )

    public static let inspectableProperties: [InspectableProperty] = [
        .spacing(label: "Row Spacing", keyPath: \.spacing, range: 0...24),
        .cornerRadius(label: "Row Corner Radius", keyPath: \.cornerRadius, range: 0...20),
        .color(label: "Checkmark Color", keyPath: \.accentColor),
        .duration(label: "Reorder Response", keyPath: \.duration, range: 0.15...0.7)
    ]

    public static func preview(config: PatternConfig) -> some View {
        TodoListPreview(config: config)
    }
}

private struct TodoListPreview: View {
    let config: PatternConfig
    @State private var items = [
        LabTodoItem(title: "Diseñar el inspector", isDone: true),
        LabTodoItem(title: "Implementar drag & drop"),
        LabTodoItem(title: "Pulir animación de reorder"),
        LabTodoItem(title: "Agregar ghost slot punteado"),
        LabTodoItem(title: "Anuncios de VoiceOver"),
        LabTodoItem(title: "Mover con teclado (sin drag)")
    ]

    var body: some View {
        LabTodoList(items: $items, config: config)
            .frame(maxWidth: 320)
    }
}

#Preview {
    TodoListPattern.preview(config: TodoListPattern.defaultConfig)
        .padding()
}
