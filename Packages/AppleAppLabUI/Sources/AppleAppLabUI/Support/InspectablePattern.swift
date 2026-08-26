import SwiftUI

@MainActor
public protocol InspectablePattern {
    associatedtype PreviewContent: View

    static var name: String { get }
    static var symbolName: String { get }
    static var defaultConfig: PatternConfig { get }
    static var inspectableProperties: [InspectableProperty] { get }

    @ViewBuilder static func preview(config: PatternConfig) -> PreviewContent
}
