import SwiftUI
import AppleAppLabUI

@MainActor
struct PatternEntry: Identifiable {
    let id: String
    let name: String
    let symbolName: String
    let defaultConfig: PatternConfig
    let inspectableProperties: [InspectableProperty]
    let makePreview: (PatternConfig) -> AnyView

    init<P: InspectablePattern>(_ type: P.Type) {
        id = P.name
        name = P.name
        symbolName = P.symbolName
        defaultConfig = P.defaultConfig
        inspectableProperties = P.inspectableProperties
        makePreview = { AnyView(P.preview(config: $0)) }
    }

    init(placeholderName: String, symbolName: String) {
        id = placeholderName
        name = placeholderName
        self.symbolName = symbolName
        defaultConfig = PatternConfig()
        inspectableProperties = []
        makePreview = { _ in AnyView(ComingSoonView(name: placeholderName)) }
    }
}

struct ComingSoonView: View {
    let name: String

    var body: some View {
        ContentUnavailableView(
            name,
            systemImage: "hourglass",
            description: Text("Este pattern todavía no está implementado.")
        )
    }
}
