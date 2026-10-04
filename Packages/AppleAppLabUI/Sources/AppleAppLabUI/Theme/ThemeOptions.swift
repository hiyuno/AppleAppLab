import SwiftUI

// Option enums that a theme carries besides the token enums that already live in
// `Tokens/` (CornerStyle, WindowMaterial, WindowTitleBarStyle, ElevationLevel).
// Raw values are the JSON values in `Themes/*.json` — do not rename cases.

public enum FontDesignOption: String, CaseIterable, Identifiable, Codable, Sendable, Hashable {
    case standard
    case rounded
    case serif
    case monospaced

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .standard: "Default"
        case .rounded: "Rounded"
        case .serif: "Serif"
        case .monospaced: "Monospaced"
        }
    }

    public var design: Font.Design {
        switch self {
        case .standard: .default
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        }
    }
}

public enum FontWeightOption: String, CaseIterable, Identifiable, Codable, Sendable, Hashable {
    case regular
    case medium
    case semibold

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .regular: "Regular"
        case .medium: "Medium"
        case .semibold: "Semibold"
        }
    }

    public var weight: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        }
    }
}

public enum Density: String, CaseIterable, Identifiable, Codable, Sendable, Hashable {
    case compact
    case regular
    case comfortable

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .compact: "Compact"
        case .regular: "Regular"
        case .comfortable: "Comfortable"
        }
    }

    /// Multiplies each pattern's own default spacing.
    public var scale: CGFloat {
        switch self {
        case .compact: 0.75
        case .regular: 1.0
        case .comfortable: 1.3
        }
    }
}

public enum IconRenderingMode: String, CaseIterable, Identifiable, Codable, Sendable, Hashable {
    case monochrome
    case hierarchical
    case multicolor

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .monochrome: "Monochrome"
        case .hierarchical: "Hierarchical"
        case .multicolor: "Multicolor"
        }
    }

    public var mode: SymbolRenderingMode {
        switch self {
        case .monochrome: .monochrome
        case .hierarchical: .hierarchical
        case .multicolor: .multicolor
        }
    }
}

public enum AppearanceMode: String, CaseIterable, Identifiable, Codable, Sendable, Hashable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    public var symbolName: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// A wallpaper behind the simulated window in PatternLibrary. The package only
/// carries the identity; whoever owns the image assets resolves `fileName`.
public struct WallpaperOption: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let displayName: String
    public let fileName: String

    public init(id: String, displayName: String, fileName: String) {
        self.id = id
        self.displayName = displayName
        self.fileName = fileName
    }

    public static let none = WallpaperOption(id: "none", displayName: "None", fileName: "")

    public static let all: [WallpaperOption] = [
        .none,
        WallpaperOption(id: "wallpaper-07", displayName: "Wallpaper 07", fileName: "wallpaper-07"),
        WallpaperOption(id: "wallpaper-10", displayName: "Wallpaper 10", fileName: "wallpaper-10"),
        WallpaperOption(id: "wallpaper-11", displayName: "Wallpaper 11", fileName: "wallpaper-11"),
        WallpaperOption(id: "wallpaper-30", displayName: "Wallpaper 30", fileName: "wallpaper-30")
    ]
}
