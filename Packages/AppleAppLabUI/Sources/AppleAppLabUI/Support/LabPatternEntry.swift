import SwiftUI

/// Type-erased `InspectablePattern`, so the dev tools and PatternLibrary can list
/// every component without knowing its concrete type.
@MainActor
public struct LabPatternEntry: Identifiable {
    public let id: String
    public let name: String
    public let symbolName: String
    public let defaultConfig: PatternConfig
    public let inspectableProperties: [InspectableProperty]
    public let makePreview: (PatternConfig) -> AnyView

    public init<P: InspectablePattern>(_ type: P.Type) {
        id = P.name
        name = P.name
        symbolName = P.symbolName
        defaultConfig = P.defaultConfig
        inspectableProperties = P.inspectableProperties
        makePreview = { AnyView(P.preview(config: $0)) }
    }

    public init(placeholderName: String, symbolName: String) {
        id = placeholderName
        name = placeholderName
        self.symbolName = symbolName
        defaultConfig = PatternConfig()
        inspectableProperties = []
        makePreview = { _ in
            AnyView(
                ContentUnavailableView(
                    placeholderName,
                    systemImage: "hourglass",
                    description: Text("Este pattern todavía no está implementado.")
                )
            )
        }
    }
}

/// Every component the package ships, in catalog order, plus whatever an app
/// registers for its own inspectable views.
@MainActor
public enum LabPatternRegistry {
    public static let builtIn: [LabPatternEntry] = [
        LabPatternEntry(ButtonsPattern.self),
        LabPatternEntry(CheckboxRadioPattern.self),
        LabPatternEntry(NavigationPattern.self),
        LabPatternEntry(ListsPattern.self),
        LabPatternEntry(TodoListPattern.self),
        LabPatternEntry(CardsPattern.self),
        LabPatternEntry(FormsPattern.self),
        LabPatternEntry(SheetsPattern.self),
        LabPatternEntry(OnboardingPattern.self),
        LabPatternEntry(EmptyStatesPattern.self),
        LabPatternEntry(LoadingPattern.self),
        LabPatternEntry(TogglesPattern.self),
        LabPatternEntry(BadgePattern.self)
    ]

    public private(set) static var custom: [LabPatternEntry] = []

    /// Apps call this for views of their own that adopt `InspectablePattern`, so
    /// they show up in the dev tools next to the `Lab*` components.
    public static func register<P: InspectablePattern>(_ type: P.Type) {
        guard !custom.contains(where: { $0.id == P.name }) else { return }
        custom.append(LabPatternEntry(type))
    }

    public static var all: [LabPatternEntry] { builtIn + custom }
}
