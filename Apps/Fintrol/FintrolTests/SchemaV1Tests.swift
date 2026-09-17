import Testing
import Foundation
import SwiftData
@testable import Fintrol

/// `SchemaV1`/`SchemaV2`/`AppMigrationPlan` — see `AppMigrationPlan.swift` for the full
/// history: `SchemaV1` and `SchemaV2` reference the same live model types, so a real
/// `.lightweight` migration stage between them crashes SwiftData ("Duplicate version
/// checksums detected") the moment the shape actually changes (reproduced when
/// `Subscription.isActive` was added). Pre-release, `AppMigrationPlan` carries only
/// `SchemaV2` with no stages — the schema evolves in place until the app ships.
@Suite("SchemaV1/V2 / AppMigrationPlan")
struct SchemaV1Tests {
    @Test("ModelContainer opens cleanly with SchemaV1 alone (no migration plan involved)")
    func opensCleanV1Container() throws {
        let schema = Schema(SchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, url: URL.temporaryDirectory.appending(path: UUID().uuidString + ".sqlite"))
        let container = try ModelContainer(for: schema, configurations: [configuration])
        #expect(container.schema.entities.count == SchemaV1.models.count)
    }

    @Test("ModelContainer opens cleanly with SchemaV2 through AppMigrationPlan — the app's real launch path")
    func opensCleanV2ContainerThroughMigrationPlan() throws {
        let schema = Schema(SchemaV2.models)
        let configuration = ModelConfiguration(schema: schema, url: URL.temporaryDirectory.appending(path: UUID().uuidString + ".sqlite"))
        let container = try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: [configuration])
        #expect(container.schema.entities.count == SchemaV2.models.count)
    }

    @Test("AppMigrationPlan carries only SchemaV2, no migration stages — pre-release, in-place evolution")
    func migrationPlanHasNoStages() {
        #expect(AppMigrationPlan.schemas.count == 1)
        #expect(AppMigrationPlan.schemas.first is SchemaV2.Type)
        #expect(AppMigrationPlan.stages.isEmpty)
    }

    @Test("SchemaV1 and SchemaV2 declare the same model types (they share live model classes, not independent shapes)")
    func schemaV1AndV2ShareModelTypes() {
        #expect(SchemaV1.models.count == SchemaV2.models.count)
        #expect(SchemaV1.versionIdentifier != SchemaV2.versionIdentifier)
    }
}
