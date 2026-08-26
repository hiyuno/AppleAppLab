import SwiftUI

public enum NavigationPattern: InspectablePattern {
    public static let name = "Navegación (tabs/sidebar)"
    public static let symbolName = "sidebar.left"

    public static let defaultConfig = PatternConfig(
        spacing: 12,
        cornerRadius: 16,
        accentColor: ColorTokens.accent,
        duration: 0.3
    )

    public static let inspectableProperties: [InspectableProperty] = [
        .spacing(label: "Item Spacing", keyPath: \.spacing, range: 0...32),
        .cornerRadius(label: "Corner Radius", keyPath: \.cornerRadius, range: 0...24),
        .color(label: "Accent Color", keyPath: \.accentColor),
        .duration(label: "Selection Response", keyPath: \.duration, range: 0.1...0.6)
    ]

    public static func preview(config: PatternConfig) -> some View {
        NavigationPreview(config: config)
    }
}

private struct NavigationPreview: View {
    let config: PatternConfig
    @State private var selection = 0

    var body: some View {
        LabTabBar(
            items: [
                LabTabItem(title: "Home", symbolName: "house"),
                LabTabItem(title: "Search", symbolName: "magnifyingglass"),
                LabTabItem(title: "Profile", symbolName: "person")
            ],
            selection: $selection,
            config: config
        )
        .frame(maxWidth: 320)
    }
}

#Preview {
    NavigationPattern.preview(config: NavigationPattern.defaultConfig)
        .padding()
}
