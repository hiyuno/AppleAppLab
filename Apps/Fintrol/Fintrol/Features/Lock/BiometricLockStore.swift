import Foundation
import LocalAuthentication
import Observation
import SwiftUI

/// Optional Face ID / Touch ID / device-passcode lock (PRD feature #10, SECURITY.md C-11).
///
/// - `.deviceOwnerAuthentication` only, never `.deviceOwnerAuthenticationWithBiometrics` alone,
///   so a device without Face ID/Touch ID configured still falls back to the passcode.
/// - `isAuthenticated` lives only in process memory: never `UserDefaults`, never Keychain
///   (there is no Keychain entitlement in this project — see SECURITY.md §6.1). It resets to
///   `false` on every cold start and whenever the app has spent ≥60s in background/inactive.
/// - Only the on/off *preference* (`isLockEnabled`) persists, via `UserDefaults` — that is not
///   the authentication result, just "did the user turn the switch on".
@MainActor
@Observable
public final class BiometricLockStore {
    /// "Tiempo de re-bloqueo" (DESIGN_LIQUID.md › Ajustes generales › Seguridad) — default
    /// "1 minuto" per the PRD (already confirmed, not a placeholder). `.immediate` relocks on
    /// *any* backgrounding: its threshold of 0s means `elapsed >= threshold` is always true.
    public enum ReauthenticationInterval: Int, CaseIterable, Identifiable, Sendable {
        case immediate = 0
        case oneMinute = 60
        case fiveMinutes = 300

        public var id: Int { rawValue }

        public var title: String {
            switch self {
            case .immediate: "Inmediato"
            case .oneMinute: "1 minuto"
            case .fiveMinutes: "5 minutos"
            }
        }

        var threshold: TimeInterval { TimeInterval(rawValue) }
    }

    private static let enabledPreferenceKey = "fintrol.biometricLockEnabled"
    private static let intervalPreferenceKey = "fintrol.biometricLockInterval"

    public var isLockEnabled: Bool {
        didSet { UserDefaults.standard.set(isLockEnabled, forKey: Self.enabledPreferenceKey) }
    }

    public var reauthenticationInterval: ReauthenticationInterval {
        didSet { UserDefaults.standard.set(reauthenticationInterval.rawValue, forKey: Self.intervalPreferenceKey) }
    }

    public private(set) var isAuthenticated = false
    public private(set) var lastAuthenticationFailed = false

    private var backgroundedAt: Date?

    public init() {
        isLockEnabled = UserDefaults.standard.bool(forKey: Self.enabledPreferenceKey)
        if let stored = UserDefaults.standard.object(forKey: Self.intervalPreferenceKey) as? Int,
           let interval = ReauthenticationInterval(rawValue: stored) {
            reauthenticationInterval = interval
        } else {
            reauthenticationInterval = .oneMinute
        }
    }

    public var shouldPresentLockScreen: Bool {
        isLockEnabled && !isAuthenticated
    }

    public func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if let backgroundedAt, Date().timeIntervalSince(backgroundedAt) >= reauthenticationInterval.threshold {
                isAuthenticated = false
            }
            backgroundedAt = nil
        case .background, .inactive:
            if backgroundedAt == nil { backgroundedAt = Date() }
        @unknown default:
            break
        }
    }

    /// Resets the in-memory authentication flag immediately — used on cold start when
    /// the lock is enabled, so no data renders before the first successful prompt.
    public func resetForColdStart() {
        isAuthenticated = false
        backgroundedAt = nil
    }

    @discardableResult
    public func authenticate() async -> Bool {
        let context = LAContext()
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            isAuthenticated = false
            lastAuthenticationFailed = true
            return false
        }

        let success = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Autentica para ver tu presupuesto") { success, _ in
                continuation.resume(returning: success)
            }
        }

        isAuthenticated = success
        lastAuthenticationFailed = !success
        return success
    }

    /// Fires a real authentication test when the user flips the switch on in Ajustes.
    /// The switch snaps back off if it fails, or there is no biometry/passcode configured —
    /// it never stays "on" without a working authentication behind it.
    @discardableResult
    public func attemptEnableLock() async -> Bool {
        let success = await authenticate()
        isLockEnabled = success
        return success
    }
}
