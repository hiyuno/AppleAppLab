import SwiftUI

public enum WindowMaterial: String, CaseIterable, Identifiable, Sendable, Codable, Hashable {
    case solid
    case frost
    case liquidGlass

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .solid: "Solid"
        case .frost: "Frost"
        case .liquidGlass: "Liquid Glass"
        }
    }

    public var symbolName: String {
        switch self {
        case .solid: "square.fill"
        case .frost: "cloud.fill"
        case .liquidGlass: "drop.fill"
        }
    }
}
