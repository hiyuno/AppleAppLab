#if os(macOS)
import Foundation
import AppleAppLabUI

/// One component's config as the app renders it under the theme.
public struct ResolvedPattern: Sendable {
    public let name: String
    public let spacing: Double
    public let cornerRadius: Double
    public let duration: Double
    public let borderWidth: Double
    public let surfaceOpacity: Double

    /// Every built-in pattern through `LabTheme.config(for:base:)`, the same call the app makes.
    @MainActor
    public static func all(for theme: LabTheme) -> [ResolvedPattern] {
        LabPatternRegistry.builtIn.map { entry in
            let c = theme.config(for: entry.name, base: entry.defaultConfig)
            return ResolvedPattern(name: entry.name, spacing: Double(c.spacing), cornerRadius: Double(c.cornerRadius),
                                   duration: c.duration, borderWidth: Double(c.borderWidth), surfaceOpacity: c.surfaceOpacityMultiplier)
        }
    }
}

/// The resolved color of each semantic role, per mode, and where it came from.
struct RoleColor {
    let role: String
    let values: [Mode: RGBA]
    let ext: JSONValue
}

/// Builds `tokens.tokens.json` (contract §5) from the theme, the app's color assets and
/// the platform's system colors. Pure: no file access.
public struct TokenBuilder {
    let theme: LabTheme
    let platform: Platform
    let assetColors: [AssetColor]
    let patterns: [ResolvedPattern]

    public init(theme: LabTheme, platform: Platform, assetColors: [AssetColor], patterns: [ResolvedPattern]) {
        self.theme = theme
        self.platform = platform
        self.assetColors = assetColors
        self.patterns = patterns
    }

    /// Asset color-set names that play a semantic role, in priority order.
    static let roleAssetNames: [String: [String]] = [
        "background": ["AppBackground", "Background", "BackgroundPrimary", "PrimaryBackground", "WindowBackground"],
        "card": ["CardBackground", "Card", "Surface", "SurfaceBackground", "AppBackgroundSecondary", "BackgroundSecondary", "SecondaryBackground"],
        "muted": ["Muted", "AppBackgroundTertiary", "BackgroundTertiary", "TertiaryBackground"],
        "foreground": ["TextPrimary", "PrimaryText", "Foreground", "Label"],
        "muted-foreground": ["TextSecondary", "SecondaryText", "SecondaryLabel", "MutedForeground"],
        "border": ["Border", "Separator", "Divider"]
    ]

    public var modes: [Mode] {
        switch theme.appearanceMode {
        case .light: [.light]
        case .dark: [.dark]
        case .system: [.light, .dark]
        }
    }

    var palette: SystemPalette { .forPlatform(platform) }
    var accent: RGBA { theme.accentColor.rgba }

    func asset(for role: String) -> AssetColor? {
        for name in Self.roleAssetNames[role] ?? [] {
            if let a = assetColors.first(where: { $0.name == name }) { return a }
        }
        return nil
    }

    /// The theme background per mode. A theme saved while following the system keeps
    /// the window background it was exported under; when it matches the platform's,
    /// the app really shows the system color in each mode.
    public func themeBackground(_ mode: Mode) -> RGBA {
        let bg = theme.backgroundColor.rgba
        let backdrop = mode == .dark ? RGBA(0, 0, 0) : RGBA(1, 1, 1)
        if modes.count == 2 {
            let window = palette.windowBackground
            if ColorMath.distance(bg.opaque, window.light) < 0.02 || ColorMath.distance(bg.opaque, window.dark) < 0.02 {
                return window.value(mode)
            }
        }
        return bg.composited(over: backdrop)
    }

    var themeBackgroundIsSystem: Bool {
        modes.count == 2 && themeBackground(.light) != themeBackground(.dark)
    }

    func roles() -> [RoleColor] {
        func fromAsset(_ role: String, over background: [Mode: RGBA]) -> RoleColor? {
            guard let a = asset(for: role) else { return nil }
            var values: [Mode: RGBA] = [:]
            for m in modes { values[m] = a.value(m).composited(over: background[m] ?? RGBA(0, 0, 0)) }
            return RoleColor(role: role, values: values, ext: obj(("asset", .string(a.name))))
        }
        func fromSystem(_ role: String, _ color: SystemColor, over background: [Mode: RGBA]?) -> RoleColor {
            var values: [Mode: RGBA] = [:]
            for m in modes {
                let raw = color.value(m)
                values[m] = background.map { raw.composited(over: $0[m]!) } ?? raw.opaque
            }
            var ext: [(String, JSONValue)] = [("system_color", .string(color.name))]
            if background != nil, color.light.a < 1 || color.dark.a < 1 { ext.append(("composited_over", "background")) }
            return RoleColor(role: role, values: values, ext: .object(ext))
        }

        var bgValues: [Mode: RGBA] = [:]
        for m in modes { bgValues[m] = themeBackground(m) }
        let bgExt: JSONValue = themeBackgroundIsSystem
            ? obj(("theme", "backgroundColor"), ("system_color", .string(palette.windowBackground.name)))
            : obj(("theme", "backgroundColor"))
        let background = RoleColor(role: "background", values: bgValues, ext: bgExt)

        return [
            background,
            fromAsset("foreground", over: bgValues) ?? fromSystem("foreground", palette.label, over: bgValues),
            fromAsset("muted", over: bgValues) ?? fromSystem("muted", palette.fill, over: bgValues),
            fromAsset("muted-foreground", over: bgValues) ?? fromSystem("muted-foreground", palette.secondaryLabel, over: bgValues),
            fromAsset("card", over: bgValues) ?? fromSystem("card", palette.card, over: nil),
            fromAsset("border", over: bgValues) ?? fromSystem("border", palette.separator, over: bgValues),
            fromSystem("danger", palette.red, over: nil),
            fromSystem("success", palette.green, over: nil),
            fromSystem("warning", palette.orange, over: nil)
        ]
    }

    // MARK: - Build

    public func build() -> JSONValue {
        let ramp = BrandRamp.build(accent: accent.opaque)
        let sourceStep = ramp.first { $0.isSource }!.key
        let roleColors = roles()
        let usedAssets = Set(roleColors.compactMap { $0.ext["asset"]?.stringValue })
        let suffix: (Mode) -> String = { "-\($0.rawValue)" }

        // color
        var app: [(String, JSONValue)] = []
        for rc in roleColors {
            for m in modes {
                app.append((rc.role + suffix(m), obj(("$value", .string(rc.values[m]!.hex)), ("$extensions", obj(("appleapplab", rc.ext))))))
            }
        }
        for a in assetColors where !usedAssets.contains(a.name) {
            for m in modes {
                let backdrop = m == .dark ? RGBA(0, 0, 0) : RGBA(1, 1, 1)
                app.append(("asset-\(RepoProbe.kebab(a.name))" + suffix(m),
                            obj(("$value", .string(a.value(m).composited(over: backdrop).hex)),
                                ("$extensions", obj(("appleapplab", obj(("asset", .string(a.name)))))))))
            }
        }
        let brand: [(String, JSONValue)] = ramp.map { step in
            (step.key, obj(("$value", .string(step.value)),
                           ("$extensions", obj(("appleapplab", step.isSource
                                ? obj(("source", true), ("theme", "accentColor"))
                                : obj(("derived", true)))))))
        }
        let color = obj(
            ("$type", "color"),
            ("brand", .object(brand)),
            ("white", obj(("$value", "#ffffff"))),
            ("black", obj(("$value", "#000000"))),
            ("app", .object(app))
        )

        // semantic
        let primaryMode = modes.first!
        func semanticColor(_ role: String) -> JSONValue {
            let light = modes.contains(.light) ? "{color.app.\(role)-light}" : "{color.app.\(role)-\(primaryMode.rawValue)}"
            var pairs: [(String, JSONValue)] = [("$value", .string(light))]
            if modes.contains(.dark) {
                pairs.append(("$extensions", obj(("web-lab", obj(("dark", .string("{color.app.\(role)-dark}")))))))
            }
            return .object(pairs)
        }
        func fixed(_ ref: String) -> JSONValue {
            var pairs: [(String, JSONValue)] = [("$value", .string(ref))]
            if modes.contains(.dark) { pairs.append(("$extensions", obj(("web-lab", obj(("dark", .string(ref))))))) }
            return .object(pairs)
        }
        let brandRef = "{color.brand.\(sourceStep)}"
        let semantic = obj(
            ("$description", "The app's decisions as shipped. Single-mode apps carry a placeholder $value (see root mode_missing)."),
            ("color", obj(
                ("$type", "color"),
                ("background", semanticColor("background")),
                ("foreground", semanticColor("foreground")),
                ("muted", semanticColor("muted")),
                ("muted-foreground", semanticColor("muted-foreground")),
                ("card", semanticColor("card")),
                ("border", semanticColor("border")),
                ("accent", fixed(brandRef)),
                ("accent-foreground", fixed("{color.white}")),
                ("danger", semanticColor("danger")),
                ("success", semanticColor("success")),
                ("warning", semanticColor("warning")),
                ("ring", fixed(brandRef))
            )),
            ("radius", obj(("$type", "dimension"), ("control", obj(("$value", "{radius.md}"))), ("surface", obj(("$value", "{radius.lg}"))))),
            ("duration", obj(("$type", "duration"), ("ui", obj(("$value", "{duration.normal}"))))),
            ("ease", obj(("$type", "cubicBezier"), ("ui", obj(("$value", "{ease.out}")))))
        )

        let root: [(String, JSONValue)] = [
            ("$schema", "https://tr.designtokens.org/format/"),
            ("$description", .string("\(theme.name) brand package tokens, generated by lab-brand-package from the app's theme, color assets and Apple system colors. Edit the app, not this file.")),
            ("color", color),
            ("spacing", spacing()),
            ("text", text()),
            ("font", font()),
            ("radius", radius()),
            ("shadow", shadow()),
            ("ease", ease()),
            ("duration", duration()),
            ("semantic", semantic),
            ("component", obj(("corner-shape", obj(("$value", .string(cornerShape)))))),
            ("$extensions", rootExtensions())
        ]
        return .object(root)
    }

    var cornerShape: String {
        switch theme.cornerStyle {
        case .squircle: "squircle"
        case .rounded: "round"
        case .sharp: "sharp"
        }
    }

    func rem(_ points: Double) -> String {
        points == 0 ? "0px" : ColorMath.trim(points / 16, 4) + "rem"
    }

    func spacing() -> JSONValue {
        let keys = [0, 1, 2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24, 32]
        var pairs: [(String, JSONValue)] = [
            ("$type", "dimension"),
            ("$description", "Keyed from the app's 4 pt base unit (1 pt = 1 px). Derived: the real per-component values are in $extensions.appleapplab.patterns."),
            ("$extensions", obj(("appleapplab", obj(("derived", true), ("base_unit_pt", 4)))))
        ]
        for k in keys {
            pairs.append((String(k), obj(("$value", .string(rem(Double(k * 4)))), ("$extensions", obj(("appleapplab", obj(("derived", true))))))))
        }
        return .object(pairs)
    }

    func text() -> JSONValue {
        let styles = TextStyles.forPlatform(platform)
        var pairs: [(String, JSONValue)] = [
            ("$type", "dimension"),
            ("$description", .string("\(platform == .macos ? "macOS" : "iOS") Dynamic Type default sizes, 1 pt = 1 px, unscaled. web-lab keys (xs…3xl) alias the Apple style that plays that role."))
        ]
        for s in styles {
            pairs.append((s.key, obj(("$value", .string(rem(s.size))),
                                     ("$extensions", obj(("appleapplab", obj(("text_style", .string(s.swiftUI)), ("points", .number(s.size)), ("weight", .string(s.weight)))))))))
        }
        for (web, apple) in TextStyles.webAliases {
            pairs.append((web, obj(("$value", .string("{text.\(apple)}")))))
        }
        return .object(pairs)
    }

    func font() -> JSONValue {
        let system: [JSONValue] = ["system-ui", "-apple-system", "BlinkMacSystemFont", "Segoe UI", "Roboto", "sans-serif"]
        var pairs: [(String, JSONValue)] = [("$type", "fontFamily")]
        let ext = obj(("appleapplab", obj(("font_design", .string(theme.fontDesign.rawValue)), ("font_weight", .string(theme.fontWeight.rawValue)))))
        switch theme.fontDesign {
        case .rounded:
            pairs.append(("sans", obj(("$value", .array(["ui-rounded", "system-ui", "sans-serif"])), ("$extensions", ext))))
        default:
            pairs.append(("sans", obj(("$value", .array(system)), ("$extensions", ext))))
        }
        if theme.fontDesign == .serif {
            pairs.append(("serif", obj(("$value", .array(["ui-serif", "New York", "Georgia", "serif"])))))
        }
        if theme.fontDesign == .monospaced {
            pairs.append(("mono", obj(("$value", .array(["ui-monospace", "SF Mono", "Menlo", "monospace"])))))
        }
        return .object(pairs)
    }

    func pattern(_ name: String) -> ResolvedPattern? { patterns.first { $0.name == name } }

    func radius() -> JSONValue {
        let sharp = theme.cornerStyle == .sharp
        func token(_ points: Double, _ source: JSONValue) -> JSONValue {
            obj(("$value", .string(sharp ? "0px" : rem(points))), ("$extensions", obj(("appleapplab", source))))
        }
        let input = pattern("Formularios/inputs")?.cornerRadius ?? Double(RadiusTokens.input)
        let card = pattern("Cards")?.cornerRadius ?? Double(RadiusTokens.card)
        let button = pattern("Botones y controles")?.cornerRadius ?? Double(RadiusTokens.pill)
        return obj(
            ("$type", "dimension"),
            ("$description", .string("The app's corner radii (\(theme.cornerStyle.rawValue)). A sharp app draws every corner square.")),
            ("none", obj(("$value", "0px"))),
            ("sm", token(Double(RadiusTokens.nestedInCard), obj(("swiftui", "RadiusTokens.nestedInCard"), ("points", .number(Double(RadiusTokens.nestedInCard)))))),
            ("md", token(input, obj(("pattern", "Formularios/inputs"), ("points", .number(input))))),
            ("lg", token(card, obj(("pattern", "Cards"), ("points", .number(card))))),
            ("button", token(button, obj(("pattern", "Botones y controles"), ("points", .number(button))))),
            ("full", obj(("$value", .string(sharp ? "0px" : "9999px"))))
        )
    }

    func shadow() -> JSONValue {
        func css(_ e: ElevationLevel) -> String {
            e.shadowOpacity == 0
                ? "0 0 0 0 rgb(0 0 0 / 0)"
                : "0 \(JSONValue.format(Double(e.shadowY)))px \(JSONValue.format(Double(e.shadowRadius)))px 0 rgb(0 0 0 / \(JSONValue.format(e.shadowOpacity)))"
        }
        func token(_ e: ElevationLevel, _ extra: [(String, JSONValue)] = []) -> JSONValue {
            obj(("$value", .string(css(e))), ("$extensions", obj(("appleapplab", .object([("elevation", .string(e.rawValue))] + extra)))))
        }
        return obj(
            ("$type", "shadow"),
            ("$description", "SwiftUI .shadow(radius:y:) per ElevationLevel; the radius is written as the CSS blur. md is the app's surface elevation."),
            ("sm", token(.subtle)),
            ("md", token(theme.elevation, [("theme", "elevation")])),
            ("lg", token(.elevated))
        )
    }

    func token(_ value: String, _ app: [(String, JSONValue)]) -> JSONValue {
        obj(("$value", .string(value)), ("$extensions", obj(("appleapplab", .object(app)))))
    }

    /// Mirrors `MotionTokens` (pinned by a test).
    func ease() -> JSONValue {
        obj(
            ("$type", "cubicBezier"),
            ("out", token("cubic-bezier(0, 0, 0.58, 1)", [("swiftui", "easeOut"), ("used_by", "MotionTokens.entrance, selectionChange")])),
            ("in", token("cubic-bezier(0.42, 0, 1, 1)", [("swiftui", "easeIn"), ("used_by", "MotionTokens.exit")])),
            ("in-out", token("cubic-bezier(0.42, 0, 0.58, 1)", [("swiftui", "easeInOut")])),
            ("spring", token(SpringCurve.cssLinear(response: 0.3, damping: 0.7),
                             [("swiftui", "spring(response: 0.3, dampingFraction: 0.7)"), ("used_by", "MotionTokens.pressResponse")]))
        )
    }

    func duration() -> JSONValue {
        let settle = SpringCurve.settleTime(response: 0.3, damping: 0.7)
        return obj(
            ("$type", "duration"),
            ("$description", "Unscaled app durations; the app divides them by motion.speed_multiplier (manifest)."),
            ("fast", token("150ms", [("swiftui", "MotionTokens.selectionChange, exit")])),
            ("normal", token("200ms", [("swiftui", "MotionTokens.entrance")])),
            ("slow", token("\(Int((settle * 1000).rounded()))ms", [("swiftui", "MotionTokens.pressResponse settle time")]))
        )
    }

    func rootExtensions() -> JSONValue {
        let pairs: [(String, String, Double)] = [
            ("semantic.color.foreground", "semantic.color.background", 4.5),
            ("semantic.color.muted-foreground", "semantic.color.background", 4.5),
            ("semantic.color.foreground", "semantic.color.muted", 4.5),
            ("semantic.color.foreground", "semantic.color.card", 4.5),
            ("semantic.color.muted-foreground", "semantic.color.card", 4.5),
            ("semantic.color.accent-foreground", "semantic.color.accent", 4.5),
            ("semantic.color.accent", "semantic.color.background", 4.5),
            ("semantic.color.danger", "semantic.color.background", 4.5),
            ("semantic.color.success", "semantic.color.background", 4.5),
            ("semantic.color.warning", "semantic.color.background", 4.5),
            ("semantic.color.border", "semantic.color.background", 1.2),
            ("semantic.color.ring", "semantic.color.background", 3)
        ]
        let contrast = JSONValue.array(pairs.map { obj(("fg", .string($0.0)), ("bg", .string($0.1)), ("min", .number($0.2))) })

        var apple: [(String, JSONValue)] = [
            ("generator", "lab-brand-package"),
            ("theme", .string(theme.name)),
            ("primary_platform", .string(platform.rawValue)),
            ("app_modes", .array(modes.map { .string($0.rawValue) }))
        ]
        if modes == [.dark] { apple.append(("mode_missing", "light")) }
        if modes == [.light] { apple.append(("mode_missing", "dark")) }
        apple.append(("materials", materials()))
        apple.append(("patterns", .object(patterns.map { p in
            (RepoProbe.kebab(p.name), obj(
                ("name", .string(p.name)),
                ("spacing_pt", .number(p.spacing)),
                ("corner_radius_pt", .number(p.cornerRadius)),
                ("duration_s", .number(p.duration)),
                ("border_width_pt", .number(p.borderWidth)),
                ("surface_opacity", .number(p.surfaceOpacity))
            ))
        })))
        return obj(("web-lab", obj(("contrast", contrast))), ("appleapplab", .object(apple)))
    }

    func materials() -> JSONValue {
        guard theme.windowMaterial != .solid else { return obj(("app", "solid"), ("surfaces", obj())) }
        let mode = modes.first!.rawValue
        let window = obj(
            ("level", .number(theme.blurIntensity)),
            ("transparency", .number(theme.transparency)),
            ("tint", .string("{color.app.background-\(mode)}")),
            ("opaque_fallback", .string("{color.app.background-\(mode)}"))
        )
        return obj(("app", .string(theme.windowMaterial.rawValue)), ("surfaces", obj(("window", window))))
    }
}

extension CodableColor {
    var rgba: RGBA { RGBA(min(max(red, 0), 1), min(max(green, 0), 1), min(max(blue, 0), 1), min(max(opacity, 0), 1)) }
}
#endif
