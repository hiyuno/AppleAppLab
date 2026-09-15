import Testing
import Foundation
@testable import Fintrol

@Suite("ExchangeRateParser — Banxico SIE, defensive, fail-closed (C-12)")
struct ExchangeRateParserTests {
    @Test("Valid Banxico SIE payload parses to the exact Decimal literal")
    func validPayload() throws {
        let json = Data(#"""
        {"bmx":{"series":[{"idSerie":"SF43718","titulo":"Tipo de cambio","datos":[{"fecha":"15/09/2026","dato":"18.42"}]}]}}
        """#.utf8)
        let rate = try ExchangeRateParser.parseUSDToMXNRate(from: json)
        #expect(rate == Decimal(string: "18.42")!)
    }

    @Test("\"N/E\" (non-business day, no dato) is treated as data unavailable, never as 0")
    func dataUnavailable() {
        let json = Data(#"""
        {"bmx":{"series":[{"idSerie":"SF43718","titulo":"Tipo de cambio","datos":[{"fecha":"14/09/2026","dato":"N/E"}]}]}}
        """#.utf8)
        #expect(throws: ExchangeRateParser.ParseError.dataUnavailable) {
            try ExchangeRateParser.parseUSDToMXNRate(from: json)
        }
    }

    @Test("Truncated JSON throws instead of crashing")
    func truncatedJSON() {
        let json = Data(#"{"bmx":{"series":[{"datos":[{"fecha":"15/09/2026","dato":"18.4"#.utf8)
        #expect(throws: (any Error).self) {
            try ExchangeRateParser.parseUSDToMXNRate(from: json)
        }
    }

    @Test("Missing series/datos throws missingField")
    func missingField() {
        let json = Data(#"{"bmx":{"series":[{"idSerie":"SF43718","titulo":"x","datos":[]}]}}"#.utf8)
        #expect(throws: ExchangeRateParser.ParseError.missingField) {
            try ExchangeRateParser.parseUSDToMXNRate(from: json)
        }
    }

    @Test("dato as a non-numeric string throws instead of coercing")
    func nonNumericDato() {
        let json = Data(#"{"bmx":{"series":[{"datos":[{"fecha":"15/09/2026","dato":"eighteen"}]}]}}"#.utf8)
        #expect(throws: (any Error).self) {
            try ExchangeRateParser.parseUSDToMXNRate(from: json)
        }
    }

    @Test("Rate of 0 is rejected as implausible")
    func zeroRateRejected() {
        let json = Data(#"{"bmx":{"series":[{"datos":[{"fecha":"15/09/2026","dato":"0"}]}]}}"#.utf8)
        #expect(throws: ExchangeRateParser.ParseError.outOfRange) {
            try ExchangeRateParser.parseUSDToMXNRate(from: json)
        }
    }

    @Test("An absurdly large rate is rejected as implausible")
    func hugeRateRejected() {
        let json = Data(#"{"bmx":{"series":[{"datos":[{"fecha":"15/09/2026","dato":"1000000"}]}]}}"#.utf8)
        #expect(throws: ExchangeRateParser.ParseError.outOfRange) {
            try ExchangeRateParser.parseUSDToMXNRate(from: json)
        }
    }

    @Test("Completely non-JSON payload throws")
    func nonJSONPayload() {
        let data = Data("not json at all".utf8)
        #expect(throws: (any Error).self) {
            try ExchangeRateParser.parseUSDToMXNRate(from: data)
        }
    }

    @Test("Empty payload throws")
    func emptyPayload() {
        #expect(throws: (any Error).self) {
            try ExchangeRateParser.parseUSDToMXNRate(from: Data())
        }
    }

    @Test("A plausible rate at the edge of the accepted range parses")
    func edgeOfRangeAccepted() throws {
        let json = Data(#"{"bmx":{"series":[{"datos":[{"fecha":"15/09/2026","dato":"100"}]}]}}"#.utf8)
        let rate = try ExchangeRateParser.parseUSDToMXNRate(from: json)
        #expect(rate == 100)
    }

    // MARK: - Invalid-token detection (C-12d) — matches the real Banxico error body,
    // confirmed live against www.banxico.org.mx on 2026-09-15: missing/invalid token
    // returns HTTP 400 (not 401/403 as the SIE docs summary suggested), body:
    // {"error":{"url":"...","mensaje":"Token inválido","detalle":"..."}}.

    @Test("HTTP 400 with Banxico's real 'Token inválido' body is detected as an invalid-token error")
    func detectsRealBanxicoInvalidTokenBody() {
        let body = Data(#"""
        {"error":{"url":"https://www.banxico.org.mx/SieAPIRest/service/v1/token","mensaje":"Token inválido","detalle":"El token enviado no es válido, favor de verificar. Para obtener un token consultar la url adjunta."}}
        """#.utf8)
        #expect(ExchangeRateParser.isInvalidTokenError(status: 400, data: body))
    }

    @Test("HTTP 401/403 with an error.mensaje body are also treated as invalid-token")
    func detects401And403() {
        let body = Data(#"{"error":{"mensaje":"Unauthorized"}}"#.utf8)
        #expect(ExchangeRateParser.isInvalidTokenError(status: 401, data: body))
        #expect(ExchangeRateParser.isInvalidTokenError(status: 403, data: body))
    }

    @Test("A 500 with the same body shape is NOT treated as invalid-token (only 400/401/403 qualify)")
    func doesNotTreat500AsInvalidToken() {
        let body = Data(#"{"error":{"mensaje":"Internal Server Error"}}"#.utf8)
        #expect(!ExchangeRateParser.isInvalidTokenError(status: 500, data: body))
    }

    @Test("HTTP 400 without Banxico's error shape is not treated as invalid-token")
    func doesNotTreatUnrelated400AsInvalidToken() {
        let body = Data(#"{"somethingElse": true}"#.utf8)
        #expect(!ExchangeRateParser.isInvalidTokenError(status: 400, data: body))
    }
}
