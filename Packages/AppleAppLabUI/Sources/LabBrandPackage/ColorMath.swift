import Foundation

/// An sRGB color with straight alpha, components in 0…1.
public struct RGBA: Equatable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    /// `#rgb`-style 0–255 integers.
    public init(r255: Int, g255: Int, b255: Int, a: Double = 1) {
        self.init(Double(r255) / 255, Double(g255) / 255, Double(b255) / 255, a)
    }

    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        self.init(r255: (v >> 16) & 0xFF, g255: (v >> 8) & 0xFF, b255: v & 0xFF)
    }

    /// Lowercase `#rrggbb`. Alpha is dropped: callers composite first.
    public var hex: String {
        func c(_ x: Double) -> Int { Int((min(max(x, 0), 1) * 255).rounded()) }
        return String(format: "#%02x%02x%02x", c(r), c(g), c(b))
    }

    /// Source-over onto an opaque backdrop; the result is opaque.
    public func composited(over backdrop: RGBA) -> RGBA {
        RGBA(r * a + backdrop.r * (1 - a), g * a + backdrop.g * (1 - a), b * a + backdrop.b * (1 - a), 1)
    }

    var opaque: RGBA { RGBA(r, g, b, 1) }
}

// MARK: - OKLab / OKLCH (Björn Ottosson)

public struct OKLCH: Equatable, Sendable {
    public var l: Double   // 0…1
    public var c: Double
    public var h: Double   // degrees

    public var css: String {
        "oklch(\(ColorMath.trim(l * 100, 1))% \(ColorMath.trim(c, 3)) \(ColorMath.trim(h, 1)))"
    }
}

public enum ColorMath {
    static func toLinear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    static func toGamma(_ c: Double) -> Double {
        c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
    }

    public static func oklab(_ c: RGBA) -> (l: Double, a: Double, b: Double) {
        let r = toLinear(c.r), g = toLinear(c.g), b = toLinear(c.b)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)
    }

    /// Unclamped linear→gamma result; may fall outside 0…1 when out of gamut.
    static func rgb(fromOKLab L: Double, _ A: Double, _ B: Double) -> RGBA {
        let l = pow(L + 0.3963377774 * A + 0.2158037573 * B, 3)
        let m = pow(L - 0.1055613458 * A - 0.0638541728 * B, 3)
        let s = pow(L - 0.0894841775 * A - 1.2914855480 * B, 3)
        return RGBA(toGamma(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
                    toGamma(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
                    toGamma(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s))
    }

    public static func oklch(_ c: RGBA) -> OKLCH {
        let lab = oklab(c)
        let chroma = hypot(lab.a, lab.b)
        var hue = atan2(lab.b, lab.a) * 180 / .pi
        if hue < 0 { hue += 360 }
        return OKLCH(l: lab.l, c: chroma, h: chroma < 1e-4 ? 0 : hue)
    }

    public static func rgb(_ c: OKLCH) -> RGBA {
        let rad = c.h * .pi / 180
        return rgb(fromOKLab: c.l, c.c * cos(rad), c.c * sin(rad))
    }

    static func inGamut(_ c: RGBA) -> Bool {
        [c.r, c.g, c.b].allSatisfy { $0 >= -0.0005 && $0 <= 1.0005 }
    }

    /// Largest chroma ≤ `c.c` that stays inside sRGB at the same L and h.
    public static func clampedToSRGB(_ c: OKLCH) -> OKLCH {
        if inGamut(rgb(c)) { return c }
        var lo = 0.0, hi = c.c
        for _ in 0..<30 {
            let mid = (lo + hi) / 2
            if inGamut(rgb(OKLCH(l: c.l, c: mid, h: c.h))) { lo = mid } else { hi = mid }
        }
        return OKLCH(l: c.l, c: lo, h: c.h)
    }

    /// Perceptual distance in OKLab; 0.02 is "same color" for our purposes.
    public static func distance(_ x: RGBA, _ y: RGBA) -> Double {
        let a = oklab(x), b = oklab(y)
        return sqrt(pow(a.l - b.l, 2) + pow(a.a - b.a, 2) + pow(a.b - b.b, 2))
    }

    public static func hueDifference(_ x: Double, _ y: Double) -> Double {
        let d = abs(x - y).truncatingRemainder(dividingBy: 360)
        return d > 180 ? 360 - d : d
    }

    /// WCAG 2 contrast ratio of two opaque colors.
    public static func contrast(_ x: RGBA, _ y: RGBA) -> Double {
        func lum(_ c: RGBA) -> Double { 0.2126 * toLinear(c.r) + 0.7152 * toLinear(c.g) + 0.0722 * toLinear(c.b) }
        let l1 = lum(x), l2 = lum(y)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    static func trim(_ v: Double, _ places: Int) -> String {
        var s = String(format: "%.\(places)f", v)
        if s.contains(".") {
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
        }
        return s
    }
}

// MARK: - Brand ramp

/// The `color.brand.50…950` ramp built around the app accent. Lightness and the
/// chroma profile follow web-lab's reference ramp, so derived steps sit where Frost
/// expects them; the hue is the accent's.
public enum BrandRamp {
    public static let steps = ["50", "100", "200", "300", "400", "500", "600", "700", "800", "900", "950"]
    static let lightness: [Double] = [0.97, 0.93, 0.86, 0.76, 0.66, 0.56, 0.48, 0.40, 0.33, 0.27, 0.20]
    static let chromaProfile: [Double] = [0.02, 0.05, 0.09, 0.13, 0.17, 0.20, 0.19, 0.16, 0.12, 0.09, 0.06]

    public struct Step: Sendable {
        public let key: String
        public let value: String
        public let isSource: Bool
        public let rgb: RGBA
    }

    /// The step whose reference lightness is closest to the accent's.
    public static func sourceIndex(for accent: RGBA) -> Int {
        let l = ColorMath.oklch(accent).l
        return lightness.indices.min { abs(lightness[$0] - l) < abs(lightness[$1] - l) }!
    }

    public static func build(accent: RGBA) -> [Step] {
        let source = ColorMath.oklch(accent)
        let index = sourceIndex(for: accent)
        return steps.indices.map { i in
            if i == index {
                return Step(key: steps[i], value: accent.hex, isSource: true, rgb: accent.opaque)
            }
            let chroma = source.c * chromaProfile[i] / chromaProfile[index]
            let c = ColorMath.clampedToSRGB(OKLCH(l: lightness[i], c: chroma, h: source.h))
            return Step(key: steps[i], value: c.css, isSource: false, rgb: ColorMath.rgb(c))
        }
    }
}

// MARK: - Springs

/// SwiftUI `spring(response:dampingFraction:)` as a CSS `linear()` easing, sampled
/// from the damped oscillator the API describes, plus the time it takes to settle.
public enum SpringCurve {
    public static func settleTime(response: Double, damping: Double) -> Double {
        let w0 = 2 * Double.pi / response
        let zeta = min(max(damping, 0.05), 1)
        let factor = zeta < 1 ? 1 + zeta / sqrt(1 - zeta * zeta) : 1 + w0
        // envelope e^(-ζω₀t)·factor < 0.001
        return log(factor / 0.001) / (zeta * w0)
    }

    public static func position(_ t: Double, response: Double, damping: Double) -> Double {
        let w0 = 2 * Double.pi / response
        let zeta = min(max(damping, 0.05), 1)
        if zeta < 1 {
            let wd = w0 * sqrt(1 - zeta * zeta)
            return 1 - exp(-zeta * w0 * t) * (cos(wd * t) + (zeta * w0 / wd) * sin(wd * t))
        }
        return 1 - exp(-w0 * t) * (1 + w0 * t)
    }

    public static func cssLinear(response: Double, damping: Double, samples: Int = 24) -> String {
        let end = settleTime(response: response, damping: damping)
        let points = (0...samples).map { i -> String in
            i == samples ? "1" : ColorMath.trim(position(end * Double(i) / Double(samples), response: response, damping: damping), 3)
        }
        return "linear(\(points.joined(separator: ", ")))"
    }
}
