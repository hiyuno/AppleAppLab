import SwiftUI

public extension View {
    /// Attaches the team's in-app dev tools to this view in Debug builds:
    /// a trailing inspector with the theme, per-component and library tabs,
    /// opened by shaking the device (iOS), pressing ⌥⌘D (macOS), or tapping
    /// the floating button. In Release this modifier compiles to nothing.
    ///
    /// Put it on the root view, after `.labTheme(store)`:
    /// ```swift
    /// RootView()
    ///     .labTheme(themeStore)
    ///     .labDevTools(themeStore)
    /// ```
    @ViewBuilder
    func labDevTools(_ store: LabThemeStore, showsButton: Bool = true) -> some View {
        #if DEBUG
        modifier(LabDevToolsModifier(store: store, showsButton: showsButton))
        #else
        self
        #endif
    }
}

#if DEBUG
private struct LabDevToolsModifier: ViewModifier {
    let store: LabThemeStore
    let showsButton: Bool
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .inspector(isPresented: $isPresented) {
                NavigationStack { LabDevToolsPanel() }
                    .environment(store)
                    .inspectorColumnWidth(min: 320, ideal: 360, max: 460)
            }
            .overlay(alignment: .bottomTrailing) {
                if showsButton {
                    Button { isPresented.toggle() } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.body.weight(.semibold))
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().strokeBorder(.tint.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                    .accessibilityLabel("Dev Tools")
                    .accessibilityHint("Abre el panel de tema y componentes")
                }
            }
            .background {
                // Hidden shortcut: ⌥⌘D on macOS / hardware keyboards.
                Button("Dev Tools") { isPresented.toggle() }
                    .keyboardShortcut("d", modifiers: [.command, .option])
                    .opacity(0)
                    .accessibilityHidden(true)
            }
            #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: .labDeviceDidShake)) { _ in
                isPresented.toggle()
            }
            #endif
    }
}

#if os(iOS)
extension Notification.Name {
    static let labDeviceDidShake = Notification.Name("AppleAppLabUI.deviceDidShake")
}

// UIKit routes shake gestures to the first responder chain and ends at the
// window; overriding here catches it app-wide without touching the host app.
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .labDeviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}
#endif
#endif
