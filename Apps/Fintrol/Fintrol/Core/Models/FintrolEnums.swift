import Foundation

public enum LineKind: String, Codable, Sendable, CaseIterable {
    case income
    case expense
}

public enum Currency: String, Codable, Sendable, CaseIterable {
    case usd
    case mxn
}

public enum LineOrigin: String, Codable, Sendable, CaseIterable {
    case manual
    case carryOver
    case recurring
    case subscription
    case loan
    /// "Inversiones" (PRD #12) — a `RecurringItem` with `category == .investment`. Same
    /// materialization/reproject path as `.recurring` (same `sourceRecurringID`), just a
    /// different origin so `LineItemRow` can show its own icon and the totals/lists that
    /// exclude investments from "Ingresos/Gastos recurrentes" can tell them apart.
    case investment
    /// "Credit Cards" (PRD #13, promoted from Fase 2 to v1) — a `CreditCard`'s own real
    /// `LineItem` (via `sourceCreditCardID`). Always `.expense`. The aggregated "Credit Cards
    /// Payments" row shown in `PeriodView` is presentation-only — it groups lines with this
    /// origin at render time, never a separate `LineItem`/model.
    case creditCard
    /// "Essentials" (2026-09-21, user's request) — a `Subscription` with `kind == .essential`:
    /// budgeted everyday spend (food, transportation, clothing, tech, furniture, fun), same
    /// mechanic as Services/Subscriptions (payment day 1–31, one aggregated line per half) but
    /// its own origin instead of reusing `.subscription` + `isHomeService`, since that flag is
    /// only binary and a third kind needs its own tag to disambiguate cleanly.
    case essential
}

/// TRD "Credit Cards" (2026-09-17): global preference (applies to every card), read ONLY in
/// the UI layer (`SettingsView`/`PeriodView`) and passed to
/// `PeriodCoordinator.reprojectCreditCard` as a plain parameter — `Core/` never reads
/// `@AppStorage` directly, same pattern as `navigableLowerBound(context:monthsBack:)`. Not
/// itself `@AppStorage`-backed (the associated `Int` on `.daysBeforeCutoff` can't be a plain
/// `RawRepresentable`) — the UI layer stores the case and the N separately and reconstructs
/// this value when calling into `Core/`.
public enum CreditCardPaymentDateRule: Sendable, Equatable {
    /// Only avoids interest — simplest option, no credit score benefit.
    case onPaymentDate
    /// Almost as good as paying early, with no buffer if something goes wrong.
    case onCutoffDate
    /// Reduces the balance reported to the credit bureau — default, N = 5.
    case daysBeforeCutoff(Int)

    /// Pure conversion from the two plain `@AppStorage` primitives the UI layer stores
    /// (`fintrol.creditCardPaymentDateRuleKind`: 0/1/2, `fintrol.creditCardPaymentDateRuleDays`)
    /// — lets every UI call site share one mapping instead of re-deriving it.
    public static func resolve(kindRaw: Int, days: Int) -> CreditCardPaymentDateRule {
        switch kindRaw {
        case 0: return .onPaymentDate
        case 1: return .onCutoffDate
        default: return .daysBeforeCutoff(days)
        }
    }
}

/// `RecurringItem.category` — distinguishes an "Inversiones" contribution (feature #12) from
/// an ordinary recurring income/expense. Added post-v1 (pre-release, `SchemaV2` in place —
/// no migration): default `.general` keeps every existing `RecurringItem` behaving exactly as
/// before.
public enum RecurringItemCategory: String, Codable, Sendable, CaseIterable {
    case general
    case investment
}

public enum PeriodHalf: String, Codable, Sendable, CaseIterable {
    /// Days 1–15 of the month.
    case first
    /// Day 16 to the last day of the month.
    case second
}

public enum RecurringFrequency: Codable, Sendable, Hashable {
    case biweekly
    case monthlyOnDay(Int)
    case once(Date)
}

/// Coordinator (2026-09-17): user feedback — "en settings agrega que podamos agregar las
/// categorías que queramos". Subscription categories are now user-editable
/// (`SubscriptionCategoryItem`, a `@Model`), so this enum is no longer read by the picker in
/// `SubscriptionsView`. It stays only as the SEED source: `RootView`'s one-time seed step
/// creates one `SubscriptionCategoryItem` per case (same `rawValue`/icon) on first launch so
/// `Subscription.categoryRaw` — persisted data, never touched — keeps matching real rows.
/// `displayName`/`Codable` are unused post-seed but kept so existing call sites (import
/// mapping, `Subscription.category` convenience accessor) that still speak this enum's
/// vocabulary keep compiling without a wider rewrite.
public enum SubscriptionCategory: String, Codable, Sendable, CaseIterable {
    case tools = "Tools"
    case entertainment = "Entertainment"
    case apartment = "Apartment"
    case work = "Work"
    case personal = "Personal"
    case hobby = "Hobby"
    case investment = "Investment"

    /// L10N_AUDIT.md L-002: `rawValue` is what's PERSISTED (SwiftData/CloudKit) and must
    /// never change — this is the separate, localized DISPLAY value UI code should read
    /// instead of `rawValue` directly. Own key per case so English copy can be tuned
    /// independently of the persisted raw string.
    public var displayName: String {
        switch self {
        case .tools: String(localized: "subscription_category_tools", defaultValue: "Tools")
        case .entertainment: String(localized: "subscription_category_entertainment", defaultValue: "Entertainment")
        case .apartment: String(localized: "subscription_category_apartment", defaultValue: "Apartment")
        case .work: String(localized: "subscription_category_work", defaultValue: "Work")
        case .personal: String(localized: "subscription_category_personal", defaultValue: "Personal")
        case .hobby: String(localized: "subscription_category_hobby", defaultValue: "Hobby")
        case .investment: String(localized: "subscription_category_investment", defaultValue: "Investment")
        }
    }

    /// Icon seeded onto the matching `SubscriptionCategoryItem` — the switch that used to live
    /// directly in `SubscriptionsView.iconName(for:)`, moved here so both the seed step and any
    /// future reseed share one mapping instead of two.
    public var seedIconName: String {
        switch self {
        case .tools: "wrench.and.screwdriver"
        case .entertainment: "play.tv"
        case .apartment: "house"
        case .work: "briefcase"
        case .personal: "person"
        case .hobby: "paintpalette"
        case .investment: "chart.line.uptrend.xyaxis"
        }
    }
}

/// Distinguishes an entertainment/tools subscription from a home service (rent, utilities)
/// within the same `Subscription` @Model — same mechanic (payment day 1–31), different
/// screen, icon and category set. DESIGN_LIQUID.md leaves the modeling choice to Woz; a
/// shared model with a `kind` keeps CloudKit simple (no new entity, no new relationships).
public enum SubscriptionKind: String, Codable, Sendable, CaseIterable {
    case subscription
    case service
    /// "Essentials" (2026-09-21, user's request) — everyday budgeted spend (food, gas/
    /// transportation, clothing, tech, furniture, fun), same mechanic as service/subscription.
    case essential
}

/// Category set for home services (Servicios) — distinct from `SubscriptionCategory`,
/// which stays reserved for entertainment/tools/work subscriptions.
public enum HomeServiceCategory: String, Codable, Sendable, CaseIterable {
    case rent = "Renta"
    case electricity = "Luz"
    case internet = "Internet"
    case water = "Agua"
    case gas = "Gas"
    case insurance = "Seguro"

    /// L10N_AUDIT.md L-002: same fix as `SubscriptionCategory.displayName` — `rawValue`
    /// stays the Spanish string already persisted (never touched, avoids a data migration),
    /// this is the separate, localized DISPLAY value.
    public var displayName: String {
        switch self {
        case .rent: String(localized: "home_service_category_rent", defaultValue: "Rent")
        case .electricity: String(localized: "home_service_category_electricity", defaultValue: "Electricity")
        case .internet: String(localized: "home_service_category_internet", defaultValue: "Internet")
        case .water: String(localized: "home_service_category_water", defaultValue: "Water")
        case .gas: String(localized: "home_service_category_gas", defaultValue: "Gas")
        case .insurance: String(localized: "home_service_category_insurance", defaultValue: "Insurance")
        }
    }
}

/// Category set for "Essentials" — everyday budgeted spend, distinct from `HomeServiceCategory`
/// (fixed monthly bills) and `SubscriptionCategory`/`SubscriptionCategoryItem` (entertainment/
/// tools subscriptions). User's explicit list (2026-09-21): food, gas/transportation, clothing,
/// tech, furniture, fun (going out, dinners, eating out, clubs, etc.).
public enum EssentialCategory: String, Codable, Sendable, CaseIterable {
    case food = "Food"
    case transportation = "Transportation"
    case clothing = "Clothing"
    case tech = "Tech"
    case furniture = "Furniture"
    case fun = "Fun"

    public var displayName: String {
        switch self {
        case .food: String(localized: "essential_category_food", defaultValue: "Food")
        case .transportation: String(localized: "essential_category_transportation", defaultValue: "Gas / Transportation")
        case .clothing: String(localized: "essential_category_clothing", defaultValue: "Clothing")
        case .tech: String(localized: "essential_category_tech", defaultValue: "Tech")
        case .furniture: String(localized: "essential_category_furniture", defaultValue: "Furniture")
        case .fun: String(localized: "essential_category_fun", defaultValue: "Fun")
        }
    }

    public var iconName: String {
        switch self {
        case .food: "fork.knife"
        case .transportation: "fuelpump.fill"
        case .clothing: "tshirt.fill"
        case .tech: "laptopcomputer"
        case .furniture: "sofa.fill"
        case .fun: "party.popper.fill"
        }
    }
}

/// `.borrowed` — someone lent the user money: its payments are EXPENSES.
/// `.lent` — the user lent money to someone else: its payments are INCOME.
public enum LoanDirection: String, Codable, Sendable, CaseIterable {
    case borrowed
    case lent
}

public enum LoanFrequency: Codable, Sendable, Hashable {
    case monthly(day: Int)
    case biweekly
}

/// `.fixedTerm` — the original mode: known term/end date, fixed calculated (or overridden)
/// payment, `LoanEngine.schedule`. `.revolving` ("Hasta liquidar") — credit-card-style debt
/// with no fixed term: monthly interest on balance, an `expectedPayment` per period that the
/// user's real payment can differ from each time, `LoanEngine.revolvingSchedule`. Added
/// post-v1 (pre-release, `SchemaV2` in place — no migration).
public enum LoanMode: String, Codable, Sendable, CaseIterable {
    case fixedTerm
    case revolving
}
