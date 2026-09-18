import Foundation
import SwiftData

@Model
public final class LineItem {
    public var id: UUID = UUID()
    public var kindRaw: String = LineKind.income.rawValue
    public var title: String = ""
    public var amount: Decimal = 0
    public var currencyRaw: String = Currency.usd.rawValue
    public var isPaid: Bool = false
    /// Added post-v1 (pre-release, SchemaV2 in place — no migration): swipe-leading on
    /// `LineItemRow` toggles this instead of the old inline toggle. `false` excludes the line
    /// from TOTAL INCOME/EXPENSES, sobrante, "Mandar", and the carry-over chain — see
    /// `CarryOverEngine`. Toggling it counts as a manual edit (`isManuallyEdited`), same as
    /// editing the amount, so a future `reproject*` never silently reactivates it.
    public var isActive: Bool = true
    public var sortOrder: Int = 0
    public var originRaw: String = LineOrigin.manual.rawValue
    public var sourceRecurringID: UUID?
    /// Same mechanism as `sourceRecurringID` but for `Loan` — a `.loan` line never has both
    /// populated (TRD).
    public var sourceLoanID: UUID?
    /// Same mechanism as `sourceLoanID` but for `CreditCard` (TRD "Credit Cards", 2026-09-17)
    /// — a `.creditCard` line always has exactly this one source populated, always individual
    /// (never a "sum" line; the aggregated "Credit Cards Payments" row is presentation-only in
    /// `PeriodView`, grouping by `origin == .creditCard` at render time).
    public var sourceCreditCardID: UUID?
    public var isManuallyEdited: Bool = false
    public var exchangeRateSnapshot: Decimal?
    /// Only meaningful when `origin == .subscription` — distinguishes the combined
    /// "Servicios" line (home services) from the combined "Payments" line (subscriptions)
    /// for icon purposes; both keep `origin == .subscription` per DESIGN_LIQUID.md.
    public var isHomeService: Bool = false
    /// Added post-v1 (pre-release, SchemaV2 in place — no migration): TRD "paidAt/progreso
    /// real de préstamos", 2026-09-16 — the real date the user confirmed `isPaid = true` via
    /// the swipe toggle (`PeriodView`), not the scheduled/period date. `nil` while
    /// `isPaid == false`. Stored as a raw `Date` (SwiftData/CloudKit need it, same convention
    /// as `Loan.startDate`/`RecurringItem.startDate`); `paidAt` below normalizes it to
    /// `CivilDate` for all Core/Engine logic.
    public var paidAtDate: Date?

    public var period: Period?

    public init(
        id: UUID = UUID(),
        kind: LineKind,
        title: String,
        amount: Decimal,
        currency: Currency,
        isPaid: Bool = false,
        isActive: Bool = true,
        sortOrder: Int = 0,
        origin: LineOrigin = .manual,
        sourceRecurringID: UUID? = nil,
        sourceLoanID: UUID? = nil,
        sourceCreditCardID: UUID? = nil,
        isManuallyEdited: Bool = false,
        exchangeRateSnapshot: Decimal? = nil,
        isHomeService: Bool = false,
        paidAtDate: Date? = nil,
        period: Period? = nil
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.title = title
        self.amount = amount
        self.currencyRaw = currency.rawValue
        self.isPaid = isPaid
        self.isActive = isActive
        self.sortOrder = sortOrder
        self.originRaw = origin.rawValue
        self.sourceRecurringID = sourceRecurringID
        self.sourceLoanID = sourceLoanID
        self.sourceCreditCardID = sourceCreditCardID
        self.isManuallyEdited = isManuallyEdited
        self.exchangeRateSnapshot = exchangeRateSnapshot
        self.isHomeService = isHomeService
        self.paidAtDate = paidAtDate
        self.period = period
    }

    public var kind: LineKind {
        get { LineKind(rawValue: kindRaw) ?? .income }
        set { kindRaw = newValue.rawValue }
    }

    public var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .usd }
        set { currencyRaw = newValue.rawValue }
    }

    public var origin: LineOrigin {
        get { LineOrigin(rawValue: originRaw) ?? .manual }
        set { originRaw = newValue.rawValue }
    }

    public var paidAt: CivilDate? {
        get { paidAtDate.map { CivilDate(from: $0, calendar: .current) } }
        set { paidAtDate = newValue?.date(calendar: .current) }
    }
}
