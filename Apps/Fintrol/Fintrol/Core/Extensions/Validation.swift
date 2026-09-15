import Foundation

/// Shared bounds for user-entered financial figures — every capture form (Préstamos,
/// Recurrentes, Suscripciones, Servicios) disables "Guardar" outside these ranges. Keeps
/// `LoanEngine` (and any other Decimal-heavy calculation) from ever being fed a value large
/// enough to risk overflow (Bertrand's crash) in the first place — defense in depth on top
/// of `LoanEngine`'s own non-crashing fallback.
enum ValidationRange {
    /// Any captured amount (principal, recurring amount, subscription/service price).
    static let amount: ClosedRange<Decimal> = Decimal(0.01)...Decimal(1_000_000_000)
    /// APR as a fraction (0...1), i.e. 0%–100%.
    static let apr: ClosedRange<Decimal> = 0...1
    static let termMonths: ClosedRange<Int> = 1...600
    static let dayOfMonth: ClosedRange<Int> = 1...31
}
