import SwiftUI

public enum ColorTokens {
    public static let accent = Color(red: 0x5E / 255, green: 0x5C / 255, blue: 0xE6 / 255)

    public static let accentSubtle = Color(
        light: Color(red: 0xDE / 255, green: 0xDC / 255, blue: 0xFC / 255),
        dark: Color(red: 0x16 / 255, green: 0x14 / 255, blue: 0x52 / 255)
    )

    public static let accentBorder = Color(
        light: Color(red: 0xA8 / 255, green: 0xA4 / 255, blue: 0xF5 / 255),
        dark: Color(red: 0x3B / 255, green: 0x37 / 255, blue: 0xA8 / 255)
    )

    public static let success = Color.green
    public static let error = Color.red
    public static let warning = Color.orange
    public static let disabled = Color.secondary.opacity(0.4)
}

extension Color {
    init(light: Color, dark: Color) {
        self = Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(isDark ? dark : light)
        })
    }
}
