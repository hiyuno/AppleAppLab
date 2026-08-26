import SwiftUI

public enum InspectableProperty: Identifiable {
    case spacing(label: String, keyPath: WritableKeyPath<PatternConfig, CGFloat>, range: ClosedRange<CGFloat>)
    case cornerRadius(label: String, keyPath: WritableKeyPath<PatternConfig, CGFloat>, range: ClosedRange<CGFloat>)
    case color(label: String, keyPath: WritableKeyPath<PatternConfig, Color>)
    case duration(label: String, keyPath: WritableKeyPath<PatternConfig, Double>, range: ClosedRange<Double>)
    case picker(label: String, keyPath: WritableKeyPath<PatternConfig, String>, options: [String])
    /// A non-interactive header used to group the properties that follow it —
    /// e.g. "Card 1" before that card's own Background/Outline color controls.
    case section(String)

    public var label: String {
        switch self {
        case .spacing(let label, _, _): label
        case .cornerRadius(let label, _, _): label
        case .color(let label, _): label
        case .duration(let label, _, _): label
        case .picker(let label, _, _): label
        case .section(let label): label
        }
    }

    // Several `.color` controls can legitimately share the same display label
    // (e.g. "Background Color" once per card section) but each targets a
    // different keyPath, so `id` folds that in to stay unique for ForEach.
    public var id: String {
        switch self {
        case .spacing(let label, let keyPath, _): "spacing-\(label)-\(keyPath.hashValue)"
        case .cornerRadius(let label, let keyPath, _): "cornerRadius-\(label)-\(keyPath.hashValue)"
        case .color(let label, let keyPath): "color-\(label)-\(keyPath.hashValue)"
        case .duration(let label, let keyPath, _): "duration-\(label)-\(keyPath.hashValue)"
        case .picker(let label, let keyPath, _): "picker-\(label)-\(keyPath.hashValue)"
        case .section(let label): "section-\(label)"
        }
    }
}
