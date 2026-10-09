#if os(macOS)
import Foundation

/// Semver for the package (contract §9), computed against the version committed at HEAD.
///
/// - MAJOR: accent hue, font design, corner style, logo or icon; an app mode removed;
///   a token removed or renamed.
/// - MINOR: any other design change; tokens, screens or screenshots added or changed.
/// - PATCH: metadata only.
public enum Versioning {
    public struct Result: Sendable {
        public let previous: String?
        public let bump: Bump
        public let reasons: [String]
    }

    /// Manifest fields that change on every run and never make a version by themselves.
    static let volatile: Set<String> = ["package_version", "generated_at", "source.commit"]
    static let majorFields: Set<String> = ["typography.font_design", "shape.corner_style", "assets.logo"]
    static let minorFields: Set<String> = ["typography.font_weight", "materials.app", "materials.surfaces", "motion.speed_multiplier",
                                           "icons.app_system", "icons.map", "ui.key_screens", "assets.screenshots", "assets.icon",
                                           "primary_platform", "appearance.app_modes", "assets.three_d"]

    public static func next(_ previous: String?, _ bump: Bump) -> String {
        guard let previous else { return "1.0.0" }
        let parts = previous.split(separator: ".").map { Int($0) ?? 0 } + [0, 0, 0]
        switch bump {
        case .major: return "\(parts[0] + 1).0.0"
        case .minor: return "\(parts[0]).\(parts[1] + 1).0"
        case .patch, .none: return "\(parts[0]).\(parts[1]).\(parts[2] + 1)"
        }
    }

    static func show(_ path: String, in snap: RepoSnapshot) -> Data? {
        guard snap.gitRoot != nil else { return nil }
        let rel = snap.relRoot.isEmpty ? path : "\(snap.relRoot)/\(path)"
        let r = Shell.run(["git", "show", "HEAD:\(rel)"], cwd: snap.gitRoot)
        return r.status == 0 ? r.data : nil
    }

    /// Blob ids at HEAD for everything under `brand-package/assets`, keyed relative to `brand-package/`.
    static func committedAssets(_ snap: RepoSnapshot) -> [String: String] {
        guard let gitRoot = snap.gitRoot else { return [:] }
        let prefix = (snap.relRoot.isEmpty ? "" : snap.relRoot + "/") + "brand-package/"
        var out: [String: String] = [:]
        for line in Shell.run(["git", "ls-tree", "-r", "HEAD", "--", prefix + "assets"], cwd: gitRoot).out.split(separator: "\n") {
            let cols = line.split(separator: "\t", maxSplits: 1)
            guard cols.count == 2 else { continue }
            let sha = cols[0].split(separator: " ").last.map(String.init) ?? ""
            out[String(cols[1].dropFirst(prefix.count))] = sha
        }
        return out
    }

    static func blob(_ url: URL) -> String? {
        let r = Shell.run(["git", "hash-object", url.path])
        return r.status == 0 ? r.out.trimmed : nil
    }

    public static func compare(snapshot snap: RepoSnapshot, manifest: JSONValue, tokens: JSONValue, copies: [(dest: String, source: URL)]) -> Result {
        guard let oldManifestData = show("brand-package/brand-package.json", in: snap),
              let oldManifest = try? JSONValue.parse(oldManifestData) else {
            return Result(previous: nil, bump: .major, reasons: ["Primer paquete."])
        }
        let previous = oldManifest["package_version"]?.stringValue ?? "0.0.0"
        var bump = Bump.none
        var reasons: [String] = []
        func raise(_ b: Bump, _ why: String) {
            bump = max(bump, b)
            reasons.append("\(b.rawValue.uppercased()): \(why)")
        }

        // Manifest
        let oldFlat = flatten(oldManifest), newFlat = flatten(manifest)
        for key in Set(oldFlat.keys).union(newFlat.keys).sorted() where !volatile.contains(key) {
            guard oldFlat[key] != newFlat[key] else { continue }
            let group = majorFields.first { key.hasPrefix($0) } ?? minorFields.first { key.hasPrefix($0) }
            if key.hasPrefix("appearance.app_modes"),
               let old = oldManifest.value(at: "appearance.app_modes")?.arrayValue,
               let new = manifest.value(at: "appearance.app_modes")?.arrayValue,
               old.contains(where: { !new.contains($0) }) {
                raise(.major, "se quitó un modo de apariencia")
            } else if let group, majorFields.contains(group) {
                raise(.major, "cambió `\(key)`")
            } else if group != nil {
                raise(.minor, "cambió `\(key)`")
            } else {
                raise(.patch, "cambió `\(key)`")
            }
        }

        // Tokens
        if let oldTokensData = show("brand-package/tokens.tokens.json", in: snap), let oldTokens = try? JSONValue.parse(oldTokensData) {
            let old = tokenValues(oldTokens), new = tokenValues(tokens)
            let removed = Set(old.keys).subtracting(new.keys)
            if !removed.isEmpty { raise(.major, "se quitaron tokens (\(removed.sorted().prefix(3).joined(separator: ", ")))") }
            let added = Set(new.keys).subtracting(old.keys)
            if !added.isEmpty { raise(.minor, "tokens nuevos (\(added.sorted().prefix(3).joined(separator: ", ")))") }
            if let oldHue = sourceHue(oldTokens), let newHue = sourceHue(tokens), ColorMath.hueDifference(oldHue, newHue) > 3 {
                raise(.major, "cambió el matiz del acento")
            }
            let changed = Set(old.keys).intersection(new.keys).filter { old[$0] != new[$0] }
            if !changed.isEmpty { raise(.minor, "cambiaron \(changed.count) tokens (\(changed.sorted().prefix(3).joined(separator: ", ")))") }
            // Materials, per-component values and app modes live in the app metadata, not in token values.
            for key in ["materials", "patterns", "app_modes", "primary_platform"] {
                let a = oldTokens.value(at: "$extensions.appleapplab.\(key)"), b = tokens.value(at: "$extensions.appleapplab.\(key)")
                if a != b { raise(.minor, "cambió `\(key)` del app") }
            }
        } else {
            raise(.minor, "no había tokens en el commit anterior")
        }

        // Assets: icon and logo are identity; screens and screenshots are design.
        let committed = committedAssets(snap)
        var planned: [String: String] = [:]
        for (dest, source) in copies { planned[dest] = blob(source) }
        let packageDir = snap.appRoot.appendingPathComponent("brand-package")
        for rel in snap.screenFiles + snap.screenshotFiles + snap.threeDFiles + [snap.logoSVG, snap.logoOnDarkSVG].compactMap({ $0 }) {
            planned[rel] = blob(packageDir.appendingPathComponent(rel))
        }
        for path in Set(committed.keys).union(planned.keys).sorted() where committed[path] != planned[path] {
            if path.hasPrefix("assets/icon/") || path.hasPrefix("assets/logo/") {
                raise(.major, "cambió `\(path)`")
            } else if planned[path] == nil, path.hasPrefix("assets/3d/") {
                raise(.major, "se quitó el asset 3D `\(path)`")
            } else if planned[path] == nil {
                raise(.minor, "se quitó `\(path)`")
            } else {
                raise(.minor, committed[path] == nil ? "nuevo `\(path)`" : "cambió `\(path)`")
            }
        }
        return Result(previous: previous, bump: bump, reasons: reasons)
    }

    /// `a.b.c` → scalar, arrays kept whole.
    static func flatten(_ json: JSONValue, prefix: String = "") -> [String: JSONValue] {
        guard case .object(let pairs) = json else { return [prefix: json] }
        var out: [String: JSONValue] = [:]
        for (k, v) in pairs {
            let key = prefix.isEmpty ? k : "\(prefix).\(k)"
            if case .object = v { out.merge(flatten(v, prefix: key)) { $1 } } else { out[key] = v }
        }
        return out
    }

    /// token path → its value and dark override; descriptions and app metadata ignored.
    static func tokenValues(_ json: JSONValue, path: String = "") -> [String: JSONValue] {
        guard case .object(let pairs) = json else { return [:] }
        if let value = json["$value"] {
            return [path: obj(("v", value), ("d", json.value(at: "$extensions.web-lab.dark") ?? .null))]
        }
        var out: [String: JSONValue] = [:]
        for (k, v) in pairs where !k.hasPrefix("$") {
            out.merge(tokenValues(v, path: path.isEmpty ? k : "\(path).\(k)")) { $1 }
        }
        return out
    }

    static func sourceHue(_ tokens: JSONValue) -> Double? {
        guard case .object(let steps)? = tokens.value(at: "color.brand") else { return nil }
        for (_, step) in steps where step.value(at: "$extensions.appleapplab.source") == .bool(true) {
            if let hex = step["$value"]?.stringValue, let c = RGBA(hex: hex) { return ColorMath.oklch(c).h }
        }
        return nil
    }
}
#endif
