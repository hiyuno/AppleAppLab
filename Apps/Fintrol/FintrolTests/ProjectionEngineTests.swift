import Testing
import Foundation
@testable import Fintrol

@Suite("ProjectionEngine")
struct ProjectionEngineTests {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> CivilDate {
        CivilDate(year: year, month: month, day: day)
    }

    // MARK: - Recurring: biweekly

    @Test("Biweekly recurring item fires in every quincena while vigente")
    func biweeklyFiresEveryHalf() {
        let item = RecurringItemSnapshot(
            id: UUID(), kind: .income, title: "WALO", amount: 2750, currency: .usd,
            frequency: .biweekly, startDate: date(2026, 1, 1), endDate: nil, isActive: true
        )
        let first = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2026, month: 6, half: .first), recurringItems: [item])
        let second = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2026, month: 6, half: .second), recurringItems: [item])
        #expect(first.count == 1)
        #expect(second.count == 1)
        #expect(first[0].amount == 2750)
    }

    // MARK: - Recurring: monthlyOnDay with end date

    @Test("Loan with end date stops generating after its last vigente quincena")
    func loanStopsAfterEndDate() {
        let loan = RecurringItemSnapshot(
            id: UUID(), kind: .expense, title: "Upstart", amount: 629, currency: .usd,
            frequency: .monthlyOnDay(20), startDate: date(2026, 1, 1), endDate: date(2026, 3, 20), isActive: true
        )

        let marchSecond = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2026, month: 3, half: .second), recurringItems: [loan])
        #expect(marchSecond.count == 1, "the last vigente occurrence (day 20, end date) must still generate")

        let aprilSecond = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2026, month: 4, half: .second), recurringItems: [loan])
        #expect(aprilSecond.isEmpty, "the quincena after the end date must not generate a line")
    }

    @Test("monthlyOnDay only fires in the half containing that day")
    func monthlyDayPicksCorrectHalf() {
        let firstHalfItem = RecurringItemSnapshot(
            id: UUID(), kind: .expense, title: "Upstart #2", amount: 534, currency: .usd,
            frequency: .monthlyOnDay(4), startDate: date(2026, 1, 1), endDate: nil, isActive: true
        )
        let inFirstHalf = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2026, month: 5, half: .first), recurringItems: [firstHalfItem])
        let inSecondHalf = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2026, month: 5, half: .second), recurringItems: [firstHalfItem])
        #expect(inFirstHalf.count == 1)
        #expect(inSecondHalf.isEmpty)
    }

    // MARK: - Manual edit wins

    @Test("Manual edit wins: only non-edited lines are returned for regeneration")
    func manualEditWinsRule() {
        let recurringID = UUID()
        let editedLineID = UUID()
        let untouchedLineID = UUID()
        let otherRecurringLineID = UUID()

        let materialized: [(id: UUID, sourceRecurringID: UUID?, isManuallyEdited: Bool)] = [
            (id: editedLineID, sourceRecurringID: recurringID, isManuallyEdited: true),
            (id: untouchedLineID, sourceRecurringID: recurringID, isManuallyEdited: false),
            (id: otherRecurringLineID, sourceRecurringID: UUID(), isManuallyEdited: false),
        ]

        let toRegenerate = ProjectionEngine.lineIDsToRegenerate(matchingRecurringID: recurringID, materializedLines: materialized)

        #expect(toRegenerate == [untouchedLineID])
        #expect(!toRegenerate.contains(editedLineID), "a manually edited line must never be scheduled for overwrite")
    }

    // MARK: - Subscriptions by payment day

    @Test("Subscription paid on day <= 15 is combined into the first-half line")
    func subscriptionFirstHalf() {
        let iCloud = SubscriptionSnapshot(id: UUID(), name: "iCloud", price: 9.99, currency: .usd, paymentDay: 15, startDate: date(2026, 1, 1), endDate: nil)
        let line = ProjectionEngine.generateSubscriptionLine(for: PeriodCoordinate(year: 2026, month: 6, half: .first), subscriptions: [iCloud], kind: .subscription, exchangeRate: 18)
        #expect(line != nil)
        #expect(line?.title == "Payments 1–15")
        #expect(line?.amount == 9.99)
    }

    @Test("Subscription paid on day 16+ is combined into the second-half line")
    func subscriptionSecondHalf() {
        let claude = SubscriptionSnapshot(id: UUID(), name: "Claude", price: 21, currency: .usd, paymentDay: 30, startDate: date(2026, 1, 1), endDate: nil)
        let firstHalf = ProjectionEngine.generateSubscriptionLine(for: PeriodCoordinate(year: 2026, month: 6, half: .first), subscriptions: [claude], kind: .subscription, exchangeRate: 18)
        let secondHalf = ProjectionEngine.generateSubscriptionLine(for: PeriodCoordinate(year: 2026, month: 6, half: .second), subscriptions: [claude], kind: .subscription, exchangeRate: 18)
        #expect(firstHalf == nil)
        #expect(secondHalf?.amount == 21)
    }

    @Test("MXN subscriptions convert into the combined USD total")
    func subscriptionMixedCurrencyCombines() {
        let netflix = SubscriptionSnapshot(id: UUID(), name: "Netflix MX", price: 219, currency: .mxn, paymentDay: 3, startDate: date(2026, 1, 1), endDate: nil)
        let chatgpt = SubscriptionSnapshot(id: UUID(), name: "ChatGPT", price: 20, currency: .usd, paymentDay: 1, startDate: date(2026, 1, 1), endDate: nil)
        let rate = Decimal(string: "18.25")!
        let line = ProjectionEngine.generateSubscriptionLine(for: PeriodCoordinate(year: 2026, month: 6, half: .first), subscriptions: [netflix, chatgpt], kind: .subscription, exchangeRate: rate)
        let expected = CurrencyConversion.toUSD(amount: 219, currency: .mxn, rate: rate) + 20
        #expect(line?.amount == expected)
        #expect(line?.currency == .usd)
    }

    @Test("Subscription with an end date stops the quincena after it expires")
    func subscriptionEndsAfterExpiry() {
        let sub = SubscriptionSnapshot(id: UUID(), name: "Trial", price: 5, currency: .usd, paymentDay: 12, startDate: date(2026, 1, 1), endDate: date(2026, 6, 12))
        let juneFirst = ProjectionEngine.generateSubscriptionLine(for: PeriodCoordinate(year: 2026, month: 6, half: .first), subscriptions: [sub], kind: .subscription, exchangeRate: 18)
        let julyFirst = ProjectionEngine.generateSubscriptionLine(for: PeriodCoordinate(year: 2026, month: 7, half: .first), subscriptions: [sub], kind: .subscription, exchangeRate: 18)
        #expect(juneFirst != nil)
        #expect(julyFirst == nil)
    }

    @Test("No subscriptions active in a half returns no generated line")
    func noSubscriptionsReturnsNil() {
        let line = ProjectionEngine.generateSubscriptionLine(for: PeriodCoordinate(year: 2026, month: 6, half: .first), subscriptions: [], kind: .subscription, exchangeRate: 18)
        #expect(line == nil)
    }

    // MARK: - Services vs. subscriptions are two independent combined lines

    @Test("Services and subscriptions never mix into the same combined line")
    func servicesAndSubscriptionsAreIsolated() {
        let netflix = SubscriptionSnapshot(id: UUID(), name: "Netflix", price: 15, currency: .usd, paymentDay: 5, startDate: date(2026, 1, 1), endDate: nil, kind: .subscription)
        let rent = SubscriptionSnapshot(id: UUID(), name: "Renta", price: 1900, currency: .usd, paymentDay: 5, startDate: date(2026, 1, 1), endDate: nil, kind: .service)

        let subscriptionLine = ProjectionEngine.generateSubscriptionLine(for: PeriodCoordinate(year: 2026, month: 6, half: .first), subscriptions: [netflix, rent], kind: .subscription, exchangeRate: 18)
        let serviceLine = ProjectionEngine.generateSubscriptionLine(for: PeriodCoordinate(year: 2026, month: 6, half: .first), subscriptions: [netflix, rent], kind: .service, exchangeRate: 18)

        #expect(subscriptionLine?.amount == 15)
        #expect(subscriptionLine?.title == "Payments 1–15")
        #expect(subscriptionLine?.isHomeService == false)

        #expect(serviceLine?.amount == 1900)
        #expect(serviceLine?.title == "Servicios 1–15")
        #expect(serviceLine?.isHomeService == true)
    }

    // MARK: - Bertrand's WALO/Luz bugs (Avie's root-cause fix: CivilDate everywhere).
    // Both reproduced the same way: a `Date`/`Calendar` mismatch shifted classification by a
    // day depending on the device's time zone. Run under two different device zones and
    // require identical results — proof the fix no longer depends on the device's zone.

    @Test("WALO (biweekly, starts Sep 1): appears exactly once in Sep 1-15, once in Sep 16-30, never in Aug 16-30", arguments: [
        TimeZone(identifier: "America/Mexico_City")!,
        TimeZone(identifier: "UTC")!,
    ])
    func waloAppearsExactlyOncePerHalf(deviceZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = deviceZone
        let pickerStart = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let civilStart = CivilDate(from: pickerStart, calendar: calendar)

        let walo = RecurringItemSnapshot(
            id: UUID(), kind: .income, title: "WALO", amount: 2750, currency: .usd,
            frequency: .biweekly, startDate: civilStart, endDate: nil, isActive: true
        )

        let sepFirst = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2026, month: 9, half: .first), recurringItems: [walo])
        let sepSecond = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2026, month: 9, half: .second), recurringItems: [walo])
        let augSecond = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2026, month: 8, half: .second), recurringItems: [walo])

        #expect(sepFirst.count == 1, "device zone \(deviceZone.identifier): WALO missing from Sep 1-15")
        #expect(sepSecond.count == 1, "device zone \(deviceZone.identifier): WALO must appear exactly once in Sep 16-30, not duplicated")
        #expect(augSecond.isEmpty, "device zone \(deviceZone.identifier): WALO starts Sep 1, must not appear before its start date")
    }

    @Test("Luz (monthlyOnDay 12) appears in Sep 1-15, in both device time zones", arguments: [
        TimeZone(identifier: "America/Mexico_City")!,
        TimeZone(identifier: "UTC")!,
    ])
    func luzAppearsOnDay12(deviceZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = deviceZone
        let pickerStart = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let civilStart = CivilDate(from: pickerStart, calendar: calendar)

        let luz = RecurringItemSnapshot(
            id: UUID(), kind: .expense, title: "Luz", amount: 450, currency: .mxn,
            frequency: .monthlyOnDay(12), startDate: civilStart, endDate: nil, isActive: true
        )

        let sepFirst = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2026, month: 9, half: .first), recurringItems: [luz])
        #expect(sepFirst.count == 1, "device zone \(deviceZone.identifier): Luz missing from Sep 1-15")
    }
}
