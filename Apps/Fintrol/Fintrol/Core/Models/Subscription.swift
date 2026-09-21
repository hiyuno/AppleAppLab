import Foundation
import SwiftData

@Model
public final class Subscription {
    public var id: UUID = UUID()
    public var name: String = ""
    public var price: Decimal = 0
    public var currencyRaw: String = Currency.usd.rawValue
    public var paymentDay: Int = 1
    public var startDate: Date = Date()
    public var endDate: Date?
    public var card: String = ""
    /// Soft reference to `CreditCard.id` — same pattern as `LineItem.sourceCreditCardID` (no
    /// `@Relationship`, resolved by querying `CreditCard` by id). Coordinator (2026-09-17):
    /// user feedback — the "Tarjeta" field becomes a picker over the cards already registered
    /// in Credit Cards instead of free text. `card: String` stays as the persisted display/
    /// round-trip value for import/backup — see `SubscriptionsView.save()`.
    public var creditCardID: UUID?
    public var kindRaw: String = SubscriptionKind.subscription.rawValue
    /// Interpreted against `SubscriptionCategory` when `kind == .subscription`, or
    /// `HomeServiceCategory` when `kind == .service` — one string field, two category sets.
    public var categoryRaw: String = SubscriptionCategory.tools.rawValue
    /// Added post-v1 (pre-release, in place — no migration needed per TRD): mirrors
    /// `RecurringItem.isActive`/`Loan.isActive`, which `Subscription` was missing entirely.
    /// The JSON import format carries an explicit `isActive` per item (a deactivated
    /// subscription/service the user still wants on record but no longer projected), and
    /// there was no field to honor that without this.
    public var isActive: Bool = true
    /// "Cada mes" (default) vs "cada quincena" — user's request (2026-09-21), so far only
    /// surfaced in `EssentialEditSheet`. `false` for every existing/imported row (added
    /// post-v1, pre-release — no migration needed). When `true`, `ProjectionEngine` includes
    /// this subscription in BOTH halves of the month instead of gating on `paymentDay`'s half.
    public var isBiweekly: Bool = false

    public init(
        id: UUID = UUID(),
        name: String,
        price: Decimal,
        currency: Currency,
        paymentDay: Int,
        startDate: Date,
        endDate: Date? = nil,
        card: String = "",
        kind: SubscriptionKind = .subscription,
        category: SubscriptionCategory,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.currencyRaw = currency.rawValue
        self.paymentDay = paymentDay
        self.startDate = startDate
        self.endDate = endDate
        self.card = card
        self.kindRaw = kind.rawValue
        self.categoryRaw = category.rawValue
        self.isActive = isActive
    }

    public convenience init(
        id: UUID = UUID(),
        name: String,
        price: Decimal,
        currency: Currency,
        paymentDay: Int,
        startDate: Date,
        endDate: Date? = nil,
        homeServiceCategory: HomeServiceCategory,
        isActive: Bool = true
    ) {
        self.init(
            id: id, name: name, price: price, currency: currency, paymentDay: paymentDay,
            startDate: startDate, endDate: endDate, card: "", kind: .service, category: .tools,
            isActive: isActive
        )
        self.categoryRaw = homeServiceCategory.rawValue
    }

    /// Coordinator (2026-09-21): "Essentials" — mirrors the `homeServiceCategory:` convenience
    /// init above exactly, just `kind: .essential` and `EssentialCategory` instead.
    public convenience init(
        id: UUID = UUID(),
        name: String,
        price: Decimal,
        currency: Currency,
        paymentDay: Int,
        startDate: Date,
        endDate: Date? = nil,
        essentialCategory: EssentialCategory,
        isActive: Bool = true,
        isBiweekly: Bool = false
    ) {
        self.init(
            id: id, name: name, price: price, currency: currency, paymentDay: paymentDay,
            startDate: startDate, endDate: endDate, card: "", kind: .essential, category: .tools,
            isActive: isActive
        )
        self.categoryRaw = essentialCategory.rawValue
        self.isBiweekly = isBiweekly
    }

    public var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .usd }
        set { currencyRaw = newValue.rawValue }
    }

    public var kind: SubscriptionKind {
        get { SubscriptionKind(rawValue: kindRaw) ?? .subscription }
        set { kindRaw = newValue.rawValue }
    }

    public var category: SubscriptionCategory {
        get { SubscriptionCategory(rawValue: categoryRaw) ?? .tools }
        set { categoryRaw = newValue.rawValue }
    }

    public var homeServiceCategory: HomeServiceCategory {
        get { HomeServiceCategory(rawValue: categoryRaw) ?? .rent }
        set { categoryRaw = newValue.rawValue }
    }

    public var essentialCategory: EssentialCategory {
        get { EssentialCategory(rawValue: categoryRaw) ?? .food }
        set { categoryRaw = newValue.rawValue }
    }

    /// Whether the payment day (1–15 vs 16–end) falls in the first half of the month.
    public var isFirstHalfPayment: Bool {
        paymentDay <= 15
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
}
