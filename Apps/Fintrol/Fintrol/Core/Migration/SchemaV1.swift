import SwiftData

public enum SchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [Period.self, LineItem.self, RecurringItem.self, Subscription.self, Loan.self, ExchangeRateCache.self]
    }
}
