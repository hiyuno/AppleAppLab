import SwiftUI

enum IconRenderingMode: String, CaseIterable, Identifiable, Codable {
    case monochrome
    case hierarchical
    case multicolor

    var id: String { rawValue }

    var label: String {
        switch self {
        case .monochrome: "Monochrome"
        case .hierarchical: "Hierarchical"
        case .multicolor: "Multicolor"
        }
    }

    var mode: SymbolRenderingMode {
        switch self {
        case .monochrome: .monochrome
        case .hierarchical: .hierarchical
        case .multicolor: .multicolor
        }
    }
}
