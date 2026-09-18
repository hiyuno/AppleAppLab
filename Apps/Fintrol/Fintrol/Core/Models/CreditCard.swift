import Foundation
import SwiftData

/// Revolving debt — no fixed term, monthly interest on balance, standard-issuer suggested
/// minimum payment. TRD "Credit Cards" (promoted from Fase 2 to v1, 2026-09-17): reuses
/// `Loan.revolving`'s data-level mechanics (`LoanEngine.revolvingSchedule`,
/// `LoanEngine.monthlyRevolvingInterest`) but is its own model/screen — a card is never "Me
/// deben" (always `.expense`), unlike a `Loan` which can be either direction.
/// `lineItems` is resolved by querying `LineItem.sourceCreditCardID`, same mechanism as
/// `Loan`/`RecurringItem` — not a stored `@Relationship`.
@Model
public final class CreditCard {
    public var id: UUID = UUID()
    public var name: String = ""
    public var balance: Decimal = 0
    public var apr: Decimal = 0
    public var creditLimit: Decimal = 0
    public var cutoffDay: Int = 1
    public var paymentDay: Int = 1
    /// `nil` ⇒ each period uses `CreditCardEngine.suggestedMinimumPayment` calculated live;
    /// if set, that's the default editable per-period amount — same pattern as
    /// `Loan.revolving.expectedPayment`.
    public var expectedPayment: Decimal?
    public var isActive: Bool = true
    /// Coordinator (2026-09-17): last 4 digits only — never full PAN, so this is safe to
    /// display/persist (not PCI DSS-regulated data). Optional, default `nil` — `SchemaV2` in
    /// place, pre-release, no migration.
    public var lastFourDigits: String?

    public init(
        id: UUID = UUID(),
        name: String,
        balance: Decimal,
        apr: Decimal,
        creditLimit: Decimal,
        cutoffDay: Int,
        paymentDay: Int,
        expectedPayment: Decimal? = nil,
        isActive: Bool = true,
        lastFourDigits: String? = nil
    ) {
        self.id = id
        self.name = name
        self.balance = balance
        self.apr = apr
        self.creditLimit = creditLimit
        self.cutoffDay = cutoffDay
        self.paymentDay = paymentDay
        self.expectedPayment = expectedPayment
        self.isActive = isActive
        self.lastFourDigits = lastFourDigits
    }

    /// A credit card's payments are always an expense — never "Me deben" like a `Loan` can be.
    public var kind: LineKind { .expense }
}
