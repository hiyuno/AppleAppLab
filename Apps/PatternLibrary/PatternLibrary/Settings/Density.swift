import Foundation

enum Density: String, CaseIterable, Identifiable, Codable {
    case compact
    case regular
    case comfortable

    var id: String { rawValue }

    var label: String {
        switch self {
        case .compact: "Compact"
        case .regular: "Regular"
        case .comfortable: "Comfortable"
        }
    }

    var scale: CGFloat {
        switch self {
        case .compact: 0.75
        case .regular: 1.0
        case .comfortable: 1.3
        }
    }
}
