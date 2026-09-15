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

    public init(
        id: UUID,
        kind: LineKind,
        title: String,
        amount: Decimal,
        currency: Currency,
        frequency: RecurringFrequency,
        startDate: CivilDate,
        endDate: CivilDate?,
        isActive: Bool
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

    public init(id: UUID, name: String, price: Decimal, currency: Currency, paymentDay: Int, startDate: CivilDate, endDate: CivilDate?, kind: SubscriptionKind = .subscription) {
        self.id = id
        self.name = name
        self.price = price
        self.currency = currency
        self.paymentDay = paymentDay
        self.startDate = startDate
        self.endDate = endDate
        self.kind = kind
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

    public init(id: UUID, name: String, direction: LoanDirection, principal: Decimal, currency: Currency, apr: Decimal, startDate: CivilDate, termMonths: Int, frequency: LoanFrequency, paymentOverride: Decimal?, isActive: Bool) {
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

    public init(kind: LineKind, title: String, amount: Decimal, currency: Currency, origin: LineOrigin, sourceRecurringID: UUID?, isHomeService: Bool = false, sourceLoanID: UUID? = nil) {
        self.kind = kind
        self.title = title
        self.amount = amount
        self.currency = currency
        self.origin = origin
        self.sourceRecurringID = sourceRecurringID
        self.isHomeService = isHomeService
        self.sourceLoanID = sourceLoanID
    }
}

/// Plain, `Sendable` snapshot of a `LineItem`, used for total/sobrante math.
public struct LineSnapshot: Sendable, Hashable {
    public let kind: LineKind
    public let amount: Decimal
    public let currency: Currency
    public let origin: LineOrigin

    public init(kind: LineKind, amount: Decimal, currency: Currency, origin: LineOrigin) {
        self.kind = kind
        self.amount = amount
        self.currency = currency
        self.origin = origin
    }
}
