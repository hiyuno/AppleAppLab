import Foundation

enum SettingsCategory: String, CaseIterable, Identifiable {
    case themes
    case color
    case typography
    case shape
    case elevation
    case iconography
    case motion
    case density
    case window

    var id: String { rawValue }

    var label: String {
        switch self {
        case .themes: "Themes"
        case .color: "Color"
        case .typography: "Typography"
        case .shape: "Shape"
        case .elevation: "Elevation"
        case .iconography: "Iconography"
        case .motion: "Motion"
        case .density: "Density"
        case .window: "Window"
        }
    }

    var symbolName: String {
        switch self {
        case .themes: "paintpalette.fill"
        case .color: "eyedropper.halffull"
        case .typography: "textformat"
        case .shape: "square.on.circle"
        case .elevation: "square.stack.3d.up.fill"
        case .iconography: "app.badge"
        case .motion: "wind"
        case .density: "rectangle.compress.vertical"
        case .window: "macwindow"
        }
    }
}
