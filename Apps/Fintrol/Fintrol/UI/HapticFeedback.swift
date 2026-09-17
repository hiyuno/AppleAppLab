import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Shared haptic helper — extracted from `LineItemRow.hapticImpact()` (2026-09-17) so the tab
/// bar's tab-switch feedback doesn't duplicate the same `UIImpactFeedbackGenerator` +
/// `accessibilityReduceMotion` guard. iOS only: no tactile feedback API on macOS.
enum HapticFeedback {
    /// A light impact, skipped entirely when Reduce Motion is on (matches every other
    /// motion/haptic gate in the app — see `LineItemRow`'s swipe, `SobranteBadge`'s color
    /// transition, etc.).
    static func lightImpact(reduceMotion: Bool) {
        #if os(iOS)
        guard !reduceMotion else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
