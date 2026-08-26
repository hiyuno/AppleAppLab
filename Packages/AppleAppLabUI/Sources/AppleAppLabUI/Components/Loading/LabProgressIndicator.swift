import SwiftUI

public struct LabProgressIndicator: View {
    let config: PatternConfig

    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(config: PatternConfig) {
        self.config = config
    }

    public var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(config.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .frame(width: 32, height: 32)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(
                reduceMotion ? .none : .linear(duration: config.duration).repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
            .accessibilityLabel("Loading")
    }
}

#Preview {
    LabProgressIndicator(config: PatternConfig())
        .padding()
}
