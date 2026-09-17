import Testing
import Foundation
import SwiftData
@testable import Fintrol

/// TRD-adjacent: subscription/service JSON import (Ajustes → "Importar suscripciones y
/// servicios…"). `SubscriptionImportService.parse` is pure; `PeriodCoordinator.importSubscriptions`
/// is the SwiftData-touching half, tested separately below.
@Suite("SubscriptionImportService — parsing")
struct SubscriptionImportServiceTests {
    /// The 3-item fixture the coordinator asked for: one valid subscription, one valid
    /// service, one invalid item (bad payDay, out of the 1-31 range).
    private static let threeItemFixture = """
    {"version":1,"items":[
        {"name":"Netflix","kind":"subscription","amount":15,"currency":"USD","payDay":5,"startDate":"2026-01-01","endDate":null,"isActive":true,"paymentMethod":"Apple Card","category":"entertainment"},
        {"name":"Luz","kind":"service","amount":82,"currency":"USD","payDay":12,"startDate":"2023-01-03","endDate":null,"isActive":true,"paymentMethod":"Apple Card","category":"home"},
        {"name":"Broken","kind":"subscription","amount":10,"currency":"USD","payDay":99,"startDate":"2026-01-01","endDate":null,"isActive":true,"paymentMethod":"","category":"tools"}
    ]}
    """.data(using: .utf8)!

    @Test("3-item fixture: 2 valid (subscription + service), 1 skipped (payDay out of range)")
    func threeItemFixtureParsesTwoValidOneInvalid() {
        let result = SubscriptionImportService.parse(data: Self.threeItemFixture)
        #expect(result.valid.count == 2)
        #expect(result.issues.count == 1)
        #expect(result.issues.first?.name == "Broken")
        #expect(result.issues.first?.reason.contains("payDay") == true)

        let netflix = result.valid.first { $0.name == "Netflix" }
        #expect(netflix?.kind == .subscription)
        #expect(netflix?.amount == 15)
        #expect(netflix?.currency == .usd)
        #expect(netflix?.payDay == 5)
        #expect(netflix?.startDate == CivilDate(year: 2026, month: 1, day: 1))
        #expect(netflix?.endDate == nil)
        #expect(netflix?.paymentMethod == "Apple Card")
        #expect(netflix?.subscriptionCategory == .entertainment)

        let luz = result.valid.first { $0.name == "Luz" }
        #expect(luz?.kind == .service)
        #expect(luz?.amount == 82)
        #expect(luz?.payDay == 12)
        #expect(luz?.startDate == CivilDate(year: 2023, month: 1, day: 3))
        // "home" has no direct HomeServiceCategory match -> nearest neighbor, .rent.
        #expect(luz?.homeServiceCategory == .rent)
    }

    @Test("Malformed JSON (not the expected shape) reports one file-level issue, no crash")
    func malformedJSONReportsFileLevelIssue() {
        let result = SubscriptionImportService.parse(data: "not json".data(using: .utf8)!)
        #expect(result.valid.isEmpty)
        #expect(result.issues.count == 1)
    }

    @Test("Missing required fields (name, kind, amount, currency, payDay, startDate) are each rejected individually")
    func missingRequiredFieldsAreRejected() {
        let cases: [String] = [
            #"{"kind":"subscription","amount":1,"currency":"USD","payDay":1,"startDate":"2026-01-01"}"#, // no name
            #"{"name":"X","amount":1,"currency":"USD","payDay":1,"startDate":"2026-01-01"}"#, // no kind
            #"{"name":"X","kind":"subscription","currency":"USD","payDay":1,"startDate":"2026-01-01"}"#, // no amount
            #"{"name":"X","kind":"subscription","amount":1,"payDay":1,"startDate":"2026-01-01"}"#, // no currency
            #"{"name":"X","kind":"subscription","amount":1,"currency":"USD","startDate":"2026-01-01"}"#, // no payDay
            #"{"name":"X","kind":"subscription","amount":1,"currency":"USD","payDay":1}"#, // no startDate
        ]
        for jsonItem in cases {
            let file = "{\"version\":1,\"items\":[\(jsonItem)]}"
            let result = SubscriptionImportService.parse(data: file.data(using: .utf8)!)
            #expect(result.valid.isEmpty, "expected rejection for: \(jsonItem)")
            #expect(result.issues.count == 1)
        }
    }

    @Test("amount outside ValidationRange.amount (e.g. 0) is rejected")
    func amountOutOfRangeIsRejected() {
        let file = #"{"version":1,"items":[{"name":"X","kind":"subscription","amount":0,"currency":"USD","payDay":1,"startDate":"2026-01-01"}]}"#
        let result = SubscriptionImportService.parse(data: file.data(using: .utf8)!)
        #expect(result.valid.isEmpty)
        #expect(result.issues.count == 1)
    }

    @Test("An impossible calendar date (Feb 30) is rejected, not silently clamped")
    func impossibleDateIsRejected() {
        let file = #"{"version":1,"items":[{"name":"X","kind":"subscription","amount":1,"currency":"USD","payDay":1,"startDate":"2026-02-30"}]}"#
        let result = SubscriptionImportService.parse(data: file.data(using: .utf8)!)
        #expect(result.valid.isEmpty)
    }

    @Test("isActive defaults to true when absent, and is honored when false")
    func isActiveDefaultsTrueAndIsHonoredWhenFalse() {
        let file = """
        {"version":1,"items":[
            {"name":"NoFlag","kind":"subscription","amount":1,"currency":"USD","payDay":1,"startDate":"2026-01-01"},
            {"name":"Inactive","kind":"subscription","amount":1,"currency":"USD","payDay":1,"startDate":"2026-01-01","isActive":false}
        ]}
        """
        let result = SubscriptionImportService.parse(data: file.data(using: .utf8)!)
        #expect(result.valid.count == 2)
        #expect(result.valid.first { $0.name == "NoFlag" }?.isActive == true)
        #expect(result.valid.first { $0.name == "Inactive" }?.isActive == false)
    }

    @Test("Currency is matched case-insensitively")
    func currencyIsCaseInsensitive() {
        let file = #"{"version":1,"items":[{"name":"X","kind":"subscription","amount":1,"currency":"usd","payDay":1,"startDate":"2026-01-01"}]}"#
        let result = SubscriptionImportService.parse(data: file.data(using: .utf8)!)
        #expect(result.valid.first?.currency == .usd)
    }
}

/// `PeriodCoordinator.importSubscriptions` — the SwiftData-touching half: persistence, dedupe
/// by name, isActive respected by projection, and the combined-line reprojection this must
/// trigger for both kinds.
@MainActor
@Suite("PeriodCoordinator.importSubscriptions")
struct SubscriptionImportPersistenceTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV2.models)
        let configuration = ModelConfiguration(schema: schema, url: URL.temporaryDirectory.appending(path: UUID().uuidString + ".sqlite"))
        let container = try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: [configuration])
        return ModelContext(container)
    }

    private func item(
        name: String, kind: SubscriptionKind = .subscription, amount: Decimal = 10,
        payDay: Int = 5, start: CivilDate = CivilDate(year: 2026, month: 1, day: 1),
        isActive: Bool = true
    ) -> SubscriptionImportService.ValidatedItem {
        SubscriptionImportService.ValidatedItem(
            name: name, kind: kind, amount: amount, currency: .usd, payDay: payDay,
            startDate: start, endDate: nil, isActive: isActive, paymentMethod: "Apple Card",
            subscriptionCategory: .tools, homeServiceCategory: .rent
        )
    }

    @Test("A brand-new item is inserted; importing the same name again updates it, not duplicates it")
    func newItemInsertedThenDedupedByNameOnReimport() throws {
        let context = try makeContext()

        let first = PeriodCoordinator.importSubscriptions([item(name: "Netflix", amount: 15)], context: context, exchangeRate: 18)
        #expect(first.imported == 1)
        #expect(first.updated == 0)

        let second = PeriodCoordinator.importSubscriptions([item(name: "Netflix", amount: 20)], context: context, exchangeRate: 18)
        #expect(second.imported == 0)
        #expect(second.updated == 1)

        let all = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        #expect(all.count == 1)
        #expect(all.first?.price == 20)
    }

    @Test("A service-kind item is created with the right kind and category, and is queryable via reprojectSubscription")
    func serviceKindItemProjectsIntoServicios() throws {
        let context = try makeContext()
        let coordinate = PeriodCoordinate(year: 2026, month: 1, half: .first)
        let period = PeriodCoordinator.materializeIfNeeded(coordinate: coordinate, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)

        PeriodCoordinator.importSubscriptions([
            item(name: "Luz", kind: .service, amount: 82, payDay: 12, start: CivilDate(year: 2026, month: 1, day: 1)),
        ], context: context, exchangeRate: 18)

        let servicios = (period.lineItems ?? []).filter { $0.origin == .subscription && $0.isHomeService }
        #expect(servicios.count == 1)
        #expect(servicios.first?.amount == 82)
    }

    @Test("isActive: false imports the row but never generates a projected line")
    func inactiveImportedItemNeverProjects() throws {
        let context = try makeContext()
        let coordinate = PeriodCoordinate(year: 2026, month: 1, half: .first)
        let period = PeriodCoordinator.materializeIfNeeded(coordinate: coordinate, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)

        let summary = PeriodCoordinator.importSubscriptions([
            item(name: "Infuse", amount: 1, payDay: 1, start: CivilDate(year: 2026, month: 1, day: 1), isActive: false),
        ], context: context, exchangeRate: 18)
        #expect(summary.imported == 1)

        let all = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        #expect(all.first?.isActive == false)

        let paymentsLine = (period.lineItems ?? []).first { $0.origin == .subscription && !$0.isHomeService }
        #expect(paymentsLine == nil, "an inactive subscription must never generate a projected line")
    }

    @Test("skippedCount passes through to the summary unchanged")
    func skippedCountPassesThrough() throws {
        let context = try makeContext()
        let summary = PeriodCoordinator.importSubscriptions([], context: context, exchangeRate: 18, skippedCount: 3)
        #expect(summary.imported == 0)
        #expect(summary.updated == 0)
        #expect(summary.skipped == 3)
    }
}
