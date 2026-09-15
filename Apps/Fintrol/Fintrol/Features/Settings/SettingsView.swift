import SwiftUI
import SwiftData
import CloudKit
import UniformTypeIdentifiers
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

    @State private var isPresentingSubscriptionImporter = false
    @State private var subscriptionImportResultMessage: String?
    @State private var isShowingSubscriptionImportResult = false

    @State private var isPresentingBackupExporter = false
    @State private var backupExportDocument: BackupJSONDocument?
    @State private var isPresentingBackupImporter = false
    @State private var isPresentingBackupImportConfirm = false
    @State private var pendingBackupImportURL: URL?
    @State private var backupResultMessage: String?
    @State private var isShowingBackupResult = false

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

                Button {
                    isPresentingSubscriptionImporter = true
                } label: {
                    Text("Importar suscripciones y servicios…")
                }

                Button {
                    let backup = BackupService.exportBackup(context: context)
                    backupExportDocument = BackupJSONDocument(backup: backup)
                    isPresentingBackupExporter = true
                } label: {
                    Text("Exportar respaldo completo (JSON)")
                }

                Button {
                    isPresentingBackupImporter = true
                } label: {
                    Text("Importar respaldo completo…")
                }
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
                // A11Y #31 (Sarah, medio): `.disabled` already stops interaction, but the
                // dimmed opacity alone doesn't explain WHY to someone who can't see it dimmed.
                .accessibilityHint(lockStore.isLockEnabled ? "" : "Disponible cuando Face ID/Touch ID esté habilitado")

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
        .fileImporter(isPresented: $isPresentingSubscriptionImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                importSubscriptions(from: url)
            case .failure:
                subscriptionImportResultMessage = "No se pudo abrir el archivo seleccionado."
                isShowingSubscriptionImportResult = true
            }
        }
        .alert("Importación", isPresented: $isShowingSubscriptionImportResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(subscriptionImportResultMessage ?? "")
        }
        .fileExporter(
            isPresented: $isPresentingBackupExporter,
            document: backupExportDocument,
            contentType: .json,
            defaultFilename: "fintrol-respaldo-\(backupFilenameStamp())"
        ) { result in
            switch result {
            case .success:
                backupResultMessage = "Respaldo exportado correctamente."
            case .failure:
                backupResultMessage = "No se pudo guardar el respaldo."
            }
            isShowingBackupResult = true
        }
        .fileImporter(isPresented: $isPresentingBackupImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                pendingBackupImportURL = url
                isPresentingBackupImportConfirm = true
            case .failure:
                backupResultMessage = "No se pudo abrir el archivo seleccionado."
                isShowingBackupResult = true
            }
        }
        .confirmationDialog(
            "Esto reemplaza TODOS los datos actuales con los del respaldo. ¿Continuar?",
            isPresented: $isPresentingBackupImportConfirm,
            titleVisibility: .visible
        ) {
            Button("Reemplazar todo", role: .destructive) {
                if let url = pendingBackupImportURL { importFullBackup(from: url) }
            }
            Button("Cancelar", role: .cancel) { pendingBackupImportURL = nil }
        }
        .alert("Respaldo", isPresented: $isShowingBackupResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(backupResultMessage ?? "")
        }
    }

    /// Ajustes → Preferencias → "Importar respaldo completo…". Destructive — the
    /// `confirmationDialog` above must run first. Dedupe by id, full replace
    /// (`BackupService.importBackup`).
    private func importFullBackup(from url: URL) {
        let needsSecurityScope = url.startAccessingSecurityScopedResource()
        defer { if needsSecurityScope { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url), let backup = BackupService.decode(data) else {
            backupResultMessage = "El archivo no es un respaldo válido de Fintrol."
            isShowingBackupResult = true
            return
        }
        let summary = BackupService.importBackup(backup, context: context)
        backupResultMessage = "Restaurado: \(summary.periods) quincenas, \(summary.lineItems) líneas, \(summary.recurringItems) recurrentes, \(summary.subscriptions) suscripciones/servicios, \(summary.loans) préstamos."
        isShowingBackupResult = true
    }

    private func backupFilenameStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// Ajustes → Preferencias → "Importar suscripciones y servicios…". Reads the
    /// user-selected JSON file, parses it defensively (`SubscriptionImportService` — a
    /// malformed item is skipped, not fatal), persists the valid items
    /// (`PeriodCoordinator.importSubscriptions`, deduped by name), and reports one summary
    /// alert. Never logs amounts or file contents (SECURITY.md C-05).
    private func importSubscriptions(from url: URL) {
        let needsSecurityScope = url.startAccessingSecurityScopedResource()
        defer { if needsSecurityScope { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            subscriptionImportResultMessage = "No se pudo leer el archivo seleccionado."
            isShowingSubscriptionImportResult = true
            return
        }

        let parsed = SubscriptionImportService.parse(data: data)
        let summary = PeriodCoordinator.importSubscriptions(
            parsed.valid, context: context, exchangeRate: rateStore.currentRate ?? 0, skippedCount: parsed.issues.count
        )
        subscriptionImportResultMessage = "\(summary.imported) importados, \(summary.updated) actualizados, \(summary.skipped) omitidos."
        isShowingSubscriptionImportResult = true
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
                    // A11Y #30 (Sarah): the red/green color alone doesn't tell VoiceOver
                    // whether this is success or failure — say it explicitly.
                    Text(tokenTestMessage)
                        .font(.caption)
                        .foregroundStyle(tokenTestIsError ? .red : .green)
                        .accessibilityLabel((tokenTestIsError ? "Error: " : "Éxito: ") + tokenTestMessage)
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

/// `FileDocument` wrapper so `BackupService.Backup` can go through `.fileExporter`.
struct BackupJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let backup: BackupService.Backup

    init(backup: BackupService.Backup) {
        self.backup = backup
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents, let decoded = BackupService.decode(data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        backup = decoded
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = BackupService.encode(backup) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}
