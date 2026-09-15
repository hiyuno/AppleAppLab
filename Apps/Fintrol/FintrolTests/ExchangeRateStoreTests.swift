import Testing
import Foundation
import SwiftData
@testable import Fintrol

/// SECURITY_AUDIT.md M-01: `applyManualOverride` must reject values outside
/// `ExchangeRateParser.plausibleRange` instead of persisting them silently.
@MainActor
@Suite("ExchangeRateStore — manual override validation (M-01)")
struct ExchangeRateStoreTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @Test("A value below the plausible range is rejected and not persisted")
    func rejectsTooLow() throws {
        let context = try makeContext()
        let store = ExchangeRateStore()

        let accepted = store.applyManualOverride(Decimal(string: "0.5")!, context: context)

        #expect(accepted == false)
        #expect(store.lastManualOverrideError == .outOfRange)
        #expect(store.currentRate == nil)
        let cached = try context.fetch(FetchDescriptor<ExchangeRateCache>())
        #expect(cached.isEmpty)
    }

    @Test("A value above the plausible range is rejected and not persisted")
    func rejectsTooHigh() throws {
        let context = try makeContext()
        let store = ExchangeRateStore()

        let accepted = store.applyManualOverride(Decimal(string: "999999")!, context: context)

        #expect(accepted == false)
        #expect(store.lastManualOverrideError == .outOfRange)
        #expect(store.currentRate == nil)
        let cached = try context.fetch(FetchDescriptor<ExchangeRateCache>())
        #expect(cached.isEmpty)
    }

    @Test("A plausible value is accepted and persisted as the cache row")
    func acceptsPlausibleValue() throws {
        let context = try makeContext()
        let store = ExchangeRateStore()

        let accepted = store.applyManualOverride(Decimal(string: "18.50")!, context: context)

        #expect(accepted == true)
        #expect(store.lastManualOverrideError == nil)
        #expect(store.currentRate == Decimal(string: "18.50")!)
        let cached = try context.fetch(FetchDescriptor<ExchangeRateCache>())
        #expect(cached.count == 1)
        #expect(cached.first?.rate == Decimal(string: "18.50")!)
        #expect(cached.first?.fetchedFromAPI == false)
    }

    @Test("A rejected override does not overwrite a previously valid cached rate")
    func rejectedOverrideDoesNotClobberExistingCache() throws {
        let context = try makeContext()
        let store = ExchangeRateStore()

        #expect(store.applyManualOverride(Decimal(string: "20.00")!, context: context) == true)
        #expect(store.applyManualOverride(Decimal(string: "16200")!, context: context) == false)

        let cached = try context.fetch(FetchDescriptor<ExchangeRateCache>())
        #expect(cached.count == 1)
        #expect(cached.first?.rate == Decimal(string: "20.00")!)
        #expect(store.currentRate == Decimal(string: "20.00")!)
    }
}
