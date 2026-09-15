import Foundation

/// Defensive, fail-closed parser for Banxico SIE (serie `SF43718`, FIX USD/MXN).
/// Confirmed live against `www.banxico.org.mx` on 2026-09-15 (see PROJECT_LEARNINGS.md):
/// a missing/invalid token returns **HTTP 400** (not 401/403 as originally assumed in
/// SECURITY.md/TRD) with body `{"error":{"mensaje":"Token inválido", ...}}` —
/// `isInvalidTokenError` treats 400/401/403 carrying that shape as the token-error case.
///
/// `dato` arrives as a JSON **string** (Banxico quotes every value, including "N/E" for a
/// non-business-day/missing reading) — decoding it as `String` never touches `Double`;
/// `Decimal(string:)` is the only numeric conversion in the whole path. Satisfies C-07/C-12.
public enum ExchangeRateParser {
    public enum ParseError: Error, Equatable, Sendable {
        case invalidResponse
        case missingField
        case outOfRange
        /// Banxico's own "no dato" marker for non-business days — absence of data,
        /// never coerced to 0.
        case dataUnavailable
    }

    /// Historically plausible USD→MXN range — rejects an obviously corrupt/malicious
    /// payload (e.g. 0 or 1,000,000) even if it is otherwise well-formed JSON.
    static let plausibleRange: ClosedRange<Decimal> = 1...100

    private struct BanxicoResponse: Decodable {
        let bmx: Series
        struct Series: Decodable { let series: [SeriesItem] }
        struct SeriesItem: Decodable { let datos: [Dato] }
        struct Dato: Decodable { let fecha: String; let dato: String }
    }

    public static func parseUSDToMXNRate(from data: Data) throws -> Decimal {
        guard let response = try? JSONDecoder().decode(BanxicoResponse.self, from: data),
              let dato = response.bmx.series.first?.datos.first else {
            throw ParseError.missingField
        }
        guard dato.dato != "N/E" else {
            throw ParseError.dataUnavailable
        }
        guard let rate = Decimal(string: dato.dato, locale: Locale(identifier: "en_US_POSIX")) else {
            throw ParseError.missingField
        }
        guard plausibleRange.contains(rate) else {
            throw ParseError.outOfRange
        }
        return rate
    }

    /// C-12(d): Banxico's real observed behavior for a missing/invalid `Bmx-Token` is
    /// HTTP 400 (the SIE docs suggest 401/403; live testing on 2026-09-15 found 400) with
    /// `{"error": {"mensaje": "..."}}`. Any of 400/401/403 carrying that shape counts as an
    /// invalid-token response, distinct from a generic network/server failure.
    public static func isInvalidTokenError(status: Int, data: Data) -> Bool {
        guard [400, 401, 403].contains(status) else { return false }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any] else { return false }
        return error["mensaje"] != nil
    }
}
