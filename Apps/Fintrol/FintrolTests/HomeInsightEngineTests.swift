import Testing
import Foundation
@testable import Fintrol

/// Plan `glimmering-swinging-bumblebee.md` §2 — one test per row of the 12-row priority table,
/// pure (no SwiftData; `HomeInsightContext` is a plain struct).
@Suite("HomeInsightEngine — 12-rule priority tree")
struct HomeInsightEngineTests {
    private func context(
        pendingCount: Int = 0,
        creditCardsDueCount: Int = 0,
        hasAnyDebt: Bool = false,
        hasOtherExpenseLines: Bool = false,
        justPaidOffLoanName: String? = nil,
        loanProgressPercent: Int = 0,
        creditUtilizationLevel: CreditCardEngine.UtilizationLevel = .low,
        surplus: Decimal = 100
    ) -> HomeInsightContext {
        HomeInsightContext(
            pendingCount: pendingCount,
            creditCardsDueCount: creditCardsDueCount,
            hasAnyDebt: hasAnyDebt,
            hasOtherExpenseLines: hasOtherExpenseLines,
            justPaidOffLoanName: justPaidOffLoanName,
            loanProgressPercent: loanProgressPercent,
            creditUtilizationLevel: creditUtilizationLevel,
            surplus: surplus
        )
    }

    @Test("Rule #1: no debt, nothing pending")
    func rule1NoDebtCaughtUp() {
        let result = HomeInsightEngine.message(for: context(pendingCount: 0, hasAnyDebt: false))
        #expect(result == .noDebtCaughtUp)
    }

    @Test("Rule #2: no debt, some payments pending")
    func rule2NoDebtPending() {
        let result = HomeInsightEngine.message(for: context(pendingCount: 3, hasAnyDebt: false))
        #expect(result == .noDebtPending(count: 3))
    }

    @Test("Rule #3: a loan was just paid off this period — wins over every other debt state")
    func rule3LoanJustPaidOff() {
        let result = HomeInsightEngine.message(for: context(
            pendingCount: 2, creditCardsDueCount: 1, hasAnyDebt: true,
            justPaidOffLoanName: "Ada", loanProgressPercent: 80, creditUtilizationLevel: .high, surplus: -50
        ))
        #expect(result == .loanJustPaidOff(name: "Ada"))
    }

    @Test("Rule #4: cards handled, other payments still pending")
    func rule4CardsHandledOthersPending() {
        let result = HomeInsightEngine.message(for: context(
            pendingCount: 2, creditCardsDueCount: 0, hasAnyDebt: true
        ))
        #expect(result == .cardsHandledOthersPending(count: 2))
    }

    @Test("Rule #5: only credit cards pending, other expenses existed and were cleared")
    func rule5AlmostThereExceptCards() {
        let result = HomeInsightEngine.message(for: context(
            pendingCount: 0, creditCardsDueCount: 2, hasAnyDebt: true, hasOtherExpenseLines: true
        ))
        #expect(result == .almostThereExceptCards(cardsDue: 2))
    }

    @Test("Rule #6: only credit cards pending, no other expenses existed this period at all")
    func rule6OnlyCardsLeft() {
        let result = HomeInsightEngine.message(for: context(
            pendingCount: 0, creditCardsDueCount: 1, hasAnyDebt: true, hasOtherExpenseLines: false
        ))
        #expect(result == .onlyCardsLeft(cardsDue: 1))
    }

    @Test("Rule #7: fully caught up, good loan progress (>= 50%)")
    func rule7CaughtUpGoodProgress() {
        let result = HomeInsightEngine.message(for: context(
            pendingCount: 0, creditCardsDueCount: 0, hasAnyDebt: true, loanProgressPercent: 62
        ))
        #expect(result == .caughtUpGoodProgress(loanPct: 62))
    }

    @Test("Rule #8: fully caught up, early loan progress (< 50%)")
    func rule8CaughtUpEarlyProgress() {
        let result = HomeInsightEngine.message(for: context(
            pendingCount: 0, creditCardsDueCount: 0, hasAnyDebt: true, loanProgressPercent: 12
        ))
        #expect(result == .caughtUpEarlyProgress(loanPct: 12))
    }

    @Test("Rule #9: both other payments and cards pending, healthy utilization (< 10%)")
    func rule9PendingHealthyUtilization() {
        let result = HomeInsightEngine.message(for: context(
            pendingCount: 4, creditCardsDueCount: 1, hasAnyDebt: true, loanProgressPercent: 30, creditUtilizationLevel: .low
        ))
        #expect(result == .pendingHealthyUtilization(count: 4, cardsDue: 1, loanPct: 30))
    }

    @Test("Rule #10: both other payments and cards pending, high utilization (>= 30%)")
    func rule10PendingHighUtilization() {
        let result = HomeInsightEngine.message(for: context(
            pendingCount: 4, creditCardsDueCount: 2, hasAnyDebt: true, creditUtilizationLevel: .high
        ))
        #expect(result == .pendingHighUtilization(count: 4, cardsDue: 2))
    }

    @Test("Rule #11: negative sobrante — reached when medium utilization leaves no other rule to claim the state")
    func rule11TightPeriod() {
        let result = HomeInsightEngine.message(for: context(
            pendingCount: 3, creditCardsDueCount: 1, hasAnyDebt: true, creditUtilizationLevel: .medium, surplus: -25
        ))
        #expect(result == .tightPeriod(count: 3))
    }

    @Test("Rule #12: fallback — no signal matches any specific rule")
    func rule12Fallback() {
        let result = HomeInsightEngine.message(for: context(
            pendingCount: 3, creditCardsDueCount: 1, hasAnyDebt: true, creditUtilizationLevel: .medium, surplus: 50
        ))
        #expect(result == .fallback)
    }

    // MARK: - Priority tie-breaks

    @Test("Tie-break: no debt + negative surplus still resolves via rules #1/#2, never rule #11")
    func tieBreakNoDebtBeatsNegativeSurplus() {
        let result = HomeInsightEngine.message(for: context(pendingCount: 2, hasAnyDebt: false, surplus: -10))
        #expect(result == .noDebtPending(count: 2))
    }

    @Test("Tie-break: loan milestone wins even with negative surplus and pending cards")
    func tieBreakLoanMilestoneBeatsEverythingElse() {
        let result = HomeInsightEngine.message(for: context(
            pendingCount: 0, creditCardsDueCount: 3, hasAnyDebt: true, justPaidOffLoanName: "Casa", surplus: -500
        ))
        #expect(result == .loanJustPaidOff(name: "Casa"))
    }
}
