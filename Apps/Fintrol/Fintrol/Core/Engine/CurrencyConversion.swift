import Foundation

/// Pure `Decimal` money conversion. Never `Double` anywhere in this chain (TRD, C-07).
public enum CurrencyConversion {
    /// Converts `amount` in `currency` to its USD equivalent using `rate` (USD→MXN,
    /// i.e. how many MXN one USD buys). MXN amounts divide by the rate; USD amounts
    /// pass through unchanged. A non-positive rate cannot divide safely and returns 0
    /// rather than trapping — callers should treat that as "conversion unavailable".
    public static func toUSD(amount: Decimal, currency: Currency, rate: Decimal) -> Decimal {
        switch currency {
        case .usd:
            return amount
        case .mxn:
            guard rate > 0 else { return 0 }
            return amount / rate
        }
    }
}
