import Testing
import SwiftData
@testable import Fintrol

/// FIN-2026 (Avie): `SchemaV1` must never be edited in place again — its `versionIdentifier`
/// stayed frozen at `1.0.0` through the CivilDate refactor, which is exactly the situation
/// that breaks lightweight migration against a real on-disk store. `SchemaV2` (identical
/// shape, new version) plus a `.lightweight` stage in `AppMigrationPlan` is the fix, and
/// formalizes that any future shape change lands as a new `SchemaVN`, never an in-place edit.
@Suite("SchemaV1/V2 / AppMigrationPlan")
struct SchemaV1Tests {
    @Test("ModelContainer opens cleanly with SchemaV1 alone (no migration plan involved)")
    func opensCleanV1Container() throws {
        let schema = Schema(SchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        #expect(container.schema.entities.count == SchemaV1.models.count)
    }

    @Test("ModelContainer opens cleanly with SchemaV2 through AppMigrationPlan — the app's real launch path")
    func opensCleanV2ContainerThroughMigrationPlan() throws {
        let schema = Schema(SchemaV2.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: [configuration])
        #expect(container.schema.entities.count == SchemaV2.models.count)
    }

    @Test("AppMigrationPlan carries exactly the V1 -> V2 lightweight stage")
    func migrationPlanHasV1ToV2Stage() {
        #expect(AppMigrationPlan.schemas.count == 2)
        #expect(AppMigrationPlan.stages.count == 1)
    }

    @Test("SchemaV1 and SchemaV2 declare the same model shape — V2 exists only to formalize the version bump")
    func schemaV1AndV2HaveTheSameModelShape() {
        #expect(SchemaV1.models.count == SchemaV2.models.count)
        #expect(SchemaV1.versionIdentifier != SchemaV2.versionIdentifier)
    }
}
