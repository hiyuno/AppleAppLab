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

    public init(
        id: UUID = UUID(),
        kind: LineKind,
        title: String,
        amount: Decimal,
        currency: Currency,
        frequency: RecurringFrequency,
        startDate: Date,
        endDate: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.title = title
        self.amount = amount
        self.currencyRaw = currency.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
        self.setFrequency(frequency)
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
