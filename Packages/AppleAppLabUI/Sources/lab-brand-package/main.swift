import Foundation
import LabBrandPackage

// lab-brand-package — produces an app's brand package for web-lab
// (web-lab docs/app-brand-package.md, contract v1). Run from the app repo:
//
//   swift run --package-path <AppleAppLabUI> lab-brand-package check [--app-root .] [--theme <json>]
//        [--platforms ios,macos] [--primary macos] [--name "App"] [--json]
//   swift run --package-path <AppleAppLabUI> lab-brand-package write  [same options]
//   swift run --package-path <AppleAppLabUI> lab-brand-package capture-mac --app "App" --out brand-package/assets/screens/<id>-<state>-<mode>@2x.png
//
// Exit codes: 0 ready/written · 2 differences or blocking problems · 3 nothing changed · 64 usage.

let usage = """
uso: lab-brand-package check|write [--app-root DIR] [--theme JSON] [--platforms ios,macos] [--primary ios|macos] [--name NAME] [--json]
     lab-brand-package capture-mac --app NAME --out FILE@2x.png
"""

let allArgs = Array(CommandLine.arguments.dropFirst())
guard let command = allArgs.first else {
    FileHandle.standardError.write(Data((usage + "\n").utf8)); exit(64)
}
let args = Array(allArgs.dropFirst())

func option(_ name: String) -> String? {
    let args = Array(CommandLine.arguments.dropFirst(2))
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}

func fail(_ message: String, _ code: Int32 = 64) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

switch command {
case "check", "write":
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let root = option("--app-root").map { URL(fileURLWithPath: $0, relativeTo: cwd) } ?? cwd
    var platforms: [Platform]?
    if let raw = option("--platforms") {
        platforms = raw.split(separator: ",").map {
            guard let p = Platform(rawValue: $0.trimmingCharacters(in: .whitespaces).lowercased()) else { fail("plataforma desconocida: \($0)") }
            return p
        }
    }
    var primary: Platform?
    if let raw = option("--primary") {
        guard let p = Platform(rawValue: raw.lowercased()) else { fail("plataforma desconocida: \(raw)") }
        primary = p
    }
    let options = ProbeOptions(appRoot: root, themePath: option("--theme"), platforms: platforms, primary: primary, name: option("--name"))
    let plan = MainActor.assumeIsolated { Generator.plan(options, requireClean: command == "write") }

    if args.contains("--json") {
        print(plan.reportJSON.serialized(), terminator: "")
    } else {
        print(plan.reportText)
    }

    if command == "write" {
        guard plan.canWrite else { exit(plan.version == nil && plan.blocking.isEmpty && plan.differences.isEmpty ? 3 : 2) }
        do {
            try Generator.write(plan)
            print("Escrito: brand-package/brand-package.json, tokens.tokens.json e íconos — versión \(plan.version!).")
        } catch {
            fail("No pude escribir el paquete: \(error)", 1)
        }
    } else {
        exit(plan.canWrite ? 0 : (plan.version == nil && plan.blocking.isEmpty && plan.differences.isEmpty ? 3 : 2))
    }

case "capture-mac":
    guard let app = option("--app"), let out = option("--out") else { fail(usage) }
    let outURL = URL(fileURLWithPath: out)
    let oneX = out.contains("@2x.") ? URL(fileURLWithPath: out.replacingOccurrences(of: "@2x.", with: "@1x.")) : nil
    do {
        try MacCapture.capture(app: app, to: outURL, alsoOneX: oneX)
        print("Captura: \(out)\(oneX.map { " + \($0.lastPathComponent)" } ?? "")")
    } catch {
        fail("\(error)", 1)
    }

default:
    fail(usage)
}
