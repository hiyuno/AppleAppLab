import SwiftUI
import AppKit

@main
struct PatternLibraryApp: App {
    @State private var appSettings = AppSettings()
    @State private var themeStore = ThemeStore()

    private static let minWindowWidth: CGFloat = 900
    private static let minWindowHeight: CGFloat = 600

    private var screenSize: CGSize {
        NSScreen.main?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
    }

    /// Ideal size is 60% of the screen, but never smaller than the layout's real minimum
    /// and never larger than the screen itself — otherwise panels get pushed off-screen.
    private var windowSize: CGSize {
        let screen = screenSize
        return CGSize(
            width: min(max(screen.width * 0.6, Self.minWindowWidth), screen.width),
            height: min(max(screen.height * 0.6, Self.minWindowHeight), screen.height)
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appSettings)
                .environment(themeStore)
                .preferredColorScheme(appSettings.appearanceMode.colorScheme)
                .frame(
                    minWidth: min(Self.minWindowWidth, screenSize.width),
                    idealWidth: windowSize.width,
                    maxWidth: screenSize.width,
                    minHeight: min(Self.minWindowHeight, screenSize.height),
                    idealHeight: windowSize.height,
                    maxHeight: screenSize.height
                )
        }
        .windowResizability(.contentSize)
    }
}
