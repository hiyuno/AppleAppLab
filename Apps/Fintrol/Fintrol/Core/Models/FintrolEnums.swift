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

public enum SubscriptionCategory: String, Codable, Sendable, CaseIterable {
    case tools = "Tools"
    case entertainment = "Entertainment"
    case apartment = "Apartment"
    case work = "Work"
    case personal = "Personal"
    case hobby = "Hobby"
    case investment = "Investment"
}

/// Distinguishes an entertainment/tools subscription from a home service (rent, utilities)
/// within the same `Subscription` @Model — same mechanic (payment day 1–31), different
/// screen, icon and category set. DESIGN_LIQUID.md leaves the modeling choice to Woz; a
/// shared model with a `kind` keeps CloudKit simple (no new entity, no new relationships).
public enum SubscriptionKind: String, Codable, Sendable, CaseIterable {
    case subscription
    case service
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
