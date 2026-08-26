import SwiftUI

public enum WindowTitleBarStyle: String, CaseIterable, Identifiable, Sendable, Codable, Hashable {
    case full
    case compact
    case none

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .full: "Full"
        case .compact: "Compact"
        case .none: "None"
        }
    }

    public var symbolName: String {
        switch self {
        case .full: "circle.grid.3x1.fill"
        case .compact: "rectangle.topthird.inset.filled"
        case .none: "rectangle"
        }
    }
}
