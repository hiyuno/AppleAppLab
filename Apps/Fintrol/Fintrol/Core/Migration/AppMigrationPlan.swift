import SwiftData

/// Pre-release (no shipped installs to migrate yet): the schema evolves in place on
/// `SchemaV2` with no real migration graph. `SchemaV1` still exists (a couple of tests build
/// an isolated in-memory container directly from it) but is deliberately **not** part of this
/// plan.
///
/// Why: `SchemaV1` and `SchemaV2` reference the exact same live model types (`Subscription`,
/// `Loan`, …) rather than each declaring its own nested copy of the shape it represents — so
/// any shape change to those types (e.g. `Subscription.isActive`, added post-v1) changes
/// BOTH schemas' computed hash identically, always, regardless of their declared
/// `versionIdentifier`. A `.lightweight` stage between two versions whose hashes always match
/// crashes SwiftData at container open the moment a real on-disk store needs migrating
/// ("Duplicate version checksums detected" — reproduced when `Subscription.isActive` was
/// added while `AppMigrationPlan` still listed a `SchemaV1 -> SchemaV2` stage). Since the app
/// has no real users yet, the fix is simply to stop pretending there's a migration: `FintrolApp`
/// opens the store directly at `SchemaV2`'s current shape, in place, no stage needed.
///
/// Once the app ships, any further shape change must introduce a genuinely distinct
/// `SchemaV3` — with its own nested model type declarations, not a re-export of the live
/// ones — paired with a real migration stage; this shared-type pattern cannot support that
/// until then.
public enum AppMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [SchemaV2.self] }
    public static var stages: [MigrationStage] { [] }
}
