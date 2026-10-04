import SwiftUI
import AppleAppLabUI

struct ThemeSwitcherBar: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(LabThemeStore.self) private var themeStore

    @State private var showingSaveAlert = false
    @State private var newThemeName = ""

    private var activeThemeName: String {
        themeStore.saved.first(where: { $0.id == themeStore.activeSavedID })?.name ?? "No Theme"
    }

    var body: some View {
        HStack(spacing: 0) {
            Menu {
                if !themeStore.saved.isEmpty {
                    ForEach(themeStore.saved) { theme in
                        Button {
                            themeStore.apply(theme, to: appSettings)
                        } label: {
                            if themeStore.activeSavedID == theme.id {
                                Label(theme.name, systemImage: "checkmark")
                            } else {
                                Text(theme.name)
                            }
                        }
                    }
                    Divider()
                }
                Button {
                    showingSaveAlert = true
                } label: {
                    Label("Save Current as New Theme…", systemImage: "plus")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "paintpalette.fill")
                        .foregroundStyle(appSettings.accentColor)
                    Text(activeThemeName)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)

            Divider()
                .frame(height: 16)
                .padding(.horizontal, 4)

            Button {
                saveActiveTheme()
            } label: {
                Image(systemName: "tray.and.arrow.down.fill")
            }
            .buttonStyle(.borderless)
            .disabled(themeStore.activeSavedID == nil)
            .help("Update the active theme with the current settings")
            .accessibilityLabel("Save current settings to active theme")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .alert("New Theme", isPresented: $showingSaveAlert) {
            TextField("Theme name", text: $newThemeName)
            Button("Cancel", role: .cancel) { newThemeName = "" }
            Button("Save") {
                let name = newThemeName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                themeStore.save(name: name, from: appSettings)
                newThemeName = ""
            }
        }
    }

    private func saveActiveTheme() {
        guard let id = themeStore.activeSavedID,
              let theme = themeStore.saved.first(where: { $0.id == id }) else {
            return
        }
        themeStore.update(theme, from: appSettings)
    }
}

#Preview {
    ThemeSwitcherBar()
        .environment(AppSettings())
        .environment(LabThemeStore(storageKey: LabThemeStore.patternLibraryStorageKey))
        .frame(width: 220)
}
