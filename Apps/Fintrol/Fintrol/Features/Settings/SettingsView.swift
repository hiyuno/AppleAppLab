import SwiftUI
import SwiftData
import CloudKit
import AppleAppLabUI

/// "Ajustes generales" — Form nativo con dos Section (DESIGN_LIQUID.md). En iOS es un tab;
/// en macOS vive en la `Settings` scene nativa (⌘,), ver `FintrolApp.swift`.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore
    @Environment(BiometricLockStore.self) private var lockStore

    @State private var lockErrorMessage: String?
    @State private var iCloudStatusText = "Sincronizando…"
    @State private var iCloudStatusIcon = "icloud"

    var body: some View {
        Form {
            Section("Preferencias") {
                HStack {
                    Text("Moneda base")
                    Spacer()
                    Text("USD")
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    ExchangeRateSettingsView()
                } label: {
                    HStack {
                        Text("Tipo de cambio")
                        Spacer()
                        Text(exchangeRateSummary)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Picker("Apariencia", selection: Binding(
                    get: { AppAppearance(rawValue: appearanceRaw) ?? .system },
                    set: { appearanceRaw = $0.rawValue }
                )) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)

                HStack {
                    Image(systemName: iCloudStatusIcon)
                        .foregroundStyle(.secondary)
                    Text(iCloudStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .task { await refreshCloudKitStatus() }
            }

            Section("Seguridad") {
                LabToggleRow(title: "Bloquear con Face ID / Touch ID", isOn: Binding(
                    get: { lockStore.isLockEnabled },
                    set: { newValue in
                        if newValue {
                            Task {
                                let success = await lockStore.attemptEnableLock()
                                lockErrorMessage = success ? nil : "No se pudo activar: verifica que tu dispositivo tenga Face ID, Touch ID o código configurado."
                            }
                        } else {
                            lockStore.isLockEnabled = false
                            lockErrorMessage = nil
                        }
                    }
                ), config: PatternConfig(accentColor: .accentColor))
                if let lockErrorMessage {
                    Text(lockErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Picker("Tiempo de re-bloqueo", selection: Binding(
                    get: { lockStore.reauthenticationInterval },
                    set: { lockStore.reauthenticationInterval = $0 }
                )) {
                    ForEach(BiometricLockStore.ReauthenticationInterval.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
                .disabled(!lockStore.isLockEnabled)
                .opacity(lockStore.isLockEnabled ? 1 : 0.4)

                Text("Ocultar montos en el app switcher siempre está activo, independiente de Face ID / Touch ID.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Spacer()
                    Text(versionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .navigationTitle("Ajustes")
    }

    @AppStorage("fintrol.appearance") private var appearanceRaw: String = AppAppearance.system.rawValue

    private var exchangeRateSummary: String {
        guard let rate = rateStore.currentRate else { return "—" }
        if let rateDate = rateStore.rateDate {
            let elapsed = elapsedDescription(since: rateDate)
            return "\(rate.twoDecimalString) · \(elapsed)"
        }
        return rate.twoDecimalString
    }

    private func elapsedDescription(since date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 3600 { return "hace \(max(1, Int(seconds / 60))) min" }
        if seconds < 86400 { return "hace \(Int(seconds / 3600)) h" }
        return "hace \(Int(seconds / 86400)) d"
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Fintrol — versión \(version) (build \(build))"
    }

    private func refreshCloudKitStatus() async {
        do {
            let status = try await CKContainer.default().accountStatus()
            switch status {
            case .available:
                iCloudStatusText = "Sincronizado"
                iCloudStatusIcon = "icloud"
            case .noAccount, .restricted, .temporarilyUnavailable:
                iCloudStatusText = "Sin conexión"
                iCloudStatusIcon = "icloud.slash"
            case .couldNotDetermine:
                iCloudStatusText = "Sincronizando…"
                iCloudStatusIcon = "icloud"
            @unknown default:
                iCloudStatusText = "Sincronizando…"
                iCloudStatusIcon = "icloud"
            }
        } catch {
            iCloudStatusText = "Sin conexión"
            iCloudStatusIcon = "icloud.slash"
        }
    }
}

/// Persisted via `@AppStorage` — a UI preference, not a secret or auth state (SECURITY.md C-11).
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Sistema"
        case .light: "Claro"
        case .dark: "Oscuro"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private struct ExchangeRateSettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore

    @AppStorage("fintrol.automaticExchangeRate") private var isAutomatic = true
    @State private var manualRateText = ""
    @State private var rateErrorMessage: String?

    @State private var tokenText = ""
    @State private var revealToken = false
    @State private var tokenTestMessage: String?
    @State private var tokenTestIsError = false
    @State private var isTestingToken = false

    var body: some View {
        Form {
            // C-12(e): SecureField by default, an explicit toggle reveals plaintext (the user
            // controls exposure, the app never shows it by default), plus "Probar token" —
            // verifies against Banxico without ever saving or echoing the token back.
            Section {
                HStack {
                    Group {
                        if revealToken {
                            TextField("Bmx-Token", text: $tokenText)
                        } else {
                            SecureField("Bmx-Token", text: $tokenText)
                        }
                    }
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()

                    Button {
                        revealToken.toggle()
                    } label: {
                        Image(systemName: revealToken ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(revealToken ? "Ocultar token" : "Mostrar token")
                }

                HStack {
                    Button("Probar token") { Task { await testToken() } }
                        .disabled(tokenText.isEmpty || isTestingToken)
                    if isTestingToken {
                        ProgressView().controlSize(.small)
                    }
                }
                if let tokenTestMessage {
                    Text(tokenTestMessage)
                        .font(.caption)
                        .foregroundStyle(tokenTestIsError ? .red : .green)
                }

                Button("Guardar token") {
                    rateStore.saveToken(tokenText)
                    tokenTestMessage = nil
                }
                .disabled(tokenText.isEmpty)

                if rateStore.isTokenInvalid {
                    Text("Tu token de Banxico no es válido o expiró — revísalo arriba.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Token de Banxico SIE")
            } footer: {
                Text("Obtén tu token gratis en el sitio de Banxico. Se guarda solo en este dispositivo, nunca en iCloud.")
            }

            Section {
                Toggle("Automático", isOn: $isAutomatic)
                if !isAutomatic {
                    LabTextField(placeholder: "Tipo de cambio (1–100)", text: $manualRateText, config: PatternConfig(accentColor: .accentColor))
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    if let rateErrorMessage {
                        Text(rateErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Button("Guardar") { applyManualOverride() }
                }
            } footer: {
                if isAutomatic {
                    Text("Se consulta automáticamente al abrir la app (máximo una vez al día).")
                } else {
                    Text("Rango válido: 1–100 (USD → MXN).")
                }
            }
        }
        .navigationTitle("Tipo de cambio")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if let rate = rateStore.currentRate {
                manualRateText = rate.twoDecimalString
            }
            tokenText = KeychainStore.read() ?? ""
        }
        .onChange(of: isAutomatic) { _, newValue in
            if newValue {
                Task { await rateStore.refresh(context: context) }
            }
        }
    }

    private func applyManualOverride() {
        guard let value = Decimal(string: manualRateText, locale: Locale(identifier: "en_US_POSIX")) else {
            rateErrorMessage = "Escribe un número válido."
            return
        }
        if rateStore.applyManualOverride(value, context: context) {
            rateErrorMessage = nil
        } else {
            rateErrorMessage = "El tipo de cambio debe estar entre \(ExchangeRateParser.plausibleRange.lowerBound) y \(ExchangeRateParser.plausibleRange.upperBound)."
        }
    }

    private func testToken() async {
        isTestingToken = true
        defer { isTestingToken = false }
        switch await rateStore.testToken(tokenText) {
        case .valid:
            tokenTestMessage = "Token válido."
            tokenTestIsError = false
        case .invalid:
            tokenTestMessage = "Token inválido — verifica que lo copiaste completo."
            tokenTestIsError = true
        case .networkError:
            tokenTestMessage = "No se pudo verificar — revisa tu conexión e intenta de nuevo."
            tokenTestIsError = true
        }
    }
}
