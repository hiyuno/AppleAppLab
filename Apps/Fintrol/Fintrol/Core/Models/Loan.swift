import Foundation
import SwiftData

/// A loan with standard (French) amortization — `.borrowed` (someone lent the user money)
/// generates EXPENSE lines, `.lent` (the user lent money) generates INCOME lines. `termMonths`
/// is the single persisted source of truth for the term — `endDate` is always derived from
/// it via `LoanEngine`, never stored independently (TRD: "uno se persiste, el otro se
/// recalcula"). `lineItems` is resolved the same way as `RecurringItem`/`Subscription` —
/// by querying `LineItem.sourceLoanID`, not a stored `@Relationship`.
@Model
public final class Loan {
    public var id: UUID = UUID()
    public var name: String = ""
    public var directionRaw: String = LoanDirection.borrowed.rawValue
    public var principal: Decimal = 0
    public var currencyRaw: String = Currency.usd.rawValue
    public var apr: Decimal = 0
    public var startDate: Date = Date()
    public var termMonths: Int = 1
    public var frequencyKindRaw: String = "monthly"
    public var frequencyDay: Int?
    public var paymentOverride: Decimal?
    public var isActive: Bool = true

    public init(
        id: UUID = UUID(),
        name: String,
        direction: LoanDirection,
        principal: Decimal,
        currency: Currency,
        apr: Decimal,
        startDate: Date,
        termMonths: Int,
        frequency: LoanFrequency,
        paymentOverride: Decimal? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.directionRaw = direction.rawValue
        self.principal = principal
        self.currencyRaw = currency.rawValue
        self.apr = apr
        self.startDate = startDate
        self.termMonths = termMonths
        self.paymentOverride = paymentOverride
        self.isActive = isActive
        self.setFrequency(frequency)
    }

    public var direction: LoanDirection {
        get { LoanDirection(rawValue: directionRaw) ?? .borrowed }
        set { directionRaw = newValue.rawValue }
    }

    public var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .usd }
        set { currencyRaw = newValue.rawValue }
    }

    public var frequency: LoanFrequency {
        get {
            frequencyKindRaw == "biweekly" ? .biweekly : .monthly(day: frequencyDay ?? 1)
        }
        set { setFrequency(newValue) }
    }

    /// `startDate` normalized to `CivilDate` for all Core/Engine logic (TRD "Decisiones de
    /// Swift" — Fechas). The persisted column stays `Date` (SwiftData/CloudKit need it); this
    /// wraps it at the model boundary so nothing downstream compares raw `Date`s.
    public var civilStartDate: CivilDate {
        get { CivilDate(from: startDate, calendar: .current) }
        set { startDate = newValue.date(calendar: .current) }
    }

    /// The kind of `LineItem` this loan's payments generate — the only real difference
    /// between how the coordinator treats a `Loan` versus a `RecurringItem` (TRD).
    public var kind: LineKind {
        direction == .borrowed ? .expense : .income
    }

    private func setFrequency(_ frequency: LoanFrequency) {
        switch frequency {
        case .monthly(let day):
            frequencyKindRaw = "monthly"
            frequencyDay = day
        case .biweekly:
            frequencyKindRaw = "biweekly"
            frequencyDay = nil
        }
    }
}
