import SwiftUI

public struct LabOnboardingStep: View {
    let icon: String
    let title: String
    let message: String
    let config: PatternConfig

    public init(icon: String, title: String, message: String, config: PatternConfig) {
        self.icon = icon
        self.title = title
        self.message = message
        self.config = config
    }

    public var body: some View {
        VStack(spacing: config.spacing) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(config.accentColor)
                .accessibilityHidden(true)

            Text(title)
                .font(.title2.bold())

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            LabButton(title: "Continue", style: .primary, config: config) {}
                .frame(maxWidth: 200)
        }
        .frame(maxWidth: 320)
    }
}

#Preview {
    LabOnboardingStep(
        icon: "sparkles",
        title: "Welcome",
        message: "This is the first step of your onboarding flow.",
        config: PatternConfig()
    )
    .padding()
}
