#if os(macOS)
import Foundation
import CoreGraphics

/// Captures the front window of a running Mac app without its shadow, the way the
/// contract's key screens need it (no device frame). Requires Screen Recording
/// permission for the terminal that runs it.
public enum MacCapture {
    public enum CaptureError: Error, CustomStringConvertible {
        case windowNotFound(String)
        case captureFailed
        public var description: String {
            switch self {
            case .windowNotFound(let app): "No encontré una ventana visible de \(app). ¿Está abierta y en pantalla? ¿La terminal tiene permiso de Grabación de pantalla?"
            case .captureFailed: "screencapture falló."
            }
        }
    }

    /// The largest on-screen, normal-level window owned by `app`.
    public static func windowID(app: String) -> CGWindowID? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        let candidates = list.filter {
            ($0[kCGWindowOwnerName as String] as? String) == app && ($0[kCGWindowLayer as String] as? Int) == 0
        }
        return candidates.max { area($0) < area($1) }?[kCGWindowNumber as String] as? CGWindowID
    }

    static func area(_ info: [String: Any]) -> Double {
        guard let b = info[kCGWindowBounds as String] as? [String: Double] else { return 0 }
        return (b["Width"] ?? 0) * (b["Height"] ?? 0)
    }

    /// Writes `<out>` at the display's native scale and, when `alsoOneX` is set, a
    /// half-size `@1x` sibling for the `@2x` file.
    public static func capture(app: String, to out: URL, alsoOneX: URL?) throws {
        guard let id = windowID(app: app) else { throw CaptureError.windowNotFound(app) }
        try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
        let r = Shell.run(["screencapture", "-x", "-o", "-l", String(id), out.path])
        guard r.status == 0, FileManager.default.fileExists(atPath: out.path) else { throw CaptureError.captureFailed }
        if let oneX = alsoOneX, let info = RepoProbe.imageInfo(out) {
            try? FileManager.default.removeItem(at: oneX)
            try FileManager.default.copyItem(at: out, to: oneX)
            Shell.run(["sips", "--resampleWidth", String(info.width / 2), oneX.path])
        }
    }
}
#endif
