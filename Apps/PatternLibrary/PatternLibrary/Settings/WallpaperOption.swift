import AppKit
import AppleAppLabUI

// `WallpaperOption` itself lives in AppleAppLabUI; only the image lookup is
// app-specific because the JPGs ship in this app's bundle.
extension WallpaperOption {
    var image: NSImage? {
        guard !fileName.isEmpty,
              let url = Bundle.main.url(forResource: fileName, withExtension: "jpg") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
