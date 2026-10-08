#if os(macOS)
import Foundation
import AppleAppLabUI

/// A value two sources of the app state differently. A package is not published while
/// any is open: Yuno picks one, Jonny fixes the source that lost (contract §1).
public struct Difference: Sendable {
    public let field: String
    public let question: String
    public let candidates: [(source: String, value: String)]
}

public enum Bump: String, Sendable, Comparable {
    case none, patch, minor, major
    static let order: [Bump] = [.none, .patch, .minor, .major]
    public static func < (a: Bump, b: Bump) -> Bool { order.firstIndex(of: a)! < order.firstIndex(of: b)! }
}

public struct Plan: Sendable {
    public let snapshot: RepoSnapshot
    public let manifest: JSONValue
    public let tokens: JSONValue
    /// Destination (relative to `brand-package/`) ← source file.
    public let copies: [(dest: String, source: URL)]
    public let differences: [Difference]
    /// Stop publication.
    public let blocking: [String]
    /// Published anyway; web-lab treats them as missing optional assets (contract §10.4).
    public let warnings: [String]
    public let previousVersion: String?
    public let version: String?
    public let bump: Bump
    public let reasons: [String]

    public var canWrite: Bool { differences.isEmpty && blocking.isEmpty && version != nil }
}

public enum Generator {
    public static let schemaVersion = "1.0"

    @MainActor
    public static func plan(_ options: ProbeOptions, requireClean: Bool, today: Date = Date()) -> Plan {
        let snap = RepoProbe.snapshot(options)
        var blocking = snap.problems
        var warnings: [String] = []
        var copies: [(String, URL)] = []

        guard let theme = snap.theme, let primary = snap.primary else {
            return Plan(snapshot: snap, manifest: .null, tokens: .null, copies: [], differences: [], blocking: blocking,
                        warnings: warnings, previousVersion: nil, version: nil, bump: .none, reasons: [])
        }

        if requireClean && !snap.dirtyPaths.isEmpty {
            blocking.append("Hay cambios sin commit fuera de `brand-package/` (\(snap.dirtyPaths.prefix(5).joined(separator: ", "))\(snap.dirtyPaths.count > 5 ? "…" : "")). El paquete se genera desde un commit limpio.")
        }

        let builder = TokenBuilder(theme: theme, platform: primary, assetColors: snap.assetColors, patterns: ResolvedPattern.all(for: theme))
        let tokens = builder.build()
        let differences = findDifferences(snap, builder: builder)

        // Icons
        var iconJSON: [(String, JSONValue)] = []
        if let ios = snap.iconIOS {
            if ios.width != 1024 || ios.height != 1024 {
                blocking.append("El ícono de iOS mide \(ios.width)×\(ios.height); el contrato pide 1024×1024.")
            } else if ios.hasAlpha {
                blocking.append("El ícono de iOS (`\(ios.url.lastPathComponent)`) tiene canal alfa; el maestro va sin alfa y sin máscara.")
            } else {
                copies.append(("assets/icon/app-icon-ios-1024.png", ios.url))
                iconJSON.append(("ios_1024", "assets/icon/app-icon-ios-1024.png"))
            }
        } else {
            blocking.append("No hay ícono de iOS 1024×1024: ni en `AppIcon.appiconset` ni exportado a mano en `brand-package/assets/icon/app-icon-ios-1024.png`.")
        }
        if let mac = snap.iconMac, mac.width == 1024, mac.height == 1024 {
            copies.append(("assets/icon/app-icon-macos-1024.png", mac.url))
            iconJSON.append(("macos_1024", "assets/icon/app-icon-macos-1024.png"))
        } else if snap.platforms.contains(.macos) {
            warnings.append(snap.hasIconComposerFile
                ? "Ícono de macOS: la app usa Icon Composer (`.icon`). Expórtalo a mano como `brand-package/assets/icon/app-icon-macos-1024.png` (opcional)."
                : "Sin ícono de macOS 1024 (opcional).")
        }

        // Logo
        let logo: JSONValue
        if let svg = snap.logoSVG {
            var pairs: [(String, JSONValue)] = [("svg", .string(svg))]
            if let dark = snap.logoOnDarkSVG { pairs.append(("on_dark_svg", .string(dark))) }
            logo = .object(pairs)
            blocking.append(contentsOf: snap.logoProblems)
        } else {
            logo = obj(("same_as_icon", true))
            warnings.append("Sin `assets/logo/logo.svg`: el logo es el ícono (`same_as_icon`).")
        }

        // Key screens
        var screensJSON: [JSONValue] = []
        if let error = snap.keyScreensSpecError { blocking.append(error) }
        if snap.keyScreensSpecPath == nil {
            blocking.append("Falta `Docs/Design/key-screens.json` con las 3 a 6 pantallas clave (Jonny las elige).")
        } else if !(3...6).contains(snap.keyScreens.count) {
            blocking.append("`\(snap.keyScreensSpecPath!)` lista \(snap.keyScreens.count) pantallas; el contrato pide de 3 a 6.")
        }
        for spec in snap.keyScreens {
            if RepoProbe.kebab(spec.id) != spec.id { blocking.append("El id de pantalla `\(spec.id)` debe ir en kebab-case.") }
            var files: [JSONValue] = []
            for state in spec.states {
                for mode in builder.modes {
                    for scale in captureScales(spec.platform) {
                        let file = "assets/screens/\(spec.id)-\(RepoProbe.kebab(state))-\(mode.rawValue)@\(scale)x.png"
                        if snap.screenFiles.contains(file) {
                            files.append(.string(file))
                        } else {
                            blocking.append("Falta la captura `\(file)` (Woz, con `-LabSeedData`).")
                        }
                    }
                }
            }
            screensJSON.append(obj(("id", .string(spec.id)), ("platform", .string(spec.platform.rawValue)), ("view", .string(spec.view)),
                                   ("states", .array(spec.states.map { .string($0) })), ("files", .array(files))))
        }

        // Icons map
        if snap.hasIconsMap && !snap.iconsMapValid { blocking.append("`icons.map.json` no es JSON válido.") }
        if !snap.hasIconsMap && snap.iconSystem != "custom" {
            warnings.append("Sin `icons.map.json`: si las pantallas clave muestran SF Symbols, Jonny lo escribe (SF Symbol → Lucide o Phosphor).")
        }
        if snap.screenshotFiles.isEmpty { warnings.append("Sin screenshots de App Store todavía (Phil, desde pre-lanzamiento).") }

        // Manifest
        var assets: [(String, JSONValue)] = [("logo", logo), ("icon", .object(iconJSON))]
        if !snap.screenshotFiles.isEmpty { assets.append(("screenshots", .array(snap.screenshotFiles.map { .string($0) }))) }
        var icons: [(String, JSONValue)] = [("app_system", .string(snap.iconSystem))]
        if snap.hasIconsMap { icons.append(("map", "icons.map.json")) }

        let materials = theme.windowMaterial == .solid ? [] : ["window"]
        var manifestPairs: [(String, JSONValue)] = [
            ("schema_version", .string(schemaVersion)),
            ("package_version", "0.0.0"),
            ("generated_at", .string(isoDate(today))),
            ("app", obj(("name", .string(snap.name)), ("slug", .string(snap.slug)))),
            ("source", obj(("repo", snap.remote.map { .string($0) } ?? .null),
                           ("commit", snap.commit.map { .string($0) } ?? .null),
                           ("intake", snap.intakePath.map { .string($0) } ?? .null))),
            ("primary_platform", .string(primary.rawValue)),
            ("platforms", .array(snap.platforms.map { .string($0.rawValue) })),
            ("appearance", obj(("app_modes", .array(builder.modes.map { .string($0.rawValue) })))),
            ("typography", obj(("font_design", .string(theme.fontDesign.rawValue)), ("font_weight", .string(theme.fontWeight.rawValue)))),
            ("shape", obj(("corner_style", .string(theme.cornerStyle.rawValue)))),
            ("materials", obj(("app", .string(theme.windowMaterial.rawValue)), ("surfaces", .array(materials.map { .string($0) })))),
            ("motion", obj(("speed_multiplier", .number(min(max(theme.motionSpeedMultiplier, 0.5), 2.0))))),
            ("icons", .object(icons)),
            ("assets", .object(assets))
        ]
        if let design = snap.designFile { manifestPairs.append(("design_file", design)) }
        manifestPairs.append(("ui", obj(("key_screens", .array(screensJSON)))))
        if !(0.5...2.0).contains(theme.motionSpeedMultiplier) {
            warnings.append("`motionSpeedMultiplier` \(theme.motionSpeedMultiplier) está fuera de 0.5–2.0; el paquete lo acota.")
        }
        var manifest = JSONValue.object(manifestPairs)

        // Secrets and local paths
        let text = manifest.serialized() + tokens.serialized()
        for (pattern, label) in secretPatterns where text.range(of: pattern, options: .regularExpression) != nil {
            blocking.append("El paquete contiene \(label). Quítalo en el origen antes de publicar.")
        }

        // Version
        let versioning = Versioning.compare(snapshot: snap, manifest: manifest, tokens: tokens, copies: copies)
        var version: String?
        if versioning.bump != .none || versioning.previous == nil {
            version = Versioning.next(versioning.previous, versioning.previous == nil ? .major : versioning.bump)
            manifest = replacing(manifest, key: "package_version", with: .string(version!))
        }

        return Plan(snapshot: snap, manifest: manifest, tokens: tokens, copies: copies, differences: differences,
                    blocking: blocking, warnings: warnings, previousVersion: versioning.previous,
                    version: version, bump: versioning.previous == nil ? .major : versioning.bump, reasons: versioning.reasons)
    }

    static let secretPatterns: [(String, String)] = [
        (#"/Users/|/home/|/private/|file://"#, "una ruta local absoluta"),
        (#"figd_[A-Za-z0-9_-]+"#, "un token de Figma"),
        (#"gh[pousr]_[A-Za-z0-9]{20,}|github_pat_"#, "un token de GitHub"),
        (#"\bsk-[A-Za-z0-9]{16,}"#, "una API key"),
        (#"AKIA[0-9A-Z]{16}"#, "una llave de AWS"),
        (#"xox[abps]-"#, "un token de Slack"),
        (#"(?i)[?&](access_)?token="#, "un token en una URL")
    ]

    static func captureScales(_ platform: Platform) -> [Int] {
        switch platform {
        case .macos: [1, 2]
        case .ios, .ipados: [3]
        case .watchos, .visionos: [2]
        }
    }

    static func findDifferences(_ snap: RepoSnapshot, builder: TokenBuilder) -> [Difference] {
        guard let theme = snap.theme else { return [] }
        var out: [Difference] = []
        let accent = theme.accentColor.rgba.opaque
        let themeSource = "tema \(snap.themePath ?? theme.name)"

        var accentOthers: [SourceValue] = []
        if let a = snap.accentAsset { accentOthers.append(SourceValue(source: "Assets.xcassets/AccentColor", value: a.opaque)) }
        accentOthers += snap.designAccents + snap.codeAccents
        let disagreeing = accentOthers.filter { ColorMath.distance($0.value, accent) > 0.02 }
        if !disagreeing.isEmpty {
            out.append(Difference(
                field: "accent",
                question: "¿Cuál es el color de acento de la app?",
                candidates: [(themeSource, accent.hex)] + disagreeing.map { ($0.source, $0.value.hex) }
            ))
        }

        if let asset = builder.asset(for: "background") {
            for mode in builder.modes {
                let themed = builder.themeBackground(mode)
                let backdrop = mode == .dark ? RGBA(0, 0, 0) : RGBA(1, 1, 1)
                let shipped = asset.value(mode).composited(over: backdrop)
                if ColorMath.distance(themed, shipped) > 0.02 {
                    out.append(Difference(
                        field: "background (\(mode.rawValue))",
                        question: "¿Cuál es el fondo de la app en modo \(mode == .dark ? "oscuro" : "claro")?",
                        candidates: [(themeSource, themed.hex), ("Assets.xcassets/\(asset.name) (\(mode.rawValue))", shipped.hex)]
                    ))
                }
            }
        }
        return out
    }

    static func replacing(_ json: JSONValue, key: String, with value: JSONValue) -> JSONValue {
        guard case .object(let pairs) = json else { return json }
        return .object(pairs.map { $0.0 == key ? ($0.0, value) : $0 })
    }

    static func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: - Write

    public enum WriteError: Error, CustomStringConvertible {
        case notReady
        public var description: String { "El paquete no está listo: hay diferencias abiertas, problemas bloqueantes o nada cambió." }
    }

    /// Writes the manifest and tokens and copies the icon masters. Captures, logo,
    /// icons map, screenshots and CHANGELOG are placed by their owners, not here.
    public static func write(_ plan: Plan) throws {
        guard plan.canWrite else { throw WriteError.notReady }
        let dir = plan.snapshot.appRoot.appendingPathComponent(RepoProbe.packageDir)
        let fm = FileManager.default
        try fm.createDirectory(at: dir.appendingPathComponent("assets/icon"), withIntermediateDirectories: true)
        try plan.manifest.serialized().write(to: dir.appendingPathComponent("brand-package.json"), atomically: true, encoding: .utf8)
        try plan.tokens.serialized().write(to: dir.appendingPathComponent("tokens.tokens.json"), atomically: true, encoding: .utf8)
        for (dest, source) in plan.copies {
            let target = dir.appendingPathComponent(dest)
            if target.standardizedFileURL == source.standardizedFileURL { continue }
            if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
            try fm.copyItem(at: source, to: target)
        }
    }
}
#endif
