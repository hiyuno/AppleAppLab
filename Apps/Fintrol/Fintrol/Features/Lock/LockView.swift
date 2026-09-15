import SwiftUI
import LocalAuthentication

/// Security surface, not navigation/content — flat `AppBackground`, no Frost, no Liquid
/// Glass (DESIGN_LIQUID.md). No financial view is ever mounted behind this screen: the
/// caller only shows real content once `BiometricLockStore.isAuthenticated` is true.
struct LockView: View {
    let store: BiometricLockStore

    // A11Y #5: initial focus for Voice Control / Switch Control on macOS.
    @FocusState private var unlockButtonFocused: Bool

    private var biometryIcon: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch context.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.shield"
        }
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            VStack(spacing: 20) {
                // A11Y #20: decorative — the texts below already communicate the same thing.
                Image(systemName: biometryIcon)
                    .font(.system(size: 80))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text("Fintrol está bloqueado")
                    .font(.title2.weight(.semibold))

                Text("Autentica para ver tus montos")
                    .font(.body)
                    .foregroundStyle(.secondary)

                if store.lastAuthenticationFailed {
                    Text("No se pudo verificar tu identidad")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Error: No se pudo verificar tu identidad")
                }

                // DESIGN_LIQUID.md specifies Liquid Glass here explicitly (security surface CTA),
                // so this stays a native `.glassProminent` button rather than `LabButton`
                // (which fills solid, not glass) — see PROJECT_LEARNINGS.md FIN-2026-003.
                Button {
                    Task { await store.authenticate() }
                } label: {
                    Text(store.lastAuthenticationFailed ? "Reintentar" : "Desbloquear")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .padding(.horizontal, 40)
                .padding(.top, 8)
                .focused($unlockButtonFocused)
            }
            .padding()
        }
        .task {
            unlockButtonFocused = true
            await store.authenticate()
        }
    }
}

#Preview {
    LockView(store: BiometricLockStore())
}
