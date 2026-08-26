import AppKit

struct WallpaperOption: Identifiable, Hashable, Codable {
    let id: String
    let displayName: String
    let fileName: String

    static let none = WallpaperOption(id: "none", displayName: "None", fileName: "")

    static let all: [WallpaperOption] = [
        .none,
        WallpaperOption(id: "wallpaper-07", displayName: "Wallpaper 07", fileName: "wallpaper-07"),
        WallpaperOption(id: "wallpaper-10", displayName: "Wallpaper 10", fileName: "wallpaper-10"),
        WallpaperOption(id: "wallpaper-11", displayName: "Wallpaper 11", fileName: "wallpaper-11"),
        WallpaperOption(id: "wallpaper-30", displayName: "Wallpaper 30", fileName: "wallpaper-30")
    ]

    var image: NSImage? {
        guard !fileName.isEmpty,
              let url = Bundle.main.url(forResource: fileName, withExtension: "jpg") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
