import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
struct SettingsResetTests {
    enum Failure: Error { case disk }

    @Test func plateResetRollsBackAndRetries() throws {
        let ctx = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let inventory = PlateInventory()
        ctx.insert(inventory)
        inventory.barWeight = 17
        inventory.availablePlates = [PlateSpec(weight: 3, countPerSide: 4)]
        inventory.updatedAt = .distantPast
        try ctx.save()
        let original = inventory.availablePlatesData

        #expect(throws: Failure.self) {
            try PlateInventoryEditor.reset(inventory, unit: .kg, context: ctx, save: { _ in throw Failure.disk })
        }
        #expect(!ctx.hasChanges)
        #expect(inventory.barWeight == 17)
        #expect(inventory.availablePlatesData == original)
        #expect(inventory.updatedAt == .distantPast)
        let reader = ModelContext(ctx.container)
        let before = try #require(try reader.fetch(FetchDescriptor<PlateInventory>()).first)
        #expect(before.barWeight == 17 && before.availablePlatesData == original)

        try PlateInventoryEditor.reset(inventory, unit: .kg, context: ctx)
        let after = try #require(try ModelContext(ctx.container).fetch(FetchDescriptor<PlateInventory>()).first)
        #expect(after.barWeight == PlateInventoryDefaults.barWeight(for: .barbell, unitSystem: .kg))
        #expect(after.availablePlates == PlateInventoryDefaults.make(for: .barbell, unitSystem: .kg))
        #expect(after.updatedAt > .distantPast)
    }

    @Test func allVolumeResetsRollBackAndRetryTogether() throws {
        let ctx = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let targets = ["chest", "lats"].map { slug in
            let muscle = MuscleGroup()
            ctx.insert(muscle)
            muscle.slug = slug
            let target = MuscleVolumeTarget()
            ctx.insert(target)
            target.muscle = muscle
            target.mv = 11
            target.mev = 12
            target.mav = 13
            target.mrv = 14
            target.userEdited = true
            return target
        }
        try ctx.save()

        #expect(throws: Failure.self) {
            try MuscleVolumeTargetEditor.reset(targets, context: ctx, save: { _ in throw Failure.disk })
        }
        #expect(!ctx.hasChanges)
        for target in targets {
            #expect(target.mv == 11 && target.mev == 12 && target.mav == 13 && target.mrv == 14)
            #expect(target.userEdited)
        }
        let before = try ModelContext(ctx.container).fetch(FetchDescriptor<MuscleVolumeTarget>())
        #expect(before.count == 2 && before.allSatisfy { $0.mrv == 14 && $0.userEdited })

        try MuscleVolumeTargetEditor.reset(targets, context: ctx)
        let after = try ModelContext(ctx.container).fetch(FetchDescriptor<MuscleVolumeTarget>())
        for target in after {
            let defaults = RPVolumeLandmarks.landmark(for: try #require(target.muscle?.slug))
            #expect(target.mv == defaults.mv && target.mev == defaults.mev && target.mav == defaults.mav && target.mrv == defaults.mrv)
            #expect(!target.userEdited)
        }
    }
}
