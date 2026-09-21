import SwiftUI

#if DEBUG
extension View {
    /// Draws a colored border + small label in the corner when debug outlines are enabled
    /// (`HomeDragDebugState.outlinesEnabled`, toggled from the `GestureDebugHUD` in
    /// `RootView.swift`) — a no-op otherwise. Added 2026-09-19 alongside the HUD's `easingDisabled`
    /// toggle so the user can visually inspect each layer/container's actual on-screen bounds
    /// while debugging a padding-interpolation timing mismatch between `HomeView`'s floating
    /// title overlay and `PeriodView`'s content during the Home→Quincena drag transition, instead
    /// of guessing from screenshots. Debug-only tool — styling doesn't need to be pixel-perfect,
    /// just legible and non-intrusive enough not to totally obscure the content underneath.
    @ViewBuilder
    func debugOutline(_ name: String, color: Color, enabled: Bool, padding: String? = nil) -> some View {
        if enabled {
            self
                .border(color, width: 2)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name)
                        if let padding {
                            Text(padding)
                        }
                    }
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color.black.opacity(0.75))
                }
        } else {
            self
        }
    }
}
#endif
