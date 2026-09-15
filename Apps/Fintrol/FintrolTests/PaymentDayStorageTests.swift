import Testing
import Foundation
@testable import Fintrol

/// Bertrand reported day-of-month off-by-one ("elige 20, guarda 19") in the Préstamos form.
/// Static review found no `day - 1`/0-based indexing anywhere in the four forms (Loans,
/// Recurrentes, Servicios, Suscripciones) — all bind a `Stepper` directly to a 1...31 `Int`.
/// These tests confirm the storage layer each of those Steppers ultimately writes into
/// round-trips the exact day with no transformation, for all four entities.
@Suite("Payment-day storage round-trips exactly (no off-by-one)")
struct PaymentDayStorageTests {
    @Test("Loan.frequency .monthly(day:) round-trips through the model's stored properties")
    func loanFrequencyDayRoundTrips() {
        let loan = Loan(name: "Upstart", direction: .borrowed, principal: 1000, currency: .usd, apr: 0.1, startDate: .now, termMonths: 12, frequency: .monthly(day: 20))
        guard case .monthly(let day) = loan.frequency else {
            Issue.record("expected .monthly")
            return
        }
        #expect(day == 20)
    }

    @Test("RecurringItem.frequency .monthlyOnDay round-trips through the model's stored properties")
    func recurringItemFrequencyDayRoundTrips() {
        let item = RecurringItem(kind: .expense, title: "Renta", amount: 1900, currency: .usd, frequency: .monthlyOnDay(20), startDate: .now)
        guard case .monthlyOnDay(let day) = item.frequency else {
            Issue.record("expected .monthlyOnDay")
            return
        }
        #expect(day == 20)
    }

    @Test("Subscription.paymentDay round-trips exactly")
    func subscriptionPaymentDayRoundTrips() {
        let subscription = Subscription(name: "Netflix", price: 15, currency: .usd, paymentDay: 20, startDate: .now, category: .entertainment)
        #expect(subscription.paymentDay == 20)
    }

    @Test("Service (Subscription.kind == .service).paymentDay round-trips exactly")
    func servicePaymentDayRoundTrips() {
        let service = Subscription(name: "Luz", price: 82, currency: .usd, paymentDay: 20, startDate: .now, homeServiceCategory: .electricity)
        #expect(service.paymentDay == 20)
    }
}
