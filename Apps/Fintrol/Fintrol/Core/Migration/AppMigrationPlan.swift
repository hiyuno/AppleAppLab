import SwiftData

/// `SchemaV1` → `SchemaV2` (FIN-2026, Avie): V2 exists only to formalize a version bump —
/// the persisted model shape is unchanged, so a `.lightweight` stage (SwiftData infers the
/// mapping automatically) is exactly right. `FintrolApp` now opens the store at `SchemaV2`;
/// this plan carries any existing V1 store forward through that stage.
public enum AppMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    public static var stages: [MigrationStage] { [migrateV1toV2] }

    static let migrateV1toV2 = MigrationStage.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
}
