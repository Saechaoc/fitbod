//
//  PreviewModelContainer.swift
//  fitbod
//
//  In-memory `ModelContainer` factory shared by SwiftUI `#Preview`
//  blocks AND the Swift Testing unit suites under `fitbodTests/`.
//  Returns a container backed by `ModelConfiguration(isStoredInMemoryOnly: true)`
//  so previews and tests never touch the on-disk store.
//
//  When called with `seedFixture: true` (the default), the container is
//  pre-populated with a deterministic mini-fixture: 4 `MuscleGroup` rows
//  (chest / triceps / lats / biceps), 2 `Exercise` rows (Barbell Bench
//  Press, Barbell Row), their stimulus join rows (primary 1.0 / secondary
//  0.5), and a single `UserSettings` row. This is enough surface for the
//  Wave-3 library / settings previews to render real data without
//  bundling the full `exercises.json` seed.
//
//  Tests that want a hermetic empty container should use
//  `InMemoryContainer.makeEmpty()` from the test-target helper instead
//  (or `PreviewModelContainer.make(seedFixture: false)` from the
//  production target).
//
//  Pattern source: RESEARCH § Pattern 8 — Apple's documented in-memory
//  preview container pattern. The `try!` is intentional — failure to
//  build an in-memory container with the locked SchemaV1 is a programmer
//  error (the schema is verified at runtime via SchemaV1Tests).
//

import Foundation
import SwiftData

public enum PreviewModelContainer {
    /// Builds a fresh in-memory `ModelContainer` over `SchemaV1`.
    ///
    /// - Parameter seedFixture: when `true` (default), inserts a
    ///   deterministic 4-muscle / 2-exercise / 1-settings fixture.
    ///   Set to `false` for previews that want the empty store
    ///   (e.g. "first-launch importing…" placeholder).
    public static func make(seedFixture: Bool = true) -> ModelContainer {
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true
        )
        let container = try! ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        if seedFixture {
            seed(into: container.mainContext)
        }
        return container
    }

    /// Deterministic mini-fixture for previews. Inserts 4 muscles,
    /// 2 exercises, their stimulus join rows, and a default
    /// `UserSettings` row. Order is fixed so previews are reproducible.
    private static func seed(into ctx: ModelContext) {
        let chest = MuscleGroup(slug: "chest",   displayName: "Chest",   region: .upper)
        let tris  = MuscleGroup(slug: "triceps", displayName: "Triceps", region: .upper)
        let lats  = MuscleGroup(slug: "lats",    displayName: "Lats",    region: .upper)
        let biceps = MuscleGroup(slug: "biceps", displayName: "Biceps",  region: .upper)
        [chest, tris, lats, biceps].forEach { ctx.insert($0) }

        let bench = Exercise.previewSample(
            name: "Barbell Bench Press",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["chest"]
        )
        ctx.insert(bench)
        ctx.insert(ExerciseMuscleStimulus(exercise: bench, muscle: chest, role: "primary",   weight: 1.0))
        ctx.insert(ExerciseMuscleStimulus(exercise: bench, muscle: tris,  role: "secondary", weight: 0.5))

        let row = Exercise.previewSample(
            name: "Barbell Row",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["lats"]
        )
        ctx.insert(row)
        ctx.insert(ExerciseMuscleStimulus(exercise: row, muscle: lats,   role: "primary",   weight: 1.0))
        ctx.insert(ExerciseMuscleStimulus(exercise: row, muscle: biceps, role: "secondary", weight: 0.5))

        ctx.insert(UserSettings.default())
        try? ctx.save()
    }
}
