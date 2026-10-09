#if os(macOS)
import Foundation
import ImageIO
import AppleAppLabUI

/// Options the CLI passes; everything else is read from the app repo.
public struct ProbeOptions: Sendable {
    public var appRoot: URL
    public var themePath: String?
    public var platforms: [Platform]?
    public var primary: Platform?
    public var name: String?

    public init(appRoot: URL, themePath: String? = nil, platforms: [Platform]? = nil, primary: Platform? = nil, name: String? = nil) {
        self.appRoot = appRoot
        self.themePath = themePath
        self.platforms = platforms
        self.primary = primary
        self.name = name
    }
}

/// One color set from `Assets.xcassets`, resolved per mode.
public struct AssetColor: Sendable {
    public let name: String
    public let light: RGBA
    public let dark: RGBA
    public func value(_ mode: Mode) -> RGBA { mode == .light ? light : dark }
}

public struct KeyScreenSpec: Sendable {
    public let id: String
    public let platform: Platform
    public let view: String
    public let states: [String]
}

/// A finished 3D asset listed in `Docs/Design/3d-assets.json` (contract v1.1).
public struct ThreeDSpec: Sendable {
    public let id: String
    public let title: String
    public let use: [String]
}

public struct ImageInfo: Sendable {
    public let url: URL
    public let width: Int
    public let height: Int
    public let hasAlpha: Bool
}

/// A value found in a design doc or in code that should agree with the theme.
public struct SourceValue: Sendable {
    public let source: String
    public let value: RGBA
}

/// Everything the generator needs, read once from the app repo.
public struct RepoSnapshot: Sendable {
    public var appRoot: URL
    public var gitRoot: URL?
    /// App root relative to the git root ("" when they are the same).
    public var relRoot: String
    public var commit: String?
    public var remote: String?
    /// Uncommitted paths outside `brand-package/`.
    public var dirtyPaths: [String]

    public var name: String
    public var slug: String
    public var platforms: [Platform]
    public var primary: Platform?
    public var theme: LabTheme?
    public var themePath: String?
    public var intakePath: String?

    public var assetColors: [AssetColor]
    public var accentAsset: RGBA?
    public var designAccents: [SourceValue]
    public var codeAccents: [SourceValue]

    public var iconIOS: ImageInfo?
    public var iconMac: ImageInfo?
    public var hasIconComposerFile: Bool
    public var iconSystem: String

    public var logoSVG: String?
    public var logoOnDarkSVG: String?
    public var logoProblems: [String]
    public var hasIconsMap: Bool
    public var iconsMapValid: Bool
    public var designFile: JSONValue?

    public var keyScreensSpecPath: String?
    public var keyScreens: [KeyScreenSpec]
    public var keyScreensSpecError: String?
    public var screenFiles: [String]
    public var threeDSpecPath: String?
    public var threeDSpecs: [ThreeDSpec]
    public var threeDSpecError: String?
    /// Every file under `brand-package/assets/3d/`, relative to `brand-package/`.
    public var threeDFiles: [String]
    public var screenshotFiles: [String]

    public var problems: [String]
}

public enum RepoProbe {
    static let packageDir = "brand-package"
    static let skipDirs: Set<String> = [".git", ".build", "build", "DerivedData", "Packages", "Pods", "Carthage",
                                        "node_modules", ".appleapplab", ".claude", ".cursor", packageDir]

    public static func snapshot(_ options: ProbeOptions) -> RepoSnapshot {
        let root = options.appRoot.standardizedFileURL
        var problems: [String] = []

        // Git
        let top = Shell.run(["git", "rev-parse", "--show-toplevel"], cwd: root)
        let gitRoot = top.status == 0 ? URL(fileURLWithPath: top.out.trimmed).standardizedFileURL : nil
        var relRoot = ""
        if let gitRoot, root.path.hasPrefix(gitRoot.path), root.path != gitRoot.path {
            relRoot = String(root.path.dropFirst(gitRoot.path.count + 1))
        }
        let commit = gitRoot == nil ? nil : Shell.run(["git", "rev-parse", "HEAD"], cwd: root).out.trimmed.nilIfEmpty
        let remoteRaw = gitRoot == nil ? nil : Shell.run(["git", "remote", "get-url", "origin"], cwd: root).out.trimmed.nilIfEmpty
        let remote = remoteRaw.map(sanitizeRemote)
        if gitRoot == nil { problems.append("La app no está en un repo git: el paquete necesita `source.commit`.") }
        if gitRoot != nil && remote == nil { problems.append("El repo no tiene remoto `origin`: `source.repo` es obligatorio (una URL de git portátil).") }
        let dirty = gitRoot == nil ? [] : Shell.run(["git", "status", "--porcelain", "--", ".", ":(exclude)\(packageDir)"], cwd: root)
            .out.split(separator: "\n").map { String($0.dropFirst(3)) }

        // project.yml
        let projectYML = try? String(contentsOf: root.appendingPathComponent("project.yml"), encoding: .utf8)
        let ymlName = projectYML.flatMap { firstMatch(#"(?m)^name:\s*["']?([^"'\n]+?)["']?\s*$"#, in: $0) }

        // Theme
        var themePath = options.themePath
        if themePath == nil, let yml = projectYML {
            themePath = firstMatch(#"(?m)-\s*path:\s*["']?([^\s"']*Themes/[^\s"']+\.json)"#, in: yml)
        }
        var theme: LabTheme?
        if let themePath {
            let url = URL(fileURLWithPath: themePath, relativeTo: root).standardizedFileURL
            do {
                theme = try LabTheme.decode(Data(contentsOf: url))
            } catch {
                problems.append("No pude leer el tema `\(themePath)`: \(error.localizedDescription)")
            }
        } else {
            problems.append("No encontré el tema de la app: ni `--theme` ni una ruta `Themes/*.json` en `project.yml`.")
        }

        let name = options.name ?? ymlName ?? theme?.name ?? root.lastPathComponent
        let slug = kebab(name)

        // Platforms
        var platforms = options.platforms ?? []
        if platforms.isEmpty, let yml = projectYML {
            platforms = detectPlatforms(yml)
        }
        if platforms.isEmpty { problems.append("No pude deducir las plataformas: pasa `--platforms ios,macos`.") }
        var primary = options.primary
        if primary == nil, platforms.count == 1 { primary = platforms[0] }
        if primary == nil, platforms.count > 1 {
            problems.append("La app tiene varias plataformas (\(platforms.map(\.rawValue).joined(separator: ", "))): Jonny elige cuál llena `text`, `radius` y `spacing` con `--primary`.")
        }
        if let p = primary, !platforms.contains(p) {
            problems.append("`--primary \(p.rawValue)` no está entre las plataformas de la app.")
        }

        // Files in the app
        let files = walk(root)
        let swiftFiles = files.filter { $0.pathExtension == "swift" && !$0.path.contains("/Tests/") && !$0.lastPathComponent.hasSuffix("Tests.swift") }

        let intake = FileManager.default.fileExists(atPath: root.appendingPathComponent("app-web-intake.md").path) ? "app-web-intake.md" : nil

        // Assets.xcassets
        var assetColors: [AssetColor] = []
        var accentAsset: RGBA?
        var iconIOS: ImageInfo?
        var iconMac: ImageInfo?
        var hasIconComposer = false
        for dir in directories(root) {
            switch dir.pathExtension {
            case "colorset":
                guard let c = parseColorSet(dir) else { continue }
                if c.name == "AccentColor" { accentAsset = c.light } else { assetColors.append(c) }
            case "appiconset":
                let icons = parseAppIconSet(dir)
                iconIOS = iconIOS ?? icons.ios
                iconMac = iconMac ?? icons.mac
            case "icon":
                hasIconComposer = true
            default: break
            }
        }
        assetColors.sort { $0.name < $1.name }

        // Hand-exported masters already in the package win (Icon Composer, macOS-only apps).
        let iconDir = root.appendingPathComponent("\(packageDir)/assets/icon")
        if let manual = imageInfo(iconDir.appendingPathComponent("app-icon-ios-1024.png")), iconIOS == nil { iconIOS = manual }
        if let manual = imageInfo(iconDir.appendingPathComponent("app-icon-macos-1024.png")) { iconMac = manual }

        // Design docs and code that state an accent
        var designAccents: [SourceValue] = []
        for doc in designDocs(root) {
            guard let text = try? String(contentsOf: doc, encoding: .utf8) else { continue }
            for (i, line) in text.components(separatedBy: "\n").enumerated()
            where line.range(of: #"(?i)\b(accent|acento|tint|brand|marca|primary|primario)\b"#, options: .regularExpression) != nil {
                for hex in allMatches(#"#[0-9A-Fa-f]{6}\b"#, in: line) {
                    if let c = RGBA(hex: hex) { designAccents.append(SourceValue(source: "\(relative(doc, to: root)):\(i + 1)", value: c)) }
                }
            }
        }
        var codeAccents: [SourceValue] = []
        var sfCount = 0, customCount = 0
        for file in swiftFiles {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            sfCount += allMatches(#"(systemName:|systemImage:)"#, in: text).count
            customCount += allMatches(#"Image\(\s*"[^"]+""#, in: text).count
            for (i, line) in text.components(separatedBy: "\n").enumerated() where line.contains(".tint(") || line.contains(".accentColor(") {
                if let c = parseColorLiteral(line) {
                    codeAccents.append(SourceValue(source: "\(relative(file, to: root)):\(i + 1)", value: c))
                }
            }
        }
        let iconSystem = customCount > 0 && sfCount > 0 ? "mixed" : (customCount > 0 ? "custom" : "sf-symbols")

        // Logo, icons map, design file
        let logoDir = root.appendingPathComponent("\(packageDir)/assets/logo")
        var logoProblems: [String] = []
        let logo = FileManager.default.fileExists(atPath: logoDir.appendingPathComponent("logo.svg").path) ? "assets/logo/logo.svg" : nil
        let logoDark = FileManager.default.fileExists(atPath: logoDir.appendingPathComponent("logo-on-dark.svg").path) ? "assets/logo/logo-on-dark.svg" : nil
        if logo != nil, let svg = try? String(contentsOf: logoDir.appendingPathComponent("logo.svg"), encoding: .utf8) {
            if svg.contains("<image") { logoProblems.append("`logo.svg` incrusta una imagen raster: el contrato pide un logo vectorial.") }
            if !svg.contains("currentColor") && logoDark == nil {
                logoProblems.append("`logo.svg` no usa `currentColor` y no hay `logo-on-dark.svg`.")
            }
        }
        let mapURL = root.appendingPathComponent("\(packageDir)/icons.map.json")
        let hasMap = FileManager.default.fileExists(atPath: mapURL.path)
        let mapValid = hasMap && (try? JSONValue.parse(Data(contentsOf: mapURL))) != nil

        var designFile: JSONValue?
        if let pen = files.first(where: { $0.pathExtension == "pen" }) {
            designFile = obj(("tool", "pen"), ("path", .string(relative(pen, to: root))), ("access", "repo"))
        } else {
            for doc in designDocs(root, includeBrief: true) {
                if let text = try? String(contentsOf: doc, encoding: .utf8),
                   let url = firstMatch(#"(https://(?:www\.)?figma\.com/(?:design|file)/[A-Za-z0-9]+[^\s)?#\"']*)"#, in: text) {
                    designFile = obj(("tool", "figma"), ("url", .string(url)), ("access", "private"))
                    break
                }
            }
        }

        // Key screens
        var specPath: String?
        var specs: [KeyScreenSpec] = []
        var specError: String?
        for candidate in ["Docs/Design/key-screens.json", "key-screens.json"] {
            let url = root.appendingPathComponent(candidate)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            specPath = candidate
            do {
                let json = try JSONValue.parse(Data(contentsOf: url))
                for item in json["screens"]?.arrayValue ?? [] {
                    guard let id = item["id"]?.stringValue,
                          let platformRaw = item["platform"]?.stringValue, let platform = Platform(rawValue: platformRaw),
                          let view = item["view"]?.stringValue else {
                        specError = "Cada pantalla en `\(candidate)` necesita `id`, `platform` (ios, ipados, macos…) y `view`."
                        continue
                    }
                    let states = item["states"]?.arrayValue?.compactMap(\.stringValue) ?? ["default"]
                    specs.append(KeyScreenSpec(id: id, platform: platform, view: view, states: states.isEmpty ? ["default"] : states))
                }
            } catch {
                specError = "`\(candidate)` no es JSON válido: \(error.localizedDescription)"
            }
            break
        }
        var threeDPath: String?
        var threeDSpecs: [ThreeDSpec] = []
        var threeDError: String?
        for candidate in ["Docs/Design/3d-assets.json", "3d-assets.json"] {
            let url = root.appendingPathComponent(candidate)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            threeDPath = candidate
            do {
                let json = try JSONValue.parse(Data(contentsOf: url))
                for item in json["assets"]?.arrayValue ?? [] {
                    guard let id = item["id"]?.stringValue, let title = item["title"]?.stringValue else {
                        threeDError = "Cada asset en `\(candidate)` necesita `id` y `title`."
                        continue
                    }
                    threeDSpecs.append(ThreeDSpec(id: id, title: title, use: item["use"]?.arrayValue?.compactMap(\.stringValue) ?? []))
                }
            } catch {
                threeDError = "`\(candidate)` no es JSON válido: \(error.localizedDescription)"
            }
            break
        }
        let threeDFiles = listFiles(root.appendingPathComponent("\(packageDir)/assets/3d"), base: root.appendingPathComponent(packageDir), extensions: ["png", "webp", "mp4", "glb"])
        let screens = listFiles(root.appendingPathComponent("\(packageDir)/assets/screens"), base: root.appendingPathComponent(packageDir))
        let screenshots = listFiles(root.appendingPathComponent("\(packageDir)/assets/screenshots"), base: root.appendingPathComponent(packageDir))

        return RepoSnapshot(
            appRoot: root, gitRoot: gitRoot, relRoot: relRoot, commit: commit, remote: remote, dirtyPaths: dirty,
            name: name, slug: slug, platforms: platforms, primary: primary, theme: theme, themePath: themePath,
            intakePath: intake, assetColors: assetColors, accentAsset: accentAsset,
            designAccents: designAccents, codeAccents: codeAccents,
            iconIOS: iconIOS, iconMac: iconMac, hasIconComposerFile: hasIconComposer, iconSystem: iconSystem,
            logoSVG: logo, logoOnDarkSVG: logoDark, logoProblems: logoProblems,
            hasIconsMap: hasMap, iconsMapValid: mapValid, designFile: designFile,
            keyScreensSpecPath: specPath, keyScreens: specs, keyScreensSpecError: specError,
            screenFiles: screens, threeDSpecPath: threeDPath, threeDSpecs: threeDSpecs, threeDSpecError: threeDError,
            threeDFiles: threeDFiles, screenshotFiles: screenshots, problems: problems
        )
    }

    // MARK: - Helpers

    /// Drops credentials from an https remote; scp-style remotes are already portable.
    public static func sanitizeRemote(_ remote: String) -> String {
        guard var comps = URLComponents(string: remote), comps.scheme != nil else { return remote }
        comps.user = nil
        comps.password = nil
        comps.query = nil
        return comps.string ?? remote
    }

    public static func kebab(_ s: String) -> String {
        let folded = s.folding(options: .diacriticInsensitive, locale: .init(identifier: "en_US"))
        var out = ""
        var previousLower = false
        for ch in folded {
            if ch.isUppercase && previousLower { out.append("-") }
            if ch.isLetter || ch.isNumber {
                out.append(Character(ch.lowercased()))
                previousLower = ch.isLowercase || ch.isNumber
            } else {
                if !out.hasSuffix("-") { out.append("-") }
                previousLower = false
            }
        }
        return out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    static func detectPlatforms(_ yml: String) -> [Platform] {
        var found: [Platform] = []
        let lines = yml.components(separatedBy: "\n").filter { $0.contains("platform:") || $0.contains("supportedDestinations") || $0.contains("platforms:") }
        let map: [(String, Platform)] = [("iOS", .ios), ("macOS", .macos), ("watchOS", .watchos), ("visionOS", .visionos)]
        for line in lines {
            for (token, platform) in map where line.contains(token) && !found.contains(platform) {
                found.append(platform)
            }
        }
        return found
    }

    static func parseComponent(_ raw: String) -> Double {
        let s = raw.trimmingCharacters(in: .whitespaces)
        if s.lowercased().hasPrefix("0x"), let v = Int(s.dropFirst(2), radix: 16) { return Double(v) / 255 }
        if s.contains("."), let v = Double(s) { return v }
        if let v = Int(s) { return v > 1 ? Double(v) / 255 : Double(v) }
        return 0
    }

    static func parseColorSet(_ dir: URL) -> AssetColor? {
        guard let data = try? Data(contentsOf: dir.appendingPathComponent("Contents.json")),
              let json = try? JSONValue.parse(data) else { return nil }
        var any: RGBA?, light: RGBA?, dark: RGBA?
        for entry in json["colors"]?.arrayValue ?? [] {
            guard let comps = entry.value(at: "color.components") else { continue }
            func c(_ k: String) -> Double { comps[k]?.stringValue.map(parseComponent) ?? 0 }
            let color = RGBA(c("red"), c("green"), c("blue"), comps["alpha"]?.stringValue.map(parseComponent) ?? 1)
            let appearance = entry["appearances"]?.arrayValue?.first { $0["appearance"]?.stringValue == "luminosity" }?["value"]?.stringValue
            switch appearance {
            case "light": light = color
            case "dark": dark = color
            case nil: any = color
            default: break
            }
        }
        guard let base = any ?? light ?? dark else { return nil }
        return AssetColor(name: dir.deletingPathExtension().lastPathComponent, light: light ?? base, dark: dark ?? base)
    }

    static func parseAppIconSet(_ dir: URL) -> (ios: ImageInfo?, mac: ImageInfo?) {
        guard let data = try? Data(contentsOf: dir.appendingPathComponent("Contents.json")),
              let json = try? JSONValue.parse(data) else { return (nil, nil) }
        var ios: ImageInfo?, mac: ImageInfo?
        for image in json["images"]?.arrayValue ?? [] {
            guard let file = image["filename"]?.stringValue, let info = imageInfo(dir.appendingPathComponent(file)) else { continue }
            let idiom = image["idiom"]?.stringValue
            let size = image["size"]?.stringValue
            let scale = image["scale"]?.stringValue
            if size == "1024x1024", idiom == "universal" || idiom == "ios-marketing", image["platform"]?.stringValue != "watchos" {
                ios = ios ?? info
            } else if idiom == "mac", size == "512x512", scale == "2x" {
                mac = info
            }
        }
        return (ios, mac)
    }

    public static func imageInfo(_ url: URL) -> ImageInfo? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        let alpha = (props[kCGImagePropertyHasAlpha] as? Bool) ?? false
        return ImageInfo(url: url, width: w, height: h, hasAlpha: alpha)
    }

    /// `Color(red: 0.9, green: …)`, `Color(red: 240/255, …)` or `Color(hex: "#F04200")` on one line.
    static func parseColorLiteral(_ line: String) -> RGBA? {
        if let hex = firstMatch(#"Color\(\s*hex:\s*"(#?[0-9A-Fa-f]{6})""#, in: line) {
            return RGBA(hex: hex.hasPrefix("#") ? hex : "#" + hex)
        }
        let num = #"([0-9]*\.?[0-9]+)\s*(/\s*255(?:\.0)?)?"#
        let pattern = #"Color\(\s*red:\s*"# + num + #"\s*,\s*green:\s*"# + num + #"\s*,\s*blue:\s*"# + num
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else { return nil }
        func comp(_ value: Int, _ divisor: Int) -> Double {
            let v = Double(line[Range(m.range(at: value), in: line)!]) ?? 0
            return m.range(at: divisor).location != NSNotFound ? v / 255 : v
        }
        return RGBA(comp(1, 2), comp(3, 4), comp(5, 6))
    }

    static func designDocs(_ root: URL, includeBrief: Bool = false) -> [URL] {
        var out: [URL] = []
        for dir in [root.appendingPathComponent("Docs/Design"), root] {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
            for n in names.sorted() where (n.hasPrefix("DESIGN_") || (includeBrief && n == "STYLE_BRIEF.md")) && n.hasSuffix(".md") {
                out.append(dir.appendingPathComponent(n))
            }
        }
        return out
    }

    static func walk(_ root: URL) -> [URL] {
        var out: [URL] = []
        guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return out }
        for case let url as URL in e {
            if skipDirs.contains(url.lastPathComponent) || url.pathExtension == "xcodeproj" { e.skipDescendants(); continue }
            out.append(url)
        }
        return out
    }

    static func directories(_ root: URL) -> [URL] {
        walk(root).filter { ["colorset", "appiconset", "icon"].contains($0.pathExtension) }
    }

    static func listFiles(_ dir: URL, base: URL, extensions: Set<String> = ["png"]) -> [String] {
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return [] }
        var out: [String] = []
        for case let url as URL in e where extensions.contains(url.pathExtension.lowercased()) {
            out.append(relative(url, to: base))
        }
        return out.sorted()
    }

    static func relative(_ url: URL, to base: URL) -> String {
        let p = url.standardizedFileURL.path, b = base.standardizedFileURL.path
        return p.hasPrefix(b + "/") ? String(p.dropFirst(b.count + 1)) : url.lastPathComponent
    }

    static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        let r = m.numberOfRanges > 1 ? m.range(at: 1) : m.range
        return Range(r, in: text).map { String(text[$0]) }
    }

    static func allMatches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }
}

// MARK: - Shell

public enum Shell {
    public struct Result: Sendable {
        public let status: Int32
        public let out: String
        public let data: Data
    }

    @discardableResult
    public static func run(_ args: [String], cwd: URL? = nil) -> Result {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = args
        if let cwd { p.currentDirectoryURL = cwd }
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return Result(status: -1, out: "", data: Data()) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return Result(status: p.terminationStatus, out: String(decoding: data, as: UTF8.self), data: data)
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
#endif
