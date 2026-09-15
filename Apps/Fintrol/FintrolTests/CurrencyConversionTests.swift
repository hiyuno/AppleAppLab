import Testing
import Foundation
@testable import Fintrol

@Suite("CurrencyConversion")
struct CurrencyConversionTests {
    @Test("USD passes through unchanged")
    func usdPassthrough() {
        let result = CurrencyConversion.toUSD(amount: 100, currency: .usd, rate: 18.42)
        #expect(result == 100)
    }

    @Test("MXN divides by the rate with exact Decimal precision")
    func mxnDivision() {
        let result = CurrencyConversion.toUSD(amount: Decimal(string: "842.30")!, currency: .mxn, rate: Decimal(string: "18.42")!)
        let expected = Decimal(string: "842.30")! / Decimal(string: "18.42")!
        #expect(result == expected)
    }

    @Test("A non-positive rate returns 0 instead of dividing by zero")
    func nonPositiveRateIsSafe() {
        #expect(CurrencyConversion.toUSD(amount: 100, currency: .mxn, rate: 0) == 0)
        #expect(CurrencyConversion.toUSD(amount: 100, currency: .mxn, rate: -5) == 0)
    }

    @Test("Decimal division stays exact for typical money values (no Double rounding)")
    func decimalPrecision() {
        let amount = Decimal(string: "10.00")!
        let rate = Decimal(string: "3.00")!
        let result = CurrencyConversion.toUSD(amount: amount, currency: .mxn, rate: rate)
        // 10 / 3 in pure Decimal, never touching Double.
        #expect(result == amount / rate)
    }
}
