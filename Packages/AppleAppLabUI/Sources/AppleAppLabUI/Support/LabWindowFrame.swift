import SwiftUI

public struct LabWindowFrame<Content: View>: View {
    let backgroundColor: Color
    let cornerStyle: CornerStyle
    let cornerRadius: CGFloat
    let material: WindowMaterial
    let titleBarStyle: WindowTitleBarStyle
    let elevation: ElevationLevel
    let borderWidth: CGFloat
    let blurIntensity: Double
    let transparency: Double
    let content: Content

    public init(
        backgroundColor: Color,
        cornerStyle: CornerStyle,
        cornerRadius: CGFloat = 14,
        material: WindowMaterial = .solid,
        titleBarStyle: WindowTitleBarStyle = .full,
        elevation: ElevationLevel = .elevated,
        borderWidth: CGFloat = 1.0,
        blurIntensity: Double = 0.5,
        transparency: Double = 0.5,
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.cornerStyle = cornerStyle
        self.cornerRadius = cornerRadius
        self.material = material
        self.titleBarStyle = titleBarStyle
        self.elevation = elevation
        self.borderWidth = borderWidth
        self.blurIntensity = blurIntensity
        self.transparency = transparency
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            titleBar
            ZStack {
                contentBackground
                content
                    .padding(32)
            }
        }
        .clipShape(LabShape(radius: cornerRadius, style: cornerStyle))
        .overlay(
            LabShape(radius: cornerRadius, style: cornerStyle)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: borderWidth)
        )
        .labShadow(elevation)
    }

    @ViewBuilder
    private var contentBackground: some View {
        switch material {
        case .solid:
            backgroundColor
        case .frost:
            if transparency >= 0.999 {
                Color.clear
            } else {
                // Material never gets an external .opacity() — SwiftUI's backdrop blur
                // renders unreliably (or not at all) once you fade the material itself.
                // Keep it at full strength; transparency only fades the color tint on top.
                ZStack {
                    Rectangle().fill(blurMaterial)
                    backgroundColor.opacity((1 - transparency) * 0.6)
                }
            }
        case .liquidGlass:
            // Real Liquid Glass (.glassEffect) needs the macOS 26 SDK; this approximates
            // the look (lighter blur + specular highlight) until that SDK is available.
            if transparency >= 0.999 {
                Color.clear
            } else {
                ZStack {
                    Rectangle().fill(blurMaterial)
                    backgroundColor.opacity((1 - transparency) * 0.35)
                    LinearGradient(
                        colors: [.white.opacity(0.08 + 0.2 * blurIntensity), .white.opacity(0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .opacity(1 - transparency)
                }
            }
        }
    }

    /// SwiftUI's Material only ships 5 discrete levels (no continuous blur radius API),
    /// so a 0...1 slider is approximated by stepping through them.
    private var blurMaterial: Material {
        switch blurIntensity {
        case ..<0.2: .ultraThinMaterial
        case ..<0.4: .thinMaterial
        case ..<0.65: .regularMaterial
        case ..<0.85: .thickMaterial
        default: .ultraThickMaterial
        }
    }

    @ViewBuilder
    private var titleBar: some View {
        switch titleBarStyle {
        case .full:
            HStack(spacing: 8) {
                trafficLight(Color(red: 1, green: 0.373, blue: 0.333))
                trafficLight(Color(red: 1, green: 0.741, blue: 0.180))
                trafficLight(Color(red: 0.157, green: 0.788, blue: 0.251))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .accessibilityHidden(true)
        case .compact:
            Color.clear
                .frame(height: 28)
                .background(.regularMaterial)
                .accessibilityHidden(true)
        case .none:
            EmptyView()
        }
    }

    private func trafficLight(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
    }
}

#Preview {
    HStack(spacing: 24) {
        ForEach(WindowMaterial.allCases) { material in
            LabWindowFrame(
                backgroundColor: Color(nsColor: .windowBackgroundColor),
                cornerStyle: .squircle,
                material: material
            ) {
                Text(material.label)
            }
            .frame(width: 260, height: 180)
        }
    }
    .padding(40)
    .background(
        LinearGradient(colors: [.green, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
    )
}
