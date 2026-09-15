import Testing
import Foundation
@testable import Fintrol

/// Stubs every request with a fixed status/body so the service's fallback cascade can be
/// exercised without hitting the real network.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var body = Data()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("ExchangeRateService — Banxico SIE fallback cascade (C-12)")
struct ExchangeRateServiceTests {
    private func stubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private let validBody = Data(#"{"bmx":{"series":[{"datos":[{"fecha":"15/09/2026","dato":"18.5"}]}]}}"#.utf8)

    @Test("No token at all falls back to cache without making a request")
    func noTokenFallsBackToCache() async {
        StubURLProtocol.statusCode = 200
        StubURLProtocol.body = validBody
        let service = ExchangeRateService(session: stubbedSession())
        let cached = ExchangeRateService.RateResult(rate: 17.0, date: .distantPast, fetchedFromAPI: false)

        let outcome = await service.refreshRate(token: nil, persistedCache: cached)
        guard case .usedCache(let result) = outcome else {
            Issue.record("expected .usedCache, got \(outcome)")
            return
        }
        #expect(result.rate == 17.0)
    }

    @Test("Successful fetch with a well-formed payload and a token returns .success")
    func successfulFetch() async {
        StubURLProtocol.statusCode = 200
        StubURLProtocol.body = validBody
        let service = ExchangeRateService(session: stubbedSession())

        let outcome = await service.refreshRate(token: "valid-token", persistedCache: nil)
        guard case .success(let result) = outcome else {
            Issue.record("expected .success, got \(outcome)")
            return
        }
        #expect(result.rate == 18.5)
        #expect(result.fetchedFromAPI)
    }

    @Test("HTTP 400 with Banxico's real invalid-token body returns .invalidToken, not a generic fallback")
    func invalidTokenIsDistinctFromGenericFailure() async {
        StubURLProtocol.statusCode = 400
        StubURLProtocol.body = Data(#"{"error":{"mensaje":"Token inválido"}}"#.utf8)
        let service = ExchangeRateService(session: stubbedSession())

        let outcome = await service.refreshRate(token: "bad-token", persistedCache: nil)
        #expect(outcome == .invalidToken)
    }

    @Test("Non-200 status without Banxico's error shape falls back to cache (generic failure)")
    func genericServerErrorFallsBackToCache() async {
        StubURLProtocol.statusCode = 500
        StubURLProtocol.body = Data()
        let service = ExchangeRateService(session: stubbedSession())
        let cached = ExchangeRateService.RateResult(rate: 17.9, date: .distantPast, fetchedFromAPI: false)

        let outcome = await service.refreshRate(token: "token", persistedCache: cached)
        guard case .usedCache(let result) = outcome else {
            Issue.record("expected .usedCache, got \(outcome)")
            return
        }
        #expect(result.rate == 17.9)
    }

    @Test("\"N/E\" (non-business day) falls back to cache instead of treating the day as 0")
    func nonBusinessDayFallsBackToCache() async {
        StubURLProtocol.statusCode = 200
        StubURLProtocol.body = Data(#"{"bmx":{"series":[{"datos":[{"fecha":"14/09/2026","dato":"N/E"}]}]}}"#.utf8)
        let service = ExchangeRateService(session: stubbedSession())
        let cached = ExchangeRateService.RateResult(rate: 19.0, date: .distantPast, fetchedFromAPI: true)

        let outcome = await service.refreshRate(token: "token", persistedCache: cached)
        guard case .usedCache(let result) = outcome else {
            Issue.record("expected .usedCache, got \(outcome)")
            return
        }
        #expect(result.rate == 19.0)
    }

    @Test("Malformed JSON falls back to the persisted cache instead of throwing out of the actor")
    func malformedJSONFallsBackToCache() async {
        StubURLProtocol.statusCode = 200
        StubURLProtocol.body = Data(#"{"bmx": not json"#.utf8)
        let service = ExchangeRateService(session: stubbedSession())
        let cached = ExchangeRateService.RateResult(rate: 19.0, date: .distantPast, fetchedFromAPI: true)

        let outcome = await service.refreshRate(token: "token", persistedCache: cached)
        guard case .usedCache(let result) = outcome else {
            Issue.record("expected .usedCache, got \(outcome)")
            return
        }
        #expect(result.rate == 19.0)
    }

    @Test("Out-of-range rate falls back to cache rather than being trusted")
    func outOfRangeRateFallsBackToCache() async {
        StubURLProtocol.statusCode = 200
        StubURLProtocol.body = Data(#"{"bmx":{"series":[{"datos":[{"fecha":"15/09/2026","dato":"999999"}]}]}}"#.utf8)
        let service = ExchangeRateService(session: stubbedSession())
        let cached = ExchangeRateService.RateResult(rate: 18.1, date: .distantPast, fetchedFromAPI: false)

        let outcome = await service.refreshRate(token: "token", persistedCache: cached)
        guard case .usedCache(let result) = outcome else {
            Issue.record("expected .usedCache, got \(outcome)")
            return
        }
        #expect(result.rate == 18.1)
    }

    @Test("Failure with no cache at all reports unavailable rather than crashing")
    func noCacheReportsUnavailable() async {
        StubURLProtocol.statusCode = 500
        StubURLProtocol.body = Data()
        let service = ExchangeRateService(session: stubbedSession())

        let outcome = await service.refreshRate(token: "token", persistedCache: nil)
        #expect(outcome == .unavailable)
    }

    @Test("A second automatic fetch within 24h is throttled and falls back to cache without a new request")
    func throttlesToOneRequestPerDay() async {
        StubURLProtocol.statusCode = 200
        StubURLProtocol.body = validBody
        let service = ExchangeRateService(session: stubbedSession())

        let first = await service.refreshRate(token: "token", persistedCache: nil)
        guard case .success = first else {
            Issue.record("expected first fetch to succeed, got \(first)")
            return
        }

        // Change the stub to a different value — if the throttle worked, this must NOT be seen.
        StubURLProtocol.body = Data(#"{"bmx":{"series":[{"datos":[{"fecha":"16/09/2026","dato":"99"}]}]}}"#.utf8)
        let second = await service.refreshRate(token: "token", persistedCache: nil)
        guard case .usedCache(let result) = second else {
            Issue.record("expected the throttled second call to fall back to the in-memory cache, got \(second)")
            return
        }
        #expect(result.rate == 18.5, "must still be the first fetch's rate, not the new stubbed 99")
    }

    @Test("testToken (\"Probar token\") bypasses the throttle and reports .valid")
    func testTokenBypassesThrottle() async {
        StubURLProtocol.statusCode = 200
        StubURLProtocol.body = validBody
        let service = ExchangeRateService(session: stubbedSession())

        _ = await service.refreshRate(token: "token", persistedCache: nil) // consumes today's budget
        let result = await service.testToken("token")
        #expect(result == .valid)
    }

    @Test("testToken reports .invalid for a bad token, without ever returning it")
    func testTokenReportsInvalid() async {
        StubURLProtocol.statusCode = 400
        StubURLProtocol.body = Data(#"{"error":{"mensaje":"Token inválido"}}"#.utf8)
        let service = ExchangeRateService(session: stubbedSession())

        let result = await service.testToken("bad-token")
        #expect(result == .invalid)
    }
}
