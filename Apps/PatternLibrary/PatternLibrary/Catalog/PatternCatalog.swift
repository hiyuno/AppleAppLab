import AppleAppLabUI

@MainActor
enum PatternCatalog {
    static let all: [PatternEntry] = [
        PatternEntry(ButtonsPattern.self),
        PatternEntry(CheckboxRadioPattern.self),
        PatternEntry(NavigationPattern.self),
        PatternEntry(ListsPattern.self),
        PatternEntry(TodoListPattern.self),
        PatternEntry(CardsPattern.self),
        PatternEntry(FormsPattern.self),
        PatternEntry(SheetsPattern.self),
        PatternEntry(OnboardingPattern.self),
        PatternEntry(EmptyStatesPattern.self),
        PatternEntry(LoadingPattern.self),
        PatternEntry(TogglesPattern.self),
        PatternEntry(BadgePattern.self)
    ]
}
