import Testing
@testable import AppleAppLabUI

@Suite("PatternConfig")
struct PatternConfigTests {
    @Test("Mutating a config through a WritableKeyPath updates only that property")
    func keyPathMutation() {
        var config = PatternConfig(spacing: 12, cornerRadius: 22, duration: 0.3)
        let spacingKeyPath: WritableKeyPath<PatternConfig, CGFloat> = \.spacing

        config[keyPath: spacingKeyPath] = 20

        #expect(config.spacing == 20)
        #expect(config.cornerRadius == 22)
        #expect(config.duration == 0.3)
    }

    @Test("ButtonsPattern exposes the inspectable properties Woz wired for it")
    @MainActor
    func buttonsPatternProperties() {
        let labels = ButtonsPattern.inspectableProperties.map(\.label)
        #expect(labels == ["Spacing", "Corner Radius", "Accent Color", "Press Response"])
    }
}
