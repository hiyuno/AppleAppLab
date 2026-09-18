import Foundation

/// Plain, `Sendable` snapshot of everything the Home screen's motivational message needs —
/// built by `PeriodCoordinator.homeInsightContext(...)` from live SwiftData, consumed here as
/// pure data so the rule tree stays testable without a `ModelContainer` (same separation as
/// every other `Core/Engine` type).
public struct HomeInsightContext: Sendable, Equatable {
    public let pendingCount: Int
    public let creditCardsDueCount: Int
    public let hasAnyDebt: Bool
    /// Whether this period has any non-credit-card expense line at all (paid or not) — used
    /// only to disambiguate rules #5/#6 below, which the plan's table gives literally
    /// identical conditions ("todo pagado excepto tarjetas" vs. "solo faltan tarjetas, nada
    /// más pendiente"). Woz's reading: #5 is "you HAD other payments and cleared them", #6 is
    /// "credit cards were the only expense this period to begin with" — both collapse to
    /// `pendingCount == 0 && creditCardsDueCount > 0` otherwise, which would make #6
    /// unreachable.
    public let hasOtherExpenseLines: Bool
    /// Name of a loan whose most recent real payment (`PeriodCoordinator.loanLastPaymentDate`)
    /// falls inside THIS period's date range and is now inactive — i.e. it was liquidated this
    /// same quincena, not merely at some point in the past.
    public let justPaidOffLoanName: String?
    /// 0–100, average of `paidToDate / principal` across active loans — same formula as
    /// `LoanRow.paidFraction` (LoansView.swift), not a second one.
    public let loanProgressPercent: Int
    /// Woz decision: the WORST (highest) utilization level among active cards with a balance,
    /// not an average — a single card near/over 30% is the actionable risk; averaging it
    /// together with healthy cards would hide exactly the thing this signal exists to surface.
    public let creditUtilizationLevel: CreditCardEngine.UtilizationLevel
    public let surplus: Decimal

    public init(
        pendingCount: Int,
        creditCardsDueCount: Int,
        hasAnyDebt: Bool,
        hasOtherExpenseLines: Bool,
        justPaidOffLoanName: String?,
        loanProgressPercent: Int,
        creditUtilizationLevel: CreditCardEngine.UtilizationLevel,
        surplus: Decimal
    ) {
        self.pendingCount = pendingCount
        self.creditCardsDueCount = creditCardsDueCount
        self.hasAnyDebt = hasAnyDebt
        self.hasOtherExpenseLines = hasOtherExpenseLines
        self.justPaidOffLoanName = justPaidOffLoanName
        self.loanProgressPercent = loanProgressPercent
        self.creditUtilizationLevel = creditUtilizationLevel
        self.surplus = surplus
    }
}

/// A message KEY + its interpolation parameters — never an assembled `String` (plan §2): the
/// UI layer (`HomeView`) turns this into an `AttributedString` via `String(localized:
/// defaultValue:)`, highlighting the numeric parameters inline, same "engine returns data, UI
/// owns presentation" split as the rest of `Core/Engine`.
public enum HomeInsightMessage: Sendable, Equatable {
    case noDebtCaughtUp
    case noDebtPending(count: Int)
    case loanJustPaidOff(name: String)
    case cardsHandledOthersPending(count: Int)
    case almostThereExceptCards(cardsDue: Int)
    case onlyCardsLeft(cardsDue: Int)
    case caughtUpGoodProgress(loanPct: Int)
    case caughtUpEarlyProgress(loanPct: Int)
    case pendingHealthyUtilization(count: Int, cardsDue: Int, loanPct: Int)
    case pendingHighUtilization(count: Int, cardsDue: Int)
    case tightPeriod(count: Int)
    case fallback
}

/// Pure rule tree behind Home's dynamic message (plan §2, 12-row priority table — most specific
/// wins, top to bottom). No SwiftData, no UI — `PeriodCoordinator.homeInsightContext` builds the
/// input, `HomeView` renders the output.
public enum HomeInsightEngine {
    public static func message(for context: HomeInsightContext) -> HomeInsightMessage {
        let pending = context.pendingCount
        let cardsDue = context.creditCardsDueCount
        let allCaughtUp = pending == 0 && cardsDue == 0

        // Rules #1–#2: no debt at all.
        if !context.hasAnyDebt {
            return allCaughtUp ? .noDebtCaughtUp : .noDebtPending(count: pending)
        }

        // Rule #3: a loan was liquidated THIS period — most specific debt-bearing state.
        if let loanName = context.justPaidOffLoanName {
            return .loanJustPaidOff(name: loanName)
        }

        // Rule #4: cards handled, something else still pending.
        if cardsDue == 0, pending > 0 {
            return .cardsHandledOthersPending(count: pending)
        }

        // Rules #5/#6: only credit cards remain pending — disambiguated by
        // `hasOtherExpenseLines` (see the doc comment on that property).
        if pending == 0, cardsDue > 0 {
            return context.hasOtherExpenseLines
                ? .almostThereExceptCards(cardsDue: cardsDue)
                : .onlyCardsLeft(cardsDue: cardsDue)
        }

        // Rules #7/#8: fully caught up, split by loan progress.
        if allCaughtUp {
            return context.loanProgressPercent >= 50
                ? .caughtUpGoodProgress(loanPct: context.loanProgressPercent)
                : .caughtUpEarlyProgress(loanPct: context.loanProgressPercent)
        }

        // Rules #9/#10: both other payments AND cards are pending — the only remaining branch
        // once #4 and #5/#6 (which require exactly one of the two at zero) didn't match, split
        // by utilization health.
        if pending > 0, cardsDue > 0 {
            if context.creditUtilizationLevel == .low {
                return .pendingHealthyUtilization(count: pending, cardsDue: cardsDue, loanPct: context.loanProgressPercent)
            }
            if context.creditUtilizationLevel == .high {
                return .pendingHighUtilization(count: pending, cardsDue: cardsDue)
            }
            // Medium utilization falls through — no dedicated copy in the plan's table for
            // this exact combination; rule #11/#12 below still apply.
        }

        // Rule #11: negative sobrante, supportive tone — only meaningful with something left
        // to clear (`pending > 0`), reached here only for the states rules #1–#10 didn't claim
        // (e.g. medium utilization with both other payments and cards pending).
        if context.surplus < 0, pending > 0 {
            return .tightPeriod(count: pending)
        }

        // Rule #12: fallback.
        return .fallback
    }
}
