import Observation

enum SidebarSelection: Hashable {
    case settings(SettingsCategory)
    case pattern(String)
}

@MainActor
@Observable
final class CatalogViewModel {
    var selection: SidebarSelection? = .settings(.themes)
}
