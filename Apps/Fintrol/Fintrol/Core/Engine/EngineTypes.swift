import Foundation

/// Plain, `Sendable` snapshot of a `RecurringItem` — engines never touch `@Model`
/// types directly so they stay testable without a `ModelContainer`.
public struct RecurringItemSnapshot: Sendable, Hashable {
    public let id: UUID
    public let kind: LineKind
    public let title: String
    public let amount: Decimal
    public let currency: Currency
    public let frequency: RecurringFrequency
    public let startDate: CivilDate
    public let endDate: CivilDate?
    public let isActive: Bool
    /// `.investment` → generated lines get `LineOrigin.investment` instead of `.recurring`
    /// (feature #12, "Inversiones").
    public let category: RecurringItemCategory

    public init(
        id: UUID,
        kind: LineKind,
        title: String,
        amount: Decimal,
        currency: Currency,
        frequency: RecurringFrequency,
        startDate: CivilDate,
        endDate: CivilDate?,
        isActive: Bool,
        category: RecurringItemCategory = .general
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.amount = amount
        self.currency = currency
        self.frequency = frequency
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
        self.category = category
    }
}

/// Plain, `Sendable` snapshot of a `Subscription`. `kind` selects whether it feeds the
/// "Payments" (subscription) or "Servicios" (home service) combined line in a quincena.
public struct SubscriptionSnapshot: Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let price: Decimal
    public let currency: Currency
    public let paymentDay: Int
    public let startDate: CivilDate
    public let endDate: CivilDate?
    public let kind: SubscriptionKind
    public let isActive: Bool

    public init(id: UUID, name: String, price: Decimal, currency: Currency, paymentDay: Int, startDate: CivilDate, endDate: CivilDate?, kind: SubscriptionKind = .subscription, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.price = price
        self.currency = currency
        self.paymentDay = paymentDay
        self.startDate = startDate
        self.endDate = endDate
        self.kind = kind
        self.isActive = isActive
    }
}

/// Plain, `Sendable` snapshot of a `Loan`. `kind` is derived from `direction` (the only
/// real difference in how a `Loan` is projected versus a `RecurringItem`, per TRD).
public struct LoanSnapshot: Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let direction: LoanDirection
    public let principal: Decimal
    public let currency: Currency
    public let apr: Decimal
    public let startDate: CivilDate
    public let termMonths: Int
    public let frequency: LoanFrequency
    public let paymentOverride: Decimal?
    public let isActive: Bool
    public let mode: LoanMode
    public let expectedPayment: Decimal?

    public init(id: UUID, name: String, direction: LoanDirection, principal: Decimal, currency: Currency, apr: Decimal, startDate: CivilDate, termMonths: Int, frequency: LoanFrequency, paymentOverride: Decimal?, isActive: Bool, mode: LoanMode = .fixedTerm, expectedPayment: Decimal? = nil) {
        self.id = id
        self.name = name
        self.direction = direction
        self.principal = principal
        self.currency = currency
        self.apr = apr
        self.startDate = startDate
        self.termMonths = termMonths
        self.frequency = frequency
        self.paymentOverride = paymentOverride
        self.isActive = isActive
        self.mode = mode
        self.expectedPayment = expectedPayment
    }

    public var kind: LineKind { direction == .borrowed ? .expense : .income }
}

/// One row of a loan's amortization table — always derived, never persisted
/// (`LoanEngine.schedule`).
public struct LoanInstallment: Sendable, Hashable, Identifiable {
    public var id: Int { number }
    public let number: Int
    public let date: CivilDate
    public let payment: Decimal
    public let interest: Decimal
    public let principal: Decimal
    public let remainingBalance: Decimal

    public init(number: Int, date: CivilDate, payment: Decimal, interest: Decimal, principal: Decimal, remainingBalance: Decimal) {
        self.number = number
        self.date = date
        self.payment = payment
        self.interest = interest
        self.principal = principal
        self.remainingBalance = remainingBalance
    }
}

/// A line an engine proposes to materialize. The coordinator turns this into a
/// real `LineItem` when the target period is actually persisted.
public struct GeneratedLine: Sendable, Hashable {
    public let kind: LineKind
    public let title: String
    public let amount: Decimal
    public let currency: Currency
    public let origin: LineOrigin
    public let sourceRecurringID: UUID?
    /// See `LineItem.isHomeService` — only meaningful when `origin == .subscription`.
    public let isHomeService: Bool
    /// See `LineItem.sourceLoanID` — only meaningful when `origin == .loan`.
    public let sourceLoanID: UUID?
    /// See `LineItem.sourceCreditCardID` — only meaningful when `origin == .creditCard`.
    public let sourceCreditCardID: UUID?

    public init(kind: LineKind, title: String, amount: Decimal, currency: Currency, origin: LineOrigin, sourceRecurringID: UUID?, isHomeService: Bool = false, sourceLoanID: UUID? = nil, sourceCreditCardID: UUID? = nil) {
        self.kind = kind
        self.title = title
        self.amount = amount
        self.currency = currency
        self.origin = origin
        self.sourceRecurringID = sourceRecurringID
        self.isHomeService = isHomeService
        self.sourceLoanID = sourceLoanID
        self.sourceCreditCardID = sourceCreditCardID
    }
}

/// Plain, `Sendable` snapshot of a `CreditCard` for pure engine functions — mirrors
/// `LoanSnapshot`'s role for `Loan`.
public struct CreditCardSnapshot: Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let balance: Decimal
    public let apr: Decimal
    public let creditLimit: Decimal
    public let cutoffDay: Int
    public let paymentDay: Int
    public let expectedPayment: Decimal?
    public let isActive: Bool

    public init(id: UUID, name: String, balance: Decimal, apr: Decimal, creditLimit: Decimal, cutoffDay: Int, paymentDay: Int, expectedPayment: Decimal?, isActive: Bool) {
        self.id = id
        self.name = name
        self.balance = balance
        self.apr = apr
        self.creditLimit = creditLimit
        self.cutoffDay = cutoffDay
        self.paymentDay = paymentDay
        self.expectedPayment = expectedPayment
        self.isActive = isActive
    }
}

/// Plain, `Sendable` snapshot of a `LineItem`, used for total/sobrante math.
public struct LineSnapshot: Sendable, Hashable {
    public let kind: LineKind
    public let amount: Decimal
    public let currency: Currency
    public let origin: LineOrigin
    /// Swipe-leading on `LineItemRow` toggles this; `CarryOverEngine` excludes an inactive
    /// line from every total, sobrante, "Mandar" and the carry-over chain.
    public let isActive: Bool

    public init(kind: LineKind, amount: Decimal, currency: Currency, origin: LineOrigin, isActive: Bool = true) {
        self.kind = kind
        self.amount = amount
        self.currency = currency
        self.origin = origin
        self.isActive = isActive
    }
}
