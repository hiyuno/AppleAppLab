import Foundation

/// Actor-isolated network + in-memory cache for the daily USD→MXN rate, sourced from
/// Banxico SIE (serie `SF43718`). Fallback cascade (TRD): token+API success → in-memory
/// last-good → caller-supplied persisted cache (`ExchangeRateCache` row) → unavailable.
/// Never crashes, never logs the token/rate/payload (C-05/C-12), never uses `http://`
/// (C-03), never touches `URLSessionDelegate` server-trust evaluation (C-02) — plain
/// `URLSession.data(for:)` over ATS-default HTTPS. Throttled to at most one automatic
/// fetch per 24h (C-12) — `testToken` (the explicit "Probar token" action) bypasses that.
public actor ExchangeRateService {
    public struct RateResult: Sendable, Equatable {
        public let rate: Decimal
        public let date: Date
        public let fetchedFromAPI: Bool

        public init(rate: Decimal, date: Date, fetchedFromAPI: Bool) {
            self.rate = rate
            self.date = date
            self.fetchedFromAPI = fetchedFromAPI
        }
    }

    public enum FetchOutcome: Sendable, Equatable {
        case success(RateResult)
        case usedCache(RateResult)
        /// C-12(d): the token is missing/invalid (HTTP 400/401/403 with Banxico's error
        /// shape) — a distinct case from a generic network failure, so the UI can point the
        /// user at Ajustes without implying the network itself is down.
        case invalidToken
        case unavailable
    }

    public enum TokenTestOutcome: Sendable, Equatable {
        case valid
        case invalid
        case networkError
    }

    private static let endpoint = URL(string: "https://www.banxico.org.mx/SieAPIRest/service/v1/series/SF43718/datos/oportuno")!
    private static let throttleInterval: TimeInterval = 86_400 // 1 request/day, C-12

    private let session: URLSession
    private var inMemoryLastGood: RateResult?
    private var lastFetchAttempt: Date?

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// `token` is read from Keychain by the caller (`ExchangeRateStore`) — this actor never
    /// touches Keychain/SwiftData itself, only the network. `persistedCache` is the last row
    /// of `ExchangeRateCache`, used as the final fallback (e.g. cold launch, no in-memory value yet).
    public func refreshRate(token: String?, persistedCache: RateResult?) async -> FetchOutcome {
        guard let token, !token.isEmpty else {
            return fallback(persistedCache: persistedCache)
        }

        if let lastFetchAttempt, Date().timeIntervalSince(lastFetchAttempt) < Self.throttleInterval {
            return fallback(persistedCache: persistedCache)
        }

        do {
            let (data, response) = try await session.data(for: makeRequest(token: token))
            lastFetchAttempt = Date()

            guard let http = response as? HTTPURLResponse else {
                return fallback(persistedCache: persistedCache)
            }
            guard http.statusCode == 200 else {
                if ExchangeRateParser.isInvalidTokenError(status: http.statusCode, data: data) {
                    return .invalidToken
                }
                return fallback(persistedCache: persistedCache)
            }

            let rate = try ExchangeRateParser.parseUSDToMXNRate(from: data)
            let result = RateResult(rate: rate, date: Date(), fetchedFromAPI: true)
            inMemoryLastGood = result
            return .success(result)
        } catch {
            lastFetchAttempt = Date()
            return fallback(persistedCache: persistedCache)
        }
    }

    /// The explicit "Probar token" action in Ajustes — a deliberate, user-initiated check,
    /// so it bypasses the once-a-day throttle. Never returns or logs the token itself.
    public func testToken(_ token: String) async -> TokenTestOutcome {
        do {
            let (data, response) = try await session.data(for: makeRequest(token: token))
            guard let http = response as? HTTPURLResponse else { return .networkError }
            if http.statusCode == 200 { return .valid }
            if ExchangeRateParser.isInvalidTokenError(status: http.statusCode, data: data) { return .invalid }
            return .networkError
        } catch {
            return .networkError
        }
    }

    private func makeRequest(token: String) -> URLRequest {
        var request = URLRequest(url: Self.endpoint)
        request.setValue(token, forHTTPHeaderField: "Bmx-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func fallback(persistedCache: RateResult?) -> FetchOutcome {
        if let cached = inMemoryLastGood ?? persistedCache {
            return .usedCache(cached)
        }
        return .unavailable
    }
}
