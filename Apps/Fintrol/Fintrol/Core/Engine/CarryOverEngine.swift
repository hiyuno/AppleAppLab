import Foundation

/// Sobrante ("what's left"), totals, "Mandar" and forward carry-over propagation.
/// Pure, `Sendable`, no SwiftData — operates entirely on `LineSnapshot` arrays.
public enum CarryOverEngine {
    /// Only `isActive` lines count — swipe-leading on `LineItemRow` toggles a line inactive
    /// (user's change, replacing the old per-row toggles) to exclude it from every total,
    /// sobrante, "Mandar" and the carry-over chain, without deleting it.
    public static func total(for lines: [LineSnapshot], kind: LineKind, exchangeRate: Decimal) -> Decimal {
        lines
            .filter { $0.kind == kind && $0.isActive }
            .reduce(Decimal(0)) { $0 + CurrencyConversion.toUSD(amount: $1.amount, currency: $1.currency, rate: exchangeRate) }
    }

    /// TOTAL INCOME − TOTAL EXPENSES. Every line counts, regardless of `isPaid` —
    /// that switch is purely visual (PRD).
    public static func sobrante(for lines: [LineSnapshot], exchangeRate: Decimal) -> Decimal {
        total(for: lines, kind: .income, exchangeRate: exchangeRate) - total(for: lines, kind: .expense, exchangeRate: exchangeRate)
    }

    /// "Mandar": sum of EXPENSES captured in MXN, divided by the exchange rate.
    public static func mandar(for lines: [LineSnapshot], exchangeRate: Decimal) -> Decimal {
        guard exchangeRate > 0 else { return 0 }
        let mxnExpenses = lines
            .filter { $0.kind == .expense && $0.currency == .mxn && $0.isActive }
            .reduce(Decimal(0)) { $0 + $1.amount }
        return mxnExpenses / exchangeRate
    }

    /// The single source of truth for "Next Month": callers pass either the real lines of an
    /// already-materialized next period, or the in-memory projected lines (recurring +
    /// subscriptions + carry-over) of one that isn't materialized yet — either way the result
    /// is just its sobrante, computed with this same formula.
    public static func previewNextMonth(lines: [LineSnapshot], exchangeRate: Decimal) -> Decimal {
        sobrante(for: lines, exchangeRate: exchangeRate)
    }

    /// One materialized period in the forward chain after an edit, described by every line
    /// EXCEPT its `.carryOver` ("Latest Month") line, plus the carry-over amount it currently
    /// holds (so we can detect a fixed point).
    public struct ChainEntry: Sendable {
        public let coordinate: PeriodCoordinate
        public let nonCarryOverLines: [LineSnapshot]
        public let previousCarryOverReceived: Decimal

        public init(coordinate: PeriodCoordinate, nonCarryOverLines: [LineSnapshot], previousCarryOverReceived: Decimal) {
            self.coordinate = coordinate
            self.nonCarryOverLines = nonCarryOverLines
            self.previousCarryOverReceived = previousCarryOverReceived
        }
    }

    /// Incremental, fixed-point recompute of the carry-over chain after an edit to period N.
    ///
    /// - `startingSobrante`: the freshly recalculated sobrante of period N.
    /// - `materializedChain`: periods N+1, N+2, … already materialized, in order.
    ///
    /// For each period in order: its new carry-over is the running sobrante of the period
    /// before it. If that new carry-over equals what the period already had
    /// (`previousCarryOverReceived`), nothing downstream can have changed either — the
    /// propagation stops right there instead of touching the rest of the chain.
    public static func recomputeForward(
        materializedChain: [ChainEntry],
        startingSobrante: Decimal,
        exchangeRate: Decimal
    ) -> [PeriodCoordinate: Decimal] {
        var result: [PeriodCoordinate: Decimal] = [:]
        var runningSobrante = startingSobrante

        for entry in materializedChain {
            let newCarryOver = runningSobrante
            if newCarryOver == entry.previousCarryOverReceived {
                break
            }
            result[entry.coordinate] = newCarryOver
            let allLines = entry.nonCarryOverLines + [LineSnapshot(kind: .income, amount: newCarryOver, currency: .usd, origin: .carryOver)]
            runningSobrante = sobrante(for: allLines, exchangeRate: exchangeRate)
        }

        return result
    }
}
