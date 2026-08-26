import SwiftUI

public enum OnboardingPattern: InspectablePattern {
    public static let name = "Onboarding"
    public static let symbolName = "hand.wave"

    public static let defaultConfig = PatternConfig(
        spacing: 16,
        cornerRadius: 22,
        accentColor: ColorTokens.accent,
        duration: 0.3
    )

    public static let inspectableProperties: [InspectableProperty] = [
        .spacing(label: "Content Spacing", keyPath: \.spacing, range: 4...32),
        .cornerRadius(label: "Button Corner Radius", keyPath: \.cornerRadius, range: 8...28),
        .color(label: "Accent Color", keyPath: \.accentColor)
    ]

    public static func preview(config: PatternConfig) -> some View {
        LabOnboardingStep(
            icon: "sparkles",
            title: "Welcome",
            message: "This is the first step of your onboarding flow.",
            config: config
        )
    }
}

#Preview {
    OnboardingPattern.preview(config: OnboardingPattern.defaultConfig)
        .padding()
}
