import Foundation
import SwiftData
import Observation

/// App-wide exchange-rate state. Wraps the `ExchangeRateService` actor (Banxico SIE),
/// the user's `Bmx-Token` (Keychain-only, C-12 — never `UserDefaults`/`@Model`/CloudKit),
/// and the persisted `ExchangeRateCache` row (TRD: the network fetch is independent of
/// CloudKit sync — the cache row itself syncs like any other model).
@MainActor
@Observable
public final class ExchangeRateStore {
    /// SECURITY_AUDIT.md M-01: the manual override feeds the same `ExchangeRateCache` row
    /// (and therefore the same future fallback) as the Banxico fetch — it must be validated
    /// with the same plausibility rule the network path already uses (C-12), not accepted
    /// silently just because the user typed it.
    public enum ManualOverrideError: Error, Equatable, Sendable {
        case outOfRange
    }

    public enum TokenTestResult: Sendable, Equatable {
        case valid
        case invalid
        case networkError
    }

    public private(set) var currentRate: Decimal?
    public private(set) var rateDate: Date?
    public private(set) var isUsingCache: Bool = false
    public private(set) var isUnavailable: Bool = false
    public private(set) var lastManualOverrideError: ManualOverrideError?
    /// C-12(d): the stored token was rejected by Banxico (400/401/403) on the last automatic
    /// fetch — the UI shows "tu token no es válido" without ever displaying the token itself.
    public private(set) var isTokenInvalid = false

    private let service = ExchangeRateService()

    public init() {}

    /// Never persisted outside Keychain — reading it does not touch SwiftData/UserDefaults.
    public var hasToken: Bool { KeychainStore.read() != nil }

    public func saveToken(_ token: String) {
        try? KeychainStore.save(token)
        isTokenInvalid = false
    }

    public func clearToken() {
        try? KeychainStore.delete()
    }

    /// The explicit "Probar token" button in Ajustes — verifies without ever saving,
    /// logging, or echoing the token back.
    public func testToken(_ token: String) async -> TokenTestResult {
        switch await service.testToken(token) {
        case .valid: .valid
        case .invalid: .invalid
        case .networkError: .networkError
        }
    }

    public func refresh(context: ModelContext) async {
        let cached = latestCache(context: context)
        let persisted = cached.map {
            ExchangeRateService.RateResult(rate: $0.rate, date: $0.date, fetchedFromAPI: $0.fetchedFromAPI)
        }
        let outcome = await service.refreshRate(token: KeychainStore.read(), persistedCache: persisted)

        switch outcome {
        case .success(let result):
            currentRate = result.rate
            rateDate = result.date
            isUsingCache = false
            isUnavailable = false
            isTokenInvalid = false
            persist(result, context: context)
        case .usedCache(let result):
            currentRate = result.rate
            rateDate = result.date
            isUsingCache = true
            isUnavailable = false
        case .invalidToken:
            isTokenInvalid = true
            if let cached {
                currentRate = cached.rate
                rateDate = cached.date
                isUsingCache = true
                isUnavailable = false
            } else {
                currentRate = nil
                rateDate = nil
                isUsingCache = false
                isUnavailable = true
            }
        case .unavailable:
            currentRate = nil
            rateDate = nil
            isUsingCache = false
            isUnavailable = true
        }
    }

    /// Applies a manual override the user typed in Ajustes: persists it as the cache row too,
    /// so it survives as the fallback the next time the API is unreachable. Rejects anything
    /// outside `ExchangeRateParser.plausibleRange` (1...100) instead of persisting it silently
    /// (M-01) — a typo like `16200` instead of `16.20` would otherwise become the fallback rate.
    @discardableResult
    public func applyManualOverride(_ rate: Decimal, context: ModelContext) -> Bool {
        guard ExchangeRateParser.plausibleRange.contains(rate) else {
            lastManualOverrideError = .outOfRange
            return false
        }
        lastManualOverrideError = nil
        let result = ExchangeRateService.RateResult(rate: rate, date: Date(), fetchedFromAPI: false)
        currentRate = result.rate
        rateDate = result.date
        isUsingCache = false
        isUnavailable = false
        persist(result, context: context)
        return true
    }

    private func latestCache(context: ModelContext) -> ExchangeRateCache? {
        let descriptor = FetchDescriptor<ExchangeRateCache>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return try? context.fetch(descriptor).first
    }

    private func persist(_ result: ExchangeRateService.RateResult, context: ModelContext) {
        if let existing = latestCache(context: context) {
            existing.date = result.date
            existing.rate = result.rate
            existing.fetchedFromAPI = result.fetchedFromAPI
        } else {
            context.insert(ExchangeRateCache(date: result.date, rate: result.rate, fetchedFromAPI: result.fetchedFromAPI))
        }
        try? context.save()
    }
}
