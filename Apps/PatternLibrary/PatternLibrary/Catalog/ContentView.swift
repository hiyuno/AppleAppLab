import SwiftUI

struct ContentView: View {
    @State private var catalog = CatalogViewModel()

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                ThemeSwitcherBar()
                Divider()
                sidebarList
            }
            .navigationTitle("Pattern Library")
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
        } detail: {
            detailView
        }
    }

    private var sidebarList: some View {
        List(selection: $catalog.selection) {
            Section("General") {
                ForEach(SettingsCategory.allCases) { category in
                    Label(category.label, systemImage: category.symbolName)
                        .tag(SidebarSelection.settings(category))
                }
            }
            Section("Patterns") {
                ForEach(PatternCatalog.all) { entry in
                    Label(entry.name, systemImage: entry.symbolName)
                        .tag(SidebarSelection.pattern(entry.id))
                }
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch catalog.selection {
        case .settings(let category):
            SettingsView(category: category)
        case .pattern(let id):
            if let entry = PatternCatalog.all.first(where: { $0.id == id }) {
                PatternDetailView(entry: entry)
                    .id(entry.id)
            } else {
                ContentUnavailableView("Pattern no encontrado", systemImage: "exclamationmark.triangle")
            }
        case nil:
            ContentUnavailableView("Selecciona un pattern", systemImage: "square.grid.2x2")
        }
    }
}

#Preview {
    ContentView()
        .environment(AppSettings())
        .environment(ThemeStore())
}
