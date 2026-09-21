import Foundation
import SwiftData

@Model
public final class RecurringItem {
    public var id: UUID = UUID()
    public var kindRaw: String = LineKind.income.rawValue
    public var title: String = ""
    public var amount: Decimal = 0
    public var currencyRaw: String = Currency.usd.rawValue
    public var frequencyKindRaw: String = "biweekly"
    public var frequencyDay: Int?
    public var frequencyOnceDate: Date?
    public var startDate: Date = Date()
    public var endDate: Date?
    public var isActive: Bool = true
    /// Added post-v1 (pre-release, `SchemaV2` in place — no migration): `.investment` marks
    /// this as an "Inversiones" contribution (feature #12) instead of an ordinary recurring
    /// income/expense — its generated lines get `LineOrigin.investment` instead of
    /// `.recurring`, and it's excluded from "Ingresos/Gastos recurrentes".
    public var categoryRaw: String = RecurringItemCategory.general.rawValue
    /// Only meaningful when `category == .investment` — the account/broker name ("GBM",
    /// "Cetesdirecto"), shown in the Inversiones list instead of a generic title.
    public var accountName: String?
    /// Only meaningful when `category == .investment` (2026-09-21, user's request): an account
    /// whose `startDate` is well in the past has real-world contributions the app never
    /// recorded — `InvestmentDetailView` asks once, the first time its schedule shows past
    /// occurrences with nothing marked paid, whether those already happened. `true` once the
    /// user has answered either way, so it never asks again for this account. Added post-v1
    /// (pre-release, `SchemaV2` in place — no migration): `false` default is correct for
    /// every existing row (nothing has been asked yet).
    public var pastPaymentsReviewed: Bool = false

    public init(
        id: UUID = UUID(),
        kind: LineKind,
        title: String,
        amount: Decimal,
        currency: Currency,
        frequency: RecurringFrequency,
        startDate: Date,
        endDate: Date? = nil,
        isActive: Bool = true,
        category: RecurringItemCategory = .general,
        accountName: String? = nil
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.title = title
        self.amount = amount
        self.currencyRaw = currency.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
        self.categoryRaw = category.rawValue
        self.accountName = accountName
        self.setFrequency(frequency)
    }

    public var category: RecurringItemCategory {
        get { RecurringItemCategory(rawValue: categoryRaw) ?? .general }
        set { categoryRaw = newValue.rawValue }
    }

    public var kind: LineKind {
        get { LineKind(rawValue: kindRaw) ?? .income }
        set { kindRaw = newValue.rawValue }
    }

    public var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .usd }
        set { currencyRaw = newValue.rawValue }
    }

    public var frequency: RecurringFrequency {
        get {
            switch frequencyKindRaw {
            case "monthlyOnDay":
                return .monthlyOnDay(frequencyDay ?? 1)
            case "once":
                return .once(frequencyOnceDate ?? startDate)
            default:
                return .biweekly
            }
        }
        set { setFrequency(newValue) }
    }

    /// `startDate`/`endDate` normalized to `CivilDate` for all Core/Engine logic (TRD
    /// "Decisiones de Swift" — Fechas). The persisted columns stay `Date` (SwiftData/CloudKit
    /// need it); these wrap them at the model boundary so nothing downstream compares raw
    /// `Date`s.
    public var civilStartDate: CivilDate {
        get { CivilDate(from: startDate, calendar: .current) }
        set { startDate = newValue.date(calendar: .current) }
    }

    public var civilEndDate: CivilDate? {
        get { endDate.map { CivilDate(from: $0, calendar: .current) } }
        set { endDate = newValue?.date(calendar: .current) }
    }

    private func setFrequency(_ frequency: RecurringFrequency) {
        switch frequency {
        case .biweekly:
            frequencyKindRaw = "biweekly"
            frequencyDay = nil
            frequencyOnceDate = nil
        case .monthlyOnDay(let day):
            frequencyKindRaw = "monthlyOnDay"
            frequencyDay = day
            frequencyOnceDate = nil
        case .once(let date):
            frequencyKindRaw = "once"
            frequencyDay = nil
            frequencyOnceDate = date
        }
    }
}
