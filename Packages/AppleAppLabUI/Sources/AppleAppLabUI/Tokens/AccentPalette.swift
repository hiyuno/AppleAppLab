import SwiftUI

public struct AccentSwatch: Identifiable {
    public let id = UUID()
    public let label: String
    public let color: Color
}

public struct AccentPalette {
    public let tone50: Color
    public let tone100: Color
    public let tone200: Color
    public let tone300: Color
    public let tone400: Color
    public let tone500: Color
    public let tone600: Color
    public let tone700: Color
    public let tone800: Color
    public let tone900: Color

    public let foregroundOnAccent: Color

    public var accent: Color { tone500 }
    public var accentSubtle: Color { tone100 }
    public var accentBorder: Color { tone300 }
    public var accentForeground: Color { tone800 }
    public var accentPressed: Color { tone600 }
    public var accentDisabled: Color { tone200 }

    public var swatches: [AccentSwatch] {
        [
            AccentSwatch(label: "50", color: tone50),
            AccentSwatch(label: "100", color: tone100),
            AccentSwatch(label: "200", color: tone200),
            AccentSwatch(label: "300", color: tone300),
            AccentSwatch(label: "400", color: tone400),
            AccentSwatch(label: "500", color: tone500),
            AccentSwatch(label: "600", color: tone600),
            AccentSwatch(label: "700", color: tone700),
            AccentSwatch(label: "800", color: tone800),
            AccentSwatch(label: "900", color: tone900)
        ]
    }

    public init(base: Color) {
        let hsl = base.hslComponents
        let rgb500 = base.rgbComponents

        func tone(light: Double, dark: Double) -> Color {
            Color(
                light: Color(hue: hsl.h, saturation: hsl.s, lightness: light),
                dark: Color(hue: hsl.h, saturation: hsl.s, lightness: dark)
            )
        }

        tone50 = tone(light: 0.95, dark: 0.10)
        tone100 = tone(light: 0.88, dark: 0.15)
        tone200 = tone(light: 0.78, dark: 0.22)
        tone300 = tone(light: 0.65, dark: 0.32)
        tone400 = tone(light: 0.55, dark: 0.45)
        tone500 = Color(hue: hsl.h, saturation: hsl.s, lightness: hsl.l)
        tone600 = tone(light: 0.45, dark: 0.60)
        tone700 = tone(light: 0.35, dark: 0.72)
        tone800 = tone(light: 0.25, dark: 0.82)
        tone900 = tone(light: 0.15, dark: 0.92)

        let baseLuminance = relativeLuminance(rgb500)
        let whiteContrast = contrastRatio(baseLuminance, 1.0)
        let blackContrast = contrastRatio(baseLuminance, 0.0)
        foregroundOnAccent = whiteContrast >= blackContrast ? .white : Color(white: 0.08)
    }
}

// MARK: - HSL conversions

extension Color {
    init(hue: Double, saturation: Double, lightness: Double) {
        guard saturation > 0 else {
            self = Color(white: lightness)
            return
        }
        func hue2rgb(_ p: Double, _ q: Double, _ t: Double) -> Double {
            var t = t
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1 / 6 { return p + (q - p) * 6 * t }
            if t < 1 / 2 { return q }
            if t < 2 / 3 { return p + (q - p) * (2 / 3 - t) * 6 }
            return p
        }
        let q = lightness < 0.5 ? lightness * (1 + saturation) : lightness + saturation - lightness * saturation
        let p = 2 * lightness - q
        let r = hue2rgb(p, q, hue + 1 / 3)
        let g = hue2rgb(p, q, hue)
        let b = hue2rgb(p, q, hue - 1 / 3)
        self = Color(red: r, green: g, blue: b)
    }

    var rgbComponents: (r: Double, g: Double, b: Double) {
        let nsColor = (NSColor(self).usingColorSpace(.deviceRGB)) ?? NSColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    var hslComponents: (h: Double, s: Double, l: Double) {
        let rgb = rgbComponents
        let maxV = max(rgb.r, rgb.g, rgb.b)
        let minV = min(rgb.r, rgb.g, rgb.b)
        let l = (maxV + minV) / 2

        guard maxV != minV else { return (0, 0, l) }

        let d = maxV - minV
        let s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV)

        var h: Double
        switch maxV {
        case rgb.r: h = (rgb.g - rgb.b) / d + (rgb.g < rgb.b ? 6 : 0)
        case rgb.g: h = (rgb.b - rgb.r) / d + 2
        default: h = (rgb.r - rgb.g) / d + 4
        }
        h /= 6

        return (h, s, l)
    }
}

// MARK: - WCAG contrast

private func relativeLuminance(_ rgb: (r: Double, g: Double, b: Double)) -> Double {
    func channel(_ c: Double) -> Double {
        c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * channel(rgb.r) + 0.7152 * channel(rgb.g) + 0.0722 * channel(rgb.b)
}

private func contrastRatio(_ l1: Double, _ l2: Double) -> Double {
    let lighter = max(l1, l2)
    let darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)
}
