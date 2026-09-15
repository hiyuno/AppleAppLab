import Foundation

/// Standard (French) amortization: fixed payment, declining interest, increasing principal
/// portion. Pure, `Sendable`, no SwiftData — deterministic from `principal`/`apr`/`frequency`/
/// `termMonths`/`paymentOverride` alone (TRD: nothing here is ever persisted).
///
/// `Decimal` end to end — the one operation `Decimal` doesn't expose directly, `(1+r)^n` for
/// an integer `n`, uses `NSDecimalNumber.raising(toPower:)`, which is exact decimal
/// exponentiation (repeated decimal multiplication), never a `Double` in the loop.
public enum LoanEngine {
    public static func periodicRate(apr: Decimal, frequency: LoanFrequency) -> Decimal {
        switch frequency {
        case .monthly: apr / 12
        case .biweekly: apr / 24
        }
    }

    /// `termMonths` is the persisted source of truth; `n` (the actual number of payment
    /// periods `LoanEngine` amortizes over) depends on frequency too — monthly is 1:1,
    /// biweekly is 2 quincenas per month.
    public static func numberOfPayments(termMonths: Int, frequency: LoanFrequency) -> Int {
        switch frequency {
        case .monthly: termMonths
        case .biweekly: termMonths * 2
        }
    }

    /// Fixed payment for a given term: `P·r / (1 − (1+r)^−n)`, or `P/n` when `apr == 0`
    /// (no division by a zero rate).
    public static func payment(principal: Decimal, apr: Decimal, termMonths: Int, frequency: LoanFrequency) -> Decimal {
        let n = numberOfPayments(termMonths: termMonths, frequency: frequency)
        let r = periodicRate(apr: apr, frequency: frequency)
        // Bertrand (crash, critical): `nil` means the compounding overflowed `Decimal` — fail
        // closed to 0 ("cannot calculate") rather than guessing with a formula that no longer
        // matches the actual (unrepresentable) interest, which is what produced NaN downstream.
        return paymentForN(n, principal: principal, r: r) ?? 0
    }

    /// Inverse of `payment(principal:apr:termMonths:frequency:)`: given a payment the user
    /// fixed by hand (`paymentOverride`), finds the smallest `n` whose required fixed payment
    /// no longer exceeds it. `payment(n)` is strictly decreasing in `n`, so this converges.
    public static func numberOfPayments(forPayment targetPayment: Decimal, principal: Decimal, apr: Decimal, frequency: LoanFrequency, maxPeriods: Int = 1200) -> Int {
        guard targetPayment > 0, principal > 0 else { return 0 }
        let r = periodicRate(apr: apr, frequency: frequency)
        guard r != 0 else {
            return max(1, ceilToInt(principal / targetPayment))
        }
        var n = 1
        while n <= maxPeriods {
            // `nil` (overflow at this n) means "still astronomically larger than any real
            // target" — keep searching larger n rather than treating it as a match.
            if let p = paymentForN(n, principal: principal, r: r), p <= targetPayment {
                return n
            }
            n += 1
        }
        return maxPeriods
    }

    /// Full amortization table. The last installment absorbs the accumulated rounding
    /// adjustment so the balance closes to exactly `0`, never a residual fraction of a cent.
    public static func schedule(
        principal: Decimal,
        apr: Decimal,
        startDate: CivilDate,
        termMonths: Int,
        frequency: LoanFrequency,
        paymentOverride: Decimal? = nil
    ) -> [LoanInstallment] {
        let r = periodicRate(apr: apr, frequency: frequency)
        let n: Int
        let fixedPayment: Decimal
        if let paymentOverride, paymentOverride > 0 {
            n = numberOfPayments(forPayment: paymentOverride, principal: principal, apr: apr, frequency: frequency)
            fixedPayment = paymentOverride
        } else {
            n = numberOfPayments(termMonths: termMonths, frequency: frequency)
            // Bertrand (crash, critical): if the fixed payment itself can't be computed
            // (compounding overflowed `Decimal`), fail closed to an EMPTY schedule instead of
            // limping along with a payment that no longer matches the real (unrepresentable)
            // interest — that mismatch is exactly what let `balance` snowball into NaN over
            // hundreds of iterations in the first version of this fix.
            guard let computed = paymentForN(n, principal: principal, r: r) else { return [] }
            fixedPayment = computed
        }
        guard n > 0, principal > 0 else { return [] }

        var installments: [LoanInstallment] = []
        var balance = principal

        for index in 1...n {
            let interest = roundToCents(balance * r)
            let principalPortion: Decimal
            let paymentThisPeriod: Decimal
            if index == n {
                principalPortion = balance
                paymentThisPeriod = roundToCents(balance + interest)
            } else {
                principalPortion = roundToCents(fixedPayment - interest)
                paymentThisPeriod = fixedPayment
            }
            // Extra belt: if any intermediate value still went non-finite (e.g. `r` itself
            // huge enough that `balance * r` alone overflows plain `Decimal` arithmetic —
            // which fails silently to NaN rather than raising), stop and return whatever
            // valid prefix was already computed instead of appending garbage.
            guard !interest.isNaN, !principalPortion.isNaN, !paymentThisPeriod.isNaN else {
                return installments
            }
            balance -= principalPortion
            let date = installmentDate(index: index, startDate: startDate, frequency: frequency)
            installments.append(LoanInstallment(number: index, date: date, payment: paymentThisPeriod, interest: interest, principal: principalPortion, remainingBalance: balance))
        }

        return installments
    }

    public static func schedule(for loan: LoanSnapshot) -> [LoanInstallment] {
        schedule(
            principal: loan.principal, apr: loan.apr, startDate: loan.startDate,
            termMonths: loan.termMonths, frequency: loan.frequency,
            paymentOverride: loan.paymentOverride
        )
    }

    /// `termMonths` implied by an `endDate` the user edited directly (plazo↔fecha fin
    /// linked fields in DESIGN_LIQUID.md) — whole months between `startDate` and `endDate`,
    /// floored at 1.
    /// Inverse of `endDate(startDate:termMonths:frequency:)` for monthly-equivalent counting:
    /// the Nth monthly installment lands `N-1` calendar months after `startDate` (the first
    /// payment is due the same month it starts), so `termMonths` (a payment *count*) is the
    /// calendar-month gap plus one — this is what keeps the plazo↔fecha-fin fields consistent
    /// when the user edits either one.
    public static func termMonths(from startDate: CivilDate, to endDate: CivilDate) -> Int {
        let months = startDate.wholeMonths(to: endDate)
        return max(1, months + 1)
    }

    public static func endDate(startDate: CivilDate, termMonths: Int, frequency: LoanFrequency) -> CivilDate {
        let n = numberOfPayments(termMonths: termMonths, frequency: frequency)
        guard n > 0 else { return startDate }
        return installmentDate(index: n, startDate: startDate, frequency: frequency)
    }

    // MARK: - Private helpers

    /// Bertrand (crash, critical): with no explicit `NSDecimalNumberHandler`,
    /// `NSDecimalNumber.raising(toPower:)` uses the default handler, whose default behavior
    /// is to **raise an uncaught `NSException` on overflow** — an absurd but reachable APR
    /// (validated 0–100% at the form/model layer, but this engine must never trust that
    /// alone) compounded over up to 600 periods overflows `Decimal`'s ~38-digit range and
    /// crashes the app. `nonRaisingHandler` turns that into a normal `NSDecimalNumber.notANumber`
    /// return value instead, which `power`/`paymentForN` fail closed on (return `nil`/0)
    /// rather than propagate a crash.
    private static let nonRaisingHandler = NSDecimalNumberHandler(
        roundingMode: .plain,
        scale: 34,
        raiseOnExactness: false,
        raiseOnOverflow: false,
        raiseOnUnderflow: false,
        raiseOnDivideByZero: false
    )

    /// `nil` means "cannot be computed" (the compounding overflowed `Decimal`) — callers
    /// must fail closed (0 / empty schedule), never substitute a formula that no longer
    /// matches the real interest for this `r`/`n` (Bertrand's crash: that mismatch is what
    /// let the schedule loop's `balance` snowball into NaN).
    private static func paymentForN(_ n: Int, principal: Decimal, r: Decimal) -> Decimal? {
        guard n > 0 else { return 0 }
        guard r != 0 else { return roundToCents(principal / Decimal(n)) }
        guard let onePlusRPowN = power(1 + r, n), onePlusRPowN != 0 else { return nil }
        let denominator = 1 - (1 / onePlusRPowN)
        guard denominator != 0 else { return nil }
        let raw = principal * r / denominator
        guard !raw.isNaN else { return nil }
        return roundToCents(raw)
    }

    /// Exact `Decimal` exponentiation for an integer power — never touches `Double`, and
    /// never crashes: returns `nil` (instead of raising) when the result overflows `Decimal`.
    private static func power(_ base: Decimal, _ exponent: Int) -> Decimal? {
        let result = NSDecimalNumber(decimal: base).raising(toPower: exponent, withBehavior: nonRaisingHandler)
        guard result != NSDecimalNumber.notANumber else { return nil }
        let value = result.decimalValue
        guard !value.isNaN else { return nil }
        return value
    }

    private static func roundToCents(_ value: Decimal) -> Decimal {
        var result = Decimal()
        var input = value
        NSDecimalRound(&result, &input, 2, .plain)
        return result
    }

    private static func ceilToInt(_ value: Decimal) -> Int {
        var result = Decimal()
        var input = value
        NSDecimalRound(&result, &input, 0, .up)
        return NSDecimalNumber(decimal: result).intValue
    }

    private static func installmentDate(index: Int, startDate: CivilDate, frequency: LoanFrequency) -> CivilDate {
        switch frequency {
        case .monthly(let day):
            let target = startDate.addingMonths(index - 1)
            return CivilDate(year: target.year, month: target.month, day: day).clampedToValidDay
        case .biweekly:
            return startDate.addingDays(15 * (index - 1))
        }
    }
}
