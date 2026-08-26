import SwiftUI

public struct LabEmptyState: View {
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
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    LabEmptyState(icon: "tray", title: "No Items", message: "Nothing here yet.", config: PatternConfig())
        .padding()
}
