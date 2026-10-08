import Foundation
import SwiftUI
import Testing
@testable import AppleAppLabUI
@testable import LabBrandPackage

@Suite("Color math")
struct ColorMathTests {
    @Test("Hex → OKLCH → sRGB round-trips")
    func roundTrip() {
        for hex in ["#f04200", "#5e5ce6", "#acdd01", "#323232", "#ffffff", "#000000"] {
            let c = RGBA(hex: hex)!
            #expect(ColorMath.rgb(ColorMath.oklch(c)).hex == hex)
        }
    }

    @Test("WCAG contrast of black on white is 21")
    func contrast() {
        #expect(abs(ColorMath.contrast(RGBA(0, 0, 0), RGBA(1, 1, 1)) - 21) < 0.01)
    }

    @Test("Ramp keeps the accent as its only source step, every step inside sRGB")
    func ramp() {
        let accent = RGBA(hex: "#f04200")!
        let ramp = BrandRamp.build(accent: accent)
        #expect(ramp.map(\.key) == BrandRamp.steps)
        #expect(ramp.filter(\.isSource).map(\.value) == ["#f04200"])
        for step in ramp where !step.isSource {
            #expect(step.value.hasPrefix("oklch("))
            #expect(ColorMath.inGamut(step.rgb))
            #expect(ColorMath.hueDifference(ColorMath.oklch(step.rgb).h, ColorMath.oklch(accent).h) < 2)
        }
    }

    @Test("Spring curve starts at 0, ends at 1, overshoots like a 0.7 damping spring")
    func spring() {
        let css = SpringCurve.cssLinear(response: 0.3, damping: 0.7)
        #expect(css.hasPrefix("linear(0, "))
        #expect(css.hasSuffix(", 1)"))
        let peak = (0...100).map { SpringCurve.position(Double($0) / 100 * 0.6, response: 0.3, damping: 0.7) }.max()!
        #expect(peak > 1 && peak < 1.1)
    }
}

@Suite("Tokens")
@MainActor
struct TokenTests {
    func tokens(_ mode: AppearanceMode, platform: Platform = .macos, assets: [AssetColor] = []) -> JSONValue {
        let theme = LabTheme(name: "Demo", accentColor: Color(red: 0.94, green: 0.26, blue: 0), appearanceMode: mode)
        return TokenBuilder(theme: theme, platform: platform, assetColors: assets, patterns: ResolvedPattern.all(for: theme)).build()
    }

    @Test("Dark-only app: dark in the override, the same value as placeholder, mode_missing light")
    func darkOnly() {
        let t = tokens(.dark)
        let bg = t.value(at: "semantic.color.background")!
        #expect(bg["$value"] == .string("{color.app.background-dark}"))
        #expect(bg.value(at: "$extensions.web-lab.dark") == .string("{color.app.background-dark}"))
        #expect(t.value(at: "$extensions.appleapplab.mode_missing") == .string("light"))
        #expect(t.value(at: "color.app.background-light") == nil)
    }

    @Test("Light-only app: real $value, no dark override, mode_missing dark")
    func lightOnly() {
        let t = tokens(.light)
        #expect(t.value(at: "semantic.color.foreground.$value") == .string("{color.app.foreground-light}"))
        #expect(t.value(at: "semantic.color.foreground.$extensions") == nil)
        #expect(t.value(at: "$extensions.appleapplab.mode_missing") == .string("dark"))
    }

    @Test("App with both modes: light $value, dark override, no mode_missing")
    func bothModes() {
        let t = tokens(.system)
        #expect(t.value(at: "semantic.color.card.$value") == .string("{color.app.card-light}"))
        #expect(t.value(at: "semantic.color.card.$extensions.web-lab.dark") == .string("{color.app.card-dark}"))
        #expect(t.value(at: "$extensions.appleapplab.mode_missing") == nil)
    }

    @Test("Contract shape: twelve semantic colors, required groups, no breakpoint, converter-safe values")
    func shape() {
        let t = tokens(.system)
        guard case .object(let semantic)? = t.value(at: "semantic.color") else { Issue.record("no semantic.color"); return }
        let names = Set(semantic.map(\.0).filter { !$0.hasPrefix("$") })
        #expect(names == ["background", "foreground", "muted", "muted-foreground", "card", "border", "accent",
                          "accent-foreground", "danger", "success", "warning", "ring"])
        for group in ["color", "spacing", "text", "font", "radius", "shadow", "ease", "duration", "component"] {
            #expect(t[group] != nil, "missing \(group)")
        }
        #expect(t["breakpoint"] == nil)
        #expect(t.value(at: "component.corner-shape.$value") == .string("squircle"))
        let text = t.serialized()
        #expect(text.range(of: #"#[0-9a-fA-F]{8}\b"#, options: .regularExpression) == nil)
        #expect(!text.contains("display-p3"))
        #expect(!Versioning.tokenValues(t).keys.contains { $0.split(separator: ".").contains { $0.contains(" ") } })
    }

    @Test("A color asset that plays a role wins over the system color")
    func assetRole() {
        let t = tokens(.dark, assets: [AssetColor(name: "TextSecondary", light: RGBA(0, 0, 0), dark: RGBA(hex: "#aaaaaa")!)])
        #expect(t.value(at: "color.app.muted-foreground-dark.$value") == .string("#aaaaaa"))
        #expect(t.value(at: "color.app.muted-foreground-dark.$extensions.appleapplab.asset") == .string("TextSecondary"))
    }

    @Test("Sharp corners draw every radius square")
    func sharp() {
        let theme = LabTheme(name: "Sharp", cornerStyle: .sharp)
        let t = TokenBuilder(theme: theme, platform: .ios, assetColors: [], patterns: ResolvedPattern.all(for: theme)).build()
        #expect(t.value(at: "radius.lg.$value") == .string("0px"))
        #expect(t.value(at: "component.corner-shape.$value") == .string("sharp"))
    }

    @Test("Ease and duration tokens mirror MotionTokens")
    func motionPinned() {
        #expect(MotionTokens.entrance == .easeOut(duration: 0.2))
        #expect(MotionTokens.exit == .easeIn(duration: 0.15))
        #expect(MotionTokens.selectionChange == .easeOut(duration: 0.15))
        #expect(MotionTokens.pressResponse == .spring(response: 0.3, dampingFraction: 0.7))
    }
}

@Suite("Repo helpers")
struct RepoHelperTests {
    @Test("Remotes lose their credentials")
    func remote() {
        #expect(RepoProbe.sanitizeRemote("https://user:tok@github.com/o/r.git") == "https://github.com/o/r.git")
        #expect(RepoProbe.sanitizeRemote("git@github.com:o/r.git") == "git@github.com:o/r.git")
    }

    @Test("Slugs are kebab-case")
    func kebab() {
        #expect(RepoProbe.kebab("Demo App") == "demo-app")
        #expect(RepoProbe.kebab("Botones y controles") == "botones-y-controles")
        #expect(RepoProbe.kebab("Formularios/inputs") == "formularios-inputs")
        #expect(RepoProbe.kebab("AppBackgroundSecondary") == "app-background-secondary")
    }

    @Test("Color literals in code are read")
    func literals() {
        #expect(RepoProbe.parseColorLiteral(".tint(Color(red: 240/255, green: 66/255, blue: 0))")?.hex == "#f04200")
        #expect(RepoProbe.parseColorLiteral(".tint(Color(hex: \"#F04200\"))")?.hex == "#f04200")
    }

    @Test("Asset components accept floats, hex and 8-bit")
    func components() {
        #expect(RepoProbe.parseComponent("0xF0") == 240.0 / 255)
        #expect(RepoProbe.parseComponent("0.500") == 0.5)
        #expect(RepoProbe.parseComponent("128") == 128.0 / 255)
    }

    @Test("Semver steps")
    func semver() {
        #expect(Versioning.next(nil, .major) == "1.0.0")
        #expect(Versioning.next("1.2.3", .major) == "2.0.0")
        #expect(Versioning.next("1.2.3", .minor) == "1.3.0")
        #expect(Versioning.next("1.2.3", .patch) == "1.2.4")
    }

    @Test("Seed-data switch reads the launch argument")
    func seed() {
        #expect(LabSeedData.launchArgument == "-LabSeedData")
        #expect(LabSeedData.isEnabled == ProcessInfo.processInfo.arguments.contains("-LabSeedData"))
        #expect(LabSeedData.screen(in: ["app", "-LabSeedData", "-LabScreen", "home"]) == "home")
        #expect(LabSeedData.screen(in: ["app", "-LabScreen", "home"]) == nil)
        #expect(LabSeedData.screen(in: ["app", "-LabSeedData", "-LabScreen"]) == nil)
    }
}
