import SwiftUI

// Coordinator (2026-09-17): DEBUG-only dev screen comparing card corner radii and
// padding/density side by side — same convention as `DeveloperVibrationsView` (whole file
// compiled out of Release/TestFlight/App Store, not just hidden at runtime). iOS-only.
#if os(iOS) && DEBUG
/// Radii researched from Apple's own docs/WWDC 2025 session 323/developer forums: standard
/// sheets sit at 10pt, the official iOS 26 widget container examples use 24pt and 60pt, and
/// the typical component range is 8–20pt. `12pt` and `20pt` are called out separately below
/// because they're the app's OWN current values (`LineItemRow`/card-per-line = 12pt internal
/// elements per Larry's squircle audit; `SobranteBadge`/`LineItemRow`'s own card = 20pt) —
/// this screen exists to compare them against the research, not to change either.
struct DeveloperCardsView: View {
    private struct RadiusSample: Identifiable {
        let id = UUID()
        let radius: CGFloat
        let label: String
    }

    private let radiusSamples: [RadiusSample] = [
        RadiusSample(radius: 8, label: "Chico (chips/botones)"),
        RadiusSample(radius: 10, label: "Sheet estándar de Apple"),
        RadiusSample(radius: 12, label: "Actual de la app"),
        RadiusSample(radius: 16, label: "—"),
        RadiusSample(radius: 20, label: "Card grande (actual en tarjetas principales)"),
        RadiusSample(radius: 24, label: "Contenedor de widget iOS 26 (oficial)"),
        RadiusSample(radius: 28, label: "—"),
    ]

    private struct DensitySample: Identifiable {
        let id = UUID()
        let padding: CGFloat
        let label: String
    }

    private let densitySamples: [DensitySample] = [
        DensitySample(padding: 12, label: "Compacto"),
        DensitySample(padding: 16, label: "Regular (actual)"),
        DensitySample(padding: 24, label: "Grande"),
    ]

    var body: some View {
        List {
            Section("Radio") {
                ForEach(radiusSamples) { sample in
                    VStack(alignment: .leading, spacing: 6) {
                        sampleCard(cornerRadius: sample.radius, padding: 16)
                        Text("\(Int(sample.radius))pt" + (sample.label == "—" ? "" : " — \(sample.label)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 4)
                }
            }

            Section("Tamaño/densidad") {
                ForEach(densitySamples) { sample in
                    VStack(alignment: .leading, spacing: 6) {
                        sampleCard(cornerRadius: 20, padding: sample.padding)
                        Text("Padding \(Int(sample.padding))pt — \(sample.label)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Cards")
    }

    /// Same content/layout as a real `LineItemRow` — "Latest Month" / "$2,828.80", description
    /// left, amount right, `AppBackgroundSecondary` — so the comparison is apples-to-apples,
    /// not an abstract shape.
    private func sampleCard(cornerRadius: CGFloat, padding: CGFloat) -> some View {
        HStack {
            Text("Latest Month")
                .font(.body)
            Spacer()
            Text("$2,828.80")
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
        .padding(padding)
        .background(Color("AppBackgroundSecondary"))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        DeveloperCardsView()
    }
}
#endif
