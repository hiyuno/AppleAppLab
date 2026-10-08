import Foundation

/// The team's launch arguments for demo data. With `-LabSeedData` the app starts on
/// a fixed, fictional dataset in an in-memory store and never reads or writes the
/// user's real data — what key-screen captures, App Store screenshots and UI tests
/// run on. `-LabScreen <id>` opens one of the key screens listed in
/// `Docs/Design/key-screens.json`, so captures need no clicking. Each app provides its
/// own seed and routing (inside `#if DEBUG`); this is only the shared switch.
///
/// ```swift
/// #if DEBUG
/// let container = LabSeedData.isEnabled ? .seeded : .live
/// if let id = LabSeedData.screen { router.open(keyScreen: id) }
/// #endif
/// ```
public enum LabSeedData {
    public static let launchArgument = "-LabSeedData"
    public static let screenArgument = "-LabScreen"

    public static var isEnabled: Bool {
        isEnabled(in: ProcessInfo.processInfo.arguments)
    }

    /// The key-screen id after `-LabScreen`, only while seed data is on.
    public static var screen: String? {
        screen(in: ProcessInfo.processInfo.arguments)
    }

    static func isEnabled(in arguments: [String]) -> Bool {
        arguments.contains(launchArgument)
    }

    static func screen(in arguments: [String]) -> String? {
        guard isEnabled(in: arguments), let i = arguments.firstIndex(of: screenArgument), i + 1 < arguments.count else { return nil }
        return arguments[i + 1]
    }
}
