import SwiftUI
#if os(iOS)
import UIKit
#endif

// Coordinator (2026-09-17): DEBUG-only dev screen to feel every iOS haptic feedback type on
// a real device — grouped by generator (Impact / Notification / Selection), same convention
// as the store-delete path in `FintrolApp.swift`: the ENTIRE file is compiled out of
// Release/TestFlight/App Store builds, not just hidden behind a runtime check. iOS-only —
// there's no haptics API on macOS, so this type doesn't exist there at all.
#if os(iOS) && DEBUG
/// Deliberately does NOT respect `accessibilityReduceMotion` — unlike every other haptic call
/// site in the app (`HapticFeedback.lightImpact`), this screen exists specifically so a
/// developer can feel each vibration on demand, regardless of that setting.
struct DeveloperVibrationsView: View {
    var body: some View {
        List {
            Section("Impact") {
                impactRow("Light", style: .light)
                impactRow("Medium", style: .medium)
                impactRow("Heavy", style: .heavy)
                impactRow("Soft", style: .soft)
                impactRow("Rigid", style: .rigid)
            }

            Section("Notification") {
                notificationRow("Success", type: .success)
                notificationRow("Warning", type: .warning)
                notificationRow("Error", type: .error)
            }

            Section("Selection") {
                HStack {
                    Text("Selection Changed")
                    Spacer()
                    Button("Probar") {
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .navigationTitle("Vibrations")
    }

    private func impactRow(_ title: String, style: UIImpactFeedbackGenerator.FeedbackStyle) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button("Probar") {
                UIImpactFeedbackGenerator(style: style).impactOccurred()
            }
            .buttonStyle(.bordered)
        }
    }

    private func notificationRow(_ title: String, type: UINotificationFeedbackGenerator.FeedbackType) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button("Probar") {
                UINotificationFeedbackGenerator().notificationOccurred(type)
            }
            .buttonStyle(.bordered)
        }
    }
}

#Preview {
    NavigationStack {
        DeveloperVibrationsView()
    }
}
#endif
