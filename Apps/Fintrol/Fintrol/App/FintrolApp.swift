import SwiftUI
import SwiftData

/// FIN-2026 (Avie): the previous version of this init caught ANY container-creation failure
/// — including a merely corrupt/incompatible on-disk store — and fell back to an in-memory
/// store with no signal to the user at all. That silently discarded every read AND every
/// future write for the rest of the session while looking, on screen, like a normal working
/// app. This is never acceptable, so the fallback is now: in `DEBUG`, delete the on-disk
/// store files and retry on disk once (safe — DEBUG builds run on simulators/dev devices with
/// no real user data to protect); in Release, never degrade to memory — surface the failure
/// via `storeLoadError` instead, which `RootView`'s wrapper below turns into a blocking alert.
enum StoreLoadError: LocalizedError {
    case diskStoreUnavailable

    var errorDescription: String? {
        "No se pudo abrir la base de datos local. Tus datos previos podrían no estar disponibles en esta sesión."
    }
}

@main
struct FintrolApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("fintrol.appearance") private var appearanceRaw: String = AppAppearance.system.rawValue

    private let modelContainer: ModelContainer
    private let storeLoadError: StoreLoadError?
    @State private var exchangeRateStore = ExchangeRateStore()
    @State private var lockStore = BiometricLockStore()
    @State private var isShowingStoreLoadError = false

    init() {
        let schema = Schema(SchemaV2.models)
        let diskConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)

        if let container = try? ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: [diskConfiguration]) {
            modelContainer = container
            storeLoadError = nil
        } else {
            #if DEBUG
            Self.deleteStoreFiles(for: diskConfiguration)
            if let retried = try? ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: [diskConfiguration]) {
                modelContainer = retried
                storeLoadError = nil
            } else {
                modelContainer = Self.emergencyInMemoryContainer(schema: schema)
                storeLoadError = .diskStoreUnavailable
            }
            #else
            modelContainer = Self.emergencyInMemoryContainer(schema: schema)
            storeLoadError = .diskStoreUnavailable
            #endif
        }
    }

    // Ivan (SECURITY_AUDIT.md, Low): these two functions are only ever CALLED from inside
    // `#if DEBUG` above, so they already never run in Release — but wrapping the call site
    // alone still leaves the function bodies themselves compiled into a Release build,
    // relying on the linker's dead-code stripping to drop them. Wrapping the full
    // definitions in `#if DEBUG` makes the compiler itself the guarantee instead.
    #if DEBUG
    /// Coordinator rule: simulator/dev data captured while testing must survive. Before ever
    /// deleting a corrupt on-disk store, copy it (main file + `-wal`/`-shm`) to
    /// `Documents/Backups/store-<fecha>.sqlite` so it can be inspected/recovered later, and
    /// log that a backup happened (no sensitive content, just the destination filename).
    private static func deleteStoreFiles(for configuration: ModelConfiguration) {
        let storeURL = configuration.url
        let fileManager = FileManager.default
        backupStoreFiles(storeURL: storeURL, fileManager: fileManager)
        for suffix in ["", "-wal", "-shm"] {
            let fileURL = URL(fileURLWithPath: storeURL.path + suffix)
            try? fileManager.removeItem(at: fileURL)
        }
    }

    private static func backupStoreFiles(storeURL: URL, fileManager: FileManager) {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let backupsDir = documents.appendingPathComponent("Backups", isDirectory: true)
        try? fileManager.createDirectory(at: backupsDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let stamp = formatter.string(from: Date())

        var copiedAny = false
        for suffix in ["", "-wal", "-shm"] {
            let sourceURL = URL(fileURLWithPath: storeURL.path + suffix)
            guard fileManager.fileExists(atPath: sourceURL.path) else { continue }
            let destURL = backupsDir.appendingPathComponent("store-\(stamp)\(suffix).sqlite")
            if (try? fileManager.copyItem(at: sourceURL, to: destURL)) != nil { copiedAny = true }
        }
        if copiedAny {
            print("[FintrolApp] Backed up unreadable store to Documents/Backups/store-\(stamp).sqlite before recovery delete.")
        }
    }
    #endif

    private static func emergencyInMemoryContainer(schema: Schema) -> ModelContainer {
        let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return (try? ModelContainer(for: schema, configurations: [memoryConfiguration])) ?? {
            fatalError("Unable to create even an in-memory ModelContainer for SchemaV2")
        }()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(exchangeRateStore)
                .environment(lockStore)
                .preferredColorScheme((AppAppearance(rawValue: appearanceRaw) ?? .system).colorScheme)
                .onAppear {
                    if lockStore.isLockEnabled { lockStore.resetForColdStart() }
                    if storeLoadError != nil { isShowingStoreLoadError = true }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    lockStore.handleScenePhaseChange(newPhase)
                }
                .alert("No se pudo abrir la base de datos local", isPresented: $isShowingStoreLoadError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(storeLoadError?.errorDescription ?? "")
                }
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        .windowResizability(.contentSize)
        .defaultSize(width: 1000, height: 700)
        #endif

        #if os(macOS)
        // "Ajustes generales › macOS" (DESIGN_LIQUID.md): native Settings scene (⌘,),
        // fixed 420pt width, same Preferencias/Seguridad grouping as the iOS tab.
        Settings {
            NavigationStack {
                SettingsView()
            }
            .environment(exchangeRateStore)
            .environment(lockStore)
            .modelContainer(modelContainer)
            .preferredColorScheme((AppAppearance(rawValue: appearanceRaw) ?? .system).colorScheme)
            .frame(width: 420)
        }
        #endif
    }
}
