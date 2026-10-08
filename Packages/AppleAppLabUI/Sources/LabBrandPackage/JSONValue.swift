import Foundation

/// JSON with insertion-ordered objects, so the package files read top-down the way
/// the contract describes them and regenerate byte-identical when nothing changed.
public indirect enum JSONValue: Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([(String, JSONValue)])

    // MARK: Access

    public subscript(key: String) -> JSONValue? {
        guard case .object(let pairs) = self else { return nil }
        return pairs.first { $0.0 == key }?.1
    }

    /// Dotted path lookup (`"typography.font_design"`).
    public func value(at path: String) -> JSONValue? {
        path.split(separator: ".").reduce(Optional(self)) { $0?[String($1)] }
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    // MARK: Parse

    public static func parse(_ data: Data) throws -> JSONValue {
        let any = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return JSONValue(any: any)
    }

    init(any: Any) {
        switch any {
        case let n as NSNumber where CFGetTypeID(n) == CFBooleanGetTypeID():
            self = .bool(n.boolValue)
        case let n as NSNumber:
            self = .number(n.doubleValue)
        case let s as String:
            self = .string(s)
        case let a as [Any]:
            self = .array(a.map(JSONValue.init(any:)))
        case let d as [String: Any]:
            self = .object(d.keys.sorted().map { ($0, JSONValue(any: d[$0]!)) })
        default:
            self = .null
        }
    }

    // MARK: Serialize

    public func serialized() -> String {
        var out = ""
        write(into: &out, indent: 0)
        return out + "\n"
    }

    private func write(into out: inout String, indent: Int) {
        let pad = String(repeating: "  ", count: indent)
        let inner = String(repeating: "  ", count: indent + 1)
        switch self {
        case .string(let s): out += Self.quote(s)
        case .number(let n): out += Self.format(n)
        case .bool(let b): out += b ? "true" : "false"
        case .null: out += "null"
        case .array(let items):
            if items.isEmpty { out += "[]"; return }
            if items.allSatisfy(\.isScalar) {
                out += "[" + items.map { $0.serializedInline() }.joined(separator: ", ") + "]"
                return
            }
            out += "[\n"
            for (i, item) in items.enumerated() {
                out += inner
                item.write(into: &out, indent: indent + 1)
                out += i < items.count - 1 ? ",\n" : "\n"
            }
            out += pad + "]"
        case .object(let pairs):
            if pairs.isEmpty { out += "{}"; return }
            out += "{\n"
            for (i, (key, value)) in pairs.enumerated() {
                out += inner + Self.quote(key) + ": "
                value.write(into: &out, indent: indent + 1)
                out += i < pairs.count - 1 ? ",\n" : "\n"
            }
            out += pad + "}"
        }
    }

    private var isScalar: Bool {
        switch self {
        case .array, .object: false
        default: true
        }
    }

    private func serializedInline() -> String {
        var out = ""
        write(into: &out, indent: 0)
        return out
    }

    static func format(_ n: Double) -> String {
        if n == n.rounded(), abs(n) < 1e15 { return String(Int(n)) }
        var s = String(format: "%.4f", n)
        while s.hasSuffix("0") { s.removeLast() }
        return s
    }

    static func quote(_ s: String) -> String {
        var out = "\""
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out + "\""
    }
}

extension JSONValue: Equatable {
    /// Objects compare as dictionaries: key order is presentation, not content.
    public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
        switch (lhs, rhs) {
        case (.string(let a), .string(let b)): a == b
        case (.number(let a), .number(let b)): abs(a - b) < 1e-9
        case (.bool(let a), .bool(let b)): a == b
        case (.null, .null): true
        case (.array(let a), .array(let b)): a == b
        case (.object(let a), .object(let b)):
            a.count == b.count && a.allSatisfy { pair in b.contains { $0.0 == pair.0 && $0.1 == pair.1 } }
        default: false
        }
    }
}

// MARK: - Builders

extension JSONValue: ExpressibleByStringLiteral, ExpressibleByBooleanLiteral, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(floatLiteral value: Double) { self = .number(value) }
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
}

/// `obj(("a", 1), ("b", "x"))` keeps the order written.
func obj(_ pairs: (String, JSONValue)...) -> JSONValue { .object(pairs) }
func obj(_ pairs: [(String, JSONValue)]) -> JSONValue { .object(pairs) }
