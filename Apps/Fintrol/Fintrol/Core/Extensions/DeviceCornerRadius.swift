import Foundation

/// The real device's physical screen corner radius (points, continuous/squircle curve).
///
/// iOS renders its screen mask with a "squircle" (continuous) curve whose radius is public
/// per-device data (the community `ScreenCorners` project has tracked it for years; Apple does
/// not expose it as a public API), not something derivable from `UIScreen.main.bounds` or any
/// other runtime geometry. So this looks the value up by hardware model identifier instead of
/// guessing a single constant for every device.
enum DeviceCornerRadius {

    /// The most recent/largest known radius (iPhone 16 Pro line and newer). Used as the fallback
    /// for any hardware identifier not in `radiusByIdentifier` — an unrecognized/future device is
    /// far more likely to be a new flagship than an old compact phone, and a slightly-too-large
    /// radius reads better than a visibly-too-small one on a modern display.
    static let fallback: CGFloat = 62.0

    #if os(iOS)
    /// Looked up once per launch — the physical device (or simulated device) never changes mid-run.
    static let current: CGFloat = {
        radiusByIdentifier[modelIdentifier] ?? fallback
    }()
    #else
    /// macOS has no physical "screen corner" concept tied to a window — callers on that platform
    /// should use their own fixed value. Kept here only so cross-platform call sites compile.
    static let current: CGFloat = 0
    #endif

    #if os(iOS)
    /// The hardware model identifier, e.g. `"iPhone15,2"`.
    ///
    /// `UIDevice.current.model` is NOT used here — it returns a generic string like `"iPhone"`,
    /// not the specific identifier needed to look up the corner radius.
    ///
    /// In the Simulator, `sysctlbyname("hw.machine", ...)` returns the HOST Mac's architecture
    /// (e.g. `"arm64"`), not the simulated iPhone's identifier. The documented way to get the
    /// *simulated* device's real model identifier is the `SIMULATOR_MODEL_IDENTIFIER` environment
    /// variable, which the Simulator sets for every process it launches — so that's checked first.
    static var modelIdentifier: String {
        if let simulatorIdentifier = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
           !simulatorIdentifier.isEmpty {
            return simulatorIdentifier
        }

        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce(into: "") { partialResult, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            partialResult.append(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier
    }

    /// Hardware identifier → real screen corner radius (points), per Steve's research.
    ///
    /// Identifier → marketing name mapping cross-checked against Apple's "Identify your iPhone
    /// model" support pages and standard developer references (e.g. `ipsw.me`, `theiphonewiki.com`
    /// device tables), current as of iPhone 17 / 17 Pro / 17 Pro Max / Air (2025):
    ///
    /// 47.33pt — iPhone 12, 12 Pro, 13 Pro, 14, 16e
    ///   iPhone 12          → iPhone13,2
    ///   iPhone 12 Pro      → iPhone13,3
    ///   iPhone 13 Pro      → iPhone14,2
    ///   iPhone 14          → iPhone14,7
    ///   iPhone 16e         → iPhone17,5
    ///
    /// 53.33pt — iPhone 12 Pro Max, 13 Pro Max, 14 Plus
    ///   iPhone 12 Pro Max  → iPhone13,4
    ///   iPhone 13 Pro Max  → iPhone14,3
    ///   iPhone 14 Plus     → iPhone14,8
    ///
    /// 55.0pt — iPhone 14 Pro, 14 Pro Max, 15, 15 Plus, 15 Pro, 15 Pro Max, 16, 16 Plus
    ///   iPhone 14 Pro      → iPhone15,2
    ///   iPhone 14 Pro Max  → iPhone15,3
    ///   iPhone 15          → iPhone15,4
    ///   iPhone 15 Plus     → iPhone15,5
    ///   iPhone 15 Pro      → iPhone16,1
    ///   iPhone 15 Pro Max  → iPhone16,2
    ///   iPhone 16          → iPhone17,3
    ///   iPhone 16 Plus     → iPhone17,4
    ///
    /// 62.0pt — iPhone 16 Pro, 16 Pro Max, 17, 17 Pro, 17 Pro Max, Air
    ///   iPhone 16 Pro      → iPhone17,1
    ///   iPhone 16 Pro Max  → iPhone17,2
    ///   iPhone 17          → iPhone18,3
    ///   iPhone Air         → iPhone18,4
    ///   iPhone 17 Pro      → iPhone18,1
    ///   iPhone 17 Pro Max  → iPhone18,2
    static let radiusByIdentifier: [String: CGFloat] = [
        // 47.33pt
        "iPhone13,2": 47.33, // iPhone 12
        "iPhone13,3": 47.33, // iPhone 12 Pro
        "iPhone14,2": 47.33, // iPhone 13 Pro
        "iPhone14,7": 47.33, // iPhone 14
        "iPhone17,5": 47.33, // iPhone 16e

        // 53.33pt
        "iPhone13,4": 53.33, // iPhone 12 Pro Max
        "iPhone14,3": 53.33, // iPhone 13 Pro Max
        "iPhone14,8": 53.33, // iPhone 14 Plus

        // 55.0pt
        "iPhone15,2": 55.0, // iPhone 14 Pro
        "iPhone15,3": 55.0, // iPhone 14 Pro Max
        "iPhone15,4": 55.0, // iPhone 15
        "iPhone15,5": 55.0, // iPhone 15 Plus
        "iPhone16,1": 55.0, // iPhone 15 Pro
        "iPhone16,2": 55.0, // iPhone 15 Pro Max
        "iPhone17,3": 55.0, // iPhone 16
        "iPhone17,4": 55.0, // iPhone 16 Plus

        // 62.0pt
        "iPhone17,1": 62.0, // iPhone 16 Pro
        "iPhone17,2": 62.0, // iPhone 16 Pro Max
        "iPhone18,3": 62.0, // iPhone 17
        "iPhone18,4": 62.0, // iPhone Air
        "iPhone18,1": 62.0, // iPhone 17 Pro
        "iPhone18,2": 62.0  // iPhone 17 Pro Max
    ]
    #endif
}
