#if os(macOS)
import Foundation

public extension Plan {
    /// Machine-readable summary the `/app-brand-package` routine reads.
    var reportJSON: JSONValue {
        obj(
            ("ready", .bool(canWrite)),
            ("app", .string(snapshot.name)),
            ("previous_version", previousVersion.map { .string($0) } ?? .null),
            ("version", version.map { .string($0) } ?? .null),
            ("bump", .string(bump.rawValue)),
            ("reasons", .array(reasons.map { .string($0) })),
            ("differences", .array(differences.map { d in
                obj(("field", .string(d.field)), ("question", .string(d.question)),
                    ("candidates", .array(d.candidates.map { obj(("source", .string($0.source)), ("value", .string($0.value))) })))
            })),
            ("blocking", .array(blocking.map { .string($0) })),
            ("warnings", .array(warnings.map { .string($0) }))
        )
    }

    /// Plain-language summary for the terminal.
    var reportText: String {
        var lines: [String] = []
        lines.append("Paquete de marca · \(snapshot.name)")
        if let version {
            lines.append("Versión: \(previousVersion ?? "—") → \(version) (\(bump.rawValue))")
        } else if previousVersion != nil {
            lines.append("Versión: \(previousVersion!) — nada cambió en el diseño; no hay versión nueva.")
        }
        for r in reasons { lines.append("  · \(r)") }
        if !differences.isEmpty {
            lines.append("")
            lines.append("Diferencias para Yuno (\(differences.count)):")
            for d in differences {
                lines.append("  ? \(d.question)")
                for c in d.candidates { lines.append("      \(c.value)  ← \(c.source)") }
            }
        }
        if !blocking.isEmpty {
            lines.append("")
            lines.append("Bloquea la publicación:")
            for b in blocking { lines.append("  ✗ \(b)") }
        }
        if !warnings.isEmpty {
            lines.append("")
            lines.append("Avisos (se publica igual):")
            for w in warnings { lines.append("  · \(w)") }
        }
        lines.append("")
        lines.append(canWrite ? "Listo para `write`." : "No se publica todavía.")
        return lines.joined(separator: "\n")
    }
}
#endif
