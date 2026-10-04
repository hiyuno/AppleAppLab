import SwiftUI

/// A `Color` that round-trips through JSON as sRGB components, so themes can be
/// saved to `UserDefaults`, exported to `Themes/*.json`, and loaded back on any
/// platform. Keys (`red`, `green`, `blue`, `opacity`) match the theme files the
/// team already ships.
public struct CodableColor: Codable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var opacity: Double

    public init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    public init(_ color: Color) {
        let components = color.rgbaComponents
        red = components.r
        green = components.g
        blue = components.b
        opacity = components.a
    }

    public var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    /// `#RRGGBB` — what designers paste into Figma/Pen and what `app-web-intake.md` wants.
    public var hexString: String {
        String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }
}

extension Color {
    var rgbaComponents: (r: Double, g: Double, b: Double, a: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(AppKit)
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return (Double(r), Double(g), Double(b), Double(a))
    }
}
