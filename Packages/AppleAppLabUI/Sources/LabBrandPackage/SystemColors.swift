import Foundation

public enum Platform: String, CaseIterable, Sendable {
    case ios, ipados, macos, watchos, visionos
}

public enum Mode: String, CaseIterable, Sendable {
    case light, dark
}

/// The system colors a LabTheme app renders with when the theme does not set a value,
/// resolved per platform and mode. Values are Apple's published defaults (HIG › Color,
/// "Specifications"); alpha colors are composited over the surface they sit on before
/// they enter the package, because the contract only accepts opaque colors.
public struct SystemColor: Sendable {
    public let name: String
    public let light: RGBA
    public let dark: RGBA

    public func value(_ mode: Mode) -> RGBA { mode == .light ? light : dark }
}

public struct SystemPalette: Sendable {
    public let windowBackground: SystemColor
    public let card: SystemColor
    public let fill: SystemColor
    public let label: SystemColor
    public let secondaryLabel: SystemColor
    public let separator: SystemColor
    public let red: SystemColor
    public let green: SystemColor
    public let orange: SystemColor

    public static func forPlatform(_ platform: Platform) -> SystemPalette {
        platform == .macos ? .macOS : .iOS
    }

    public static let iOS = SystemPalette(
        windowBackground: SystemColor(name: "systemBackground", light: RGBA(hex: "#ffffff")!, dark: RGBA(hex: "#000000")!),
        card: SystemColor(name: "secondarySystemBackground", light: RGBA(hex: "#f2f2f7")!, dark: RGBA(hex: "#1c1c1e")!),
        fill: SystemColor(name: "systemFill", light: RGBA(r255: 120, g255: 120, b255: 128, a: 0.2), dark: RGBA(r255: 120, g255: 120, b255: 128, a: 0.36)),
        label: SystemColor(name: "label", light: RGBA(0, 0, 0), dark: RGBA(1, 1, 1)),
        secondaryLabel: SystemColor(name: "secondaryLabel", light: RGBA(r255: 60, g255: 60, b255: 67, a: 0.6), dark: RGBA(r255: 235, g255: 235, b255: 245, a: 0.6)),
        separator: SystemColor(name: "separator", light: RGBA(r255: 60, g255: 60, b255: 67, a: 0.29), dark: RGBA(r255: 84, g255: 84, b255: 88, a: 0.6)),
        red: SystemColor(name: "systemRed", light: RGBA(hex: "#ff3b30")!, dark: RGBA(hex: "#ff453a")!),
        green: SystemColor(name: "systemGreen", light: RGBA(hex: "#34c759")!, dark: RGBA(hex: "#30d158")!),
        orange: SystemColor(name: "systemOrange", light: RGBA(hex: "#ff9500")!, dark: RGBA(hex: "#ff9f0a")!)
    )

    public static let macOS = SystemPalette(
        windowBackground: SystemColor(name: "windowBackgroundColor", light: RGBA(hex: "#ececec")!, dark: RGBA(hex: "#323232")!),
        card: SystemColor(name: "controlBackgroundColor", light: RGBA(hex: "#ffffff")!, dark: RGBA(hex: "#1e1e1e")!),
        fill: SystemColor(name: "quaternaryLabelColor", light: RGBA(0, 0, 0, 0.1), dark: RGBA(1, 1, 1, 0.1)),
        label: SystemColor(name: "labelColor", light: RGBA(0, 0, 0, 0.85), dark: RGBA(1, 1, 1, 0.85)),
        secondaryLabel: SystemColor(name: "secondaryLabelColor", light: RGBA(0, 0, 0, 0.5), dark: RGBA(1, 1, 1, 0.55)),
        separator: SystemColor(name: "separatorColor", light: RGBA(0, 0, 0, 0.1), dark: RGBA(1, 1, 1, 0.1)),
        red: SystemColor(name: "systemRed", light: RGBA(hex: "#ff3b30")!, dark: RGBA(hex: "#ff453a")!),
        green: SystemColor(name: "systemGreen", light: RGBA(hex: "#28cd41")!, dark: RGBA(hex: "#32d74b")!),
        orange: SystemColor(name: "systemOrange", light: RGBA(hex: "#ff9500")!, dark: RGBA(hex: "#ff9f0a")!)
    )
}

/// Dynamic Type default ("Large") sizes in points, per platform, with the weight
/// SwiftUI uses for each text style. Keys are the package's `text` token keys.
public enum TextStyles {
    public struct Style: Sendable {
        public let key: String
        public let swiftUI: String
        public let size: Double
        public let weight: String
    }

    public static func forPlatform(_ platform: Platform) -> [Style] {
        platform == .macos ? macOS : iOS
    }

    static let iOS: [Style] = [
        Style(key: "large-title", swiftUI: "largeTitle", size: 34, weight: "regular"),
        Style(key: "title-1", swiftUI: "title", size: 28, weight: "regular"),
        Style(key: "title-2", swiftUI: "title2", size: 22, weight: "regular"),
        Style(key: "title-3", swiftUI: "title3", size: 20, weight: "regular"),
        Style(key: "headline", swiftUI: "headline", size: 17, weight: "semibold"),
        Style(key: "body", swiftUI: "body", size: 17, weight: "regular"),
        Style(key: "callout", swiftUI: "callout", size: 16, weight: "regular"),
        Style(key: "subheadline", swiftUI: "subheadline", size: 15, weight: "regular"),
        Style(key: "footnote", swiftUI: "footnote", size: 13, weight: "regular"),
        Style(key: "caption-1", swiftUI: "caption", size: 12, weight: "regular"),
        Style(key: "caption-2", swiftUI: "caption2", size: 11, weight: "regular")
    ]

    static let macOS: [Style] = [
        Style(key: "large-title", swiftUI: "largeTitle", size: 26, weight: "regular"),
        Style(key: "title-1", swiftUI: "title", size: 22, weight: "regular"),
        Style(key: "title-2", swiftUI: "title2", size: 17, weight: "regular"),
        Style(key: "title-3", swiftUI: "title3", size: 15, weight: "regular"),
        Style(key: "headline", swiftUI: "headline", size: 13, weight: "bold"),
        Style(key: "body", swiftUI: "body", size: 13, weight: "regular"),
        Style(key: "callout", swiftUI: "callout", size: 12, weight: "regular"),
        Style(key: "subheadline", swiftUI: "subheadline", size: 11, weight: "regular"),
        Style(key: "footnote", swiftUI: "footnote", size: 10, weight: "regular"),
        Style(key: "caption-1", swiftUI: "caption", size: 10, weight: "regular"),
        Style(key: "caption-2", swiftUI: "caption2", size: 10, weight: "regular")
    ]

    /// web-lab's utility names (`text-sm`, `text-base`…) as aliases to the Apple
    /// style that plays that role, so the lab's preview renders with the app's sizes.
    public static let webAliases: [(String, String)] = [
        ("xs", "caption-1"), ("sm", "footnote"), ("base", "body"), ("lg", "title-3"),
        ("xl", "title-2"), ("2xl", "title-1"), ("3xl", "large-title")
    ]
}
