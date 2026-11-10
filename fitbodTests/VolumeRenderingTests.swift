import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import fitbod

@MainActor
@Suite(.serialized)
struct VolumeRenderingTests {
    enum Screen: CaseIterable { case surface, detail }

    @Test(arguments: Screen.allCases)
    func missingTargetsRenderWithoutModelChanges(_ screen: Screen) async throws {
        let container = try FitbodModelContainer.make(inMemory: true)
        let ctx = container.mainContext
        ctx.autosaveEnabled = false
        let muscle = MuscleGroup(slug: "chest", displayName: "Chest")
        ctx.insert(muscle)
        let lift = LoggerFixtures.exercise("Bench", in: ctx)
        let stimulus = ExerciseMuscleStimulus()
        ctx.insert(stimulus)
        stimulus.exercise = lift
        stimulus.muscle = muscle
        try LoggerFixtures.session(exercise: lift, startedAt: .now, completedAt: .now,
                                   sets: [(50, 5, true)], in: ctx)
        try ctx.save()
        let content = switch screen {
        case .surface: AnyView(FatigueSurfaceView())
        case .detail: AnyView(PerMuscleDetailView(muscleSlug: "chest"))
        }
        let host = UIHostingController(rootView: content.modelContainer(container))
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 1100)
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        try await Task.sleep(for: .milliseconds(200))
        host.view.layoutIfNeeded()
        _ = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        #expect(!ctx.hasChanges)
        #expect(ctx.insertedModelsArray.isEmpty)
        #expect((muscle.volumeTargets ?? []).isEmpty)
        #expect(try ctx.fetchCount(FetchDescriptor<MuscleVolumeTarget>()) == 0)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<MuscleVolumeTarget>()) == 0)
    }
    @Test func explicitCreationRollsBackAndRetriesWithoutDuplicates() throws {
        enum Failure: Error { case disk }
        let ctx = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let muscle = MuscleGroup(slug: "chest", displayName: "Chest")
        ctx.insert(muscle)
        try ctx.save()
        #expect(throws: Failure.self) {
            try PerMuscleDetailView.createTarget(for: muscle, context: ctx, save: { _ in throw Failure.disk })
        }
        #expect(!ctx.hasChanges)
        #expect((muscle.volumeTargets ?? []).isEmpty)
        #expect(try ctx.fetchCount(FetchDescriptor<MuscleVolumeTarget>()) == 0)

        let target = try PerMuscleDetailView.createTarget(for: muscle, context: ctx)
        #expect(RPVolumeLandmarks.Landmark(target) == RPVolumeLandmarks.landmark(for: "chest"))
        #expect(target.mv <= target.mev && target.mev < target.mav && target.mav < target.mrv)
        #expect(try PerMuscleDetailView.createTarget(for: muscle, context: ctx).id == target.id)
        #expect(try ModelContext(ctx.container).fetchCount(FetchDescriptor<MuscleVolumeTarget>()) == 1)
    }

}
