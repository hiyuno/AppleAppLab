import Foundation

extension Decimal {
    /// "$1,240.50" / "-$320.00" style formatting used throughout the app. Always shows
    /// the sign explicitly for negative values (accessibility rule: never color-only).
    func currencyString(currency: Currency = .usd) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = currency == .usd ? "$" : "MX$"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: self as NSDecimalNumber) ?? "\(currency == .usd ? "$" : "MX$")\(self)"
    }

    var twoDecimalString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
    }
}
