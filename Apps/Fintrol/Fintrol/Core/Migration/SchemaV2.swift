import SwiftData

/// FIN-2026 (Avie): `SchemaV1` was edited in place after it had already shipped (its
/// `versionIdentifier` stayed `1.0.0` through the CivilDate refactor) — SwiftData's
/// lightweight-migration machinery identifies a schema by that version, not by its actual
/// shape, so silently changing V1's shape under the same identifier is exactly the situation
/// that produces an unrecoverable mismatch against an on-disk store created from the real,
/// original V1. From here on, ANY future change to the persisted model shape must land as a
/// new `SchemaVN`, never as an in-place edit of an existing one.
///
/// The model shape itself has not changed since V1 (the CivilDate refactor only added
/// computed properties — `civilStartDate`/`civilEndDate` — which SwiftData never persists);
/// V2 exists purely to give `AppMigrationPlan` a real, versioned stage to migrate through, so
/// the next actual shape change has a clean V2→V3 stage to land in instead of repeating this
/// mistake.
public enum SchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [Period.self, LineItem.self, RecurringItem.self, Subscription.self, Loan.self, CreditCard.self, ExchangeRateCache.self, SubscriptionCategoryItem.self]
    }
}
