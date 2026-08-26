import SwiftUI

public enum ElevationLevel: String, CaseIterable, Identifiable, Sendable, Codable, Hashable {
    case flat
    case subtle
    case elevated

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .flat: "Flat"
        case .subtle: "Subtle"
        case .elevated: "Elevated"
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .flat: 0
        case .subtle: 0.08
        case .elevated: 0.20
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .flat: 0
        case .subtle: 8
        case .elevated: 18
        }
    }

    var shadowY: CGFloat {
        switch self {
        case .flat: 0
        case .subtle: 2
        case .elevated: 8
        }
    }
}

public extension View {
    func labShadow(_ elevation: ElevationLevel) -> some View {
        shadow(color: .black.opacity(elevation.shadowOpacity), radius: elevation.shadowRadius, y: elevation.shadowY)
    }
}
