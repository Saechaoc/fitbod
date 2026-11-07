//
//  SettingsUnitsIntegrationTests.swift
//  fitbodTests
//
//  Wave-4 plan 04-01 — SET-01 integration anchor. Proves the lb → kg
//  toggle persists across a re-fetched `ModelContext` so the
//  `SettingsView`'s `@Bindable` Toggle write-through actually survives
//  an app relaunch.
//
//  The `UserSettingsTests` suite (plan 01-03) already covers the
//  in-memory round-trip via the computed `weightUnit` setter — this
//  test adds the cross-context fetch step (mimicking the "close the
//  app, reopen, the setting is still kg" flow that's load-bearing
//  for SET-01's user-visible contract).
//

import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import fitbod

@Suite("SettingsView units toggle (SET-01 integration)", .serialized)
struct SettingsUnitsIntegrationTests {

    /// Flipping `weightUnit` on `UserSettings` and saving the context
    /// persists the change across a fresh `ModelContext` (same
    /// `ModelContainer`, different context — the closest in-process
    /// analog to "relaunch the app and the setting is still kg").
    @Test("Flipping weightUnit on UserSettings persists across re-fetched ModelContext (SET-01)")
    func unitsTogglePersists() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)

        // Seed the singleton row via the production factory.
        let settings = UserSettings.default()
        ctx.insert(settings)
        try ctx.save()

        // Initial state: lb (factory default).
        #expect(settings.weightUnit == .lb)
        #expect(settings.unitsRaw == "lb")

        // Flip to kg — this is the same code path `SettingsView`'s
        // Toggle setter invokes (`s.weightUnit = newValue ? .kg : .lb`).
        settings.weightUnit = .kg
        try ctx.save()

        // Re-fetch from a fresh ModelContext (same container) — the
        // analog of "relaunch the app, read the setting again".
        let fresh = ModelContext(container)
        let fetched = try fresh.fetch(FetchDescriptor<UserSettings>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.weightUnit == .kg)
        #expect(fetched.first?.unitsRaw == "kg")
    }

    /// And back again — flipping kg → lb persists. Ensures the
    /// Binding's set closure works in both directions, not just the
    /// forward (lb → kg) case.
    @Test("Flipping weightUnit kg → lb also persists across re-fetched ModelContext")
    func unitsToggleReversePersists() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)

        let settings = UserSettings.default()
        settings.weightUnit = .kg
        ctx.insert(settings)
        try ctx.save()
        #expect(settings.weightUnit == .kg)

        // Toggle back to lb.
        settings.weightUnit = .lb
        try ctx.save()

        let fresh = ModelContext(container)
        let fetched = try fresh.fetch(FetchDescriptor<UserSettings>())
        #expect(fetched.first?.weightUnit == .lb)
        #expect(fetched.first?.unitsRaw == "lb")
    }

    @MainActor
    @Test("summary set rows respect exercise overrides in both unit directions",
          .hostedAccessibility, arguments: [WeightUnit.lb, .kg])
    func summaryUsesExerciseUnitOverride(global: WeightUnit) throws {
        let ctx = try LoggerFixtures.makeContext()
        let exercise = LoggerFixtures.exercise("Override Bench", in: ctx)
        let override: WeightUnit = global == .lb ? .kg : .lb
        exercise.unitOverride = override
        let yesterday = Date.now.addingTimeInterval(-86_400)
        let workout = try LoggerFixtures.session(
            exercise: exercise, startedAt: yesterday, completedAt: yesterday.addingTimeInterval(3_600),
            sets: [(100, 5, true)], in: ctx
        )
        let window = try HostedAccessibility.show(
            NavigationStack { SessionDetailView(session: workout) }
                .modelContainer(ctx.container)
                .environment(\.weightUnit, global)
        )
        defer { window.isHidden = true }
        func labels() -> [String] {
            HostedAccessibility.elements(under: window).compactMap {
                HostedAccessibility.property("accessibilityLabel", of: $0) as? String
            }
        }
        HostedAccessibility.waitUntil { labels().contains { $0.contains("Set 1,") } }
        let rendered = labels()
        try #require(rendered.contains { $0.contains("Set 1,") }, "The set row must have rendered")
        #expect(rendered.contains { $0.contains("100 \(override.rawValue) by 5") }, "Rendered labels: \(rendered)")
        #expect(hasExerciseVolume("500 \(override.rawValue)", in: rendered))
        #expect(workout.exercises?.first?.sets?.first?.weight == 100)
    }

    @MainActor
    @Test("summary lines resolve overrides by SessionExercise identity, not a shared snapshot name", .hostedAccessibility)
    func summaryResolvesDuplicateNamesByID() throws {
        let ctx = try LoggerFixtures.makeContext()
        let workout = try finishedWorkout(override: .kg, in: ctx)
        let first = try #require(workout.exercises?.first)
        first.exerciseNameSnapshot = "Same frozen name"
        let second = SessionExercise()
        ctx.insert(second)
        second.session = workout
        second.orderIndex = 1
        second.exercise = LoggerFixtures.exercise("Other catalog exercise", in: ctx)
        second.exercise?.unitOverride = .lb
        second.exerciseNameSnapshot = "Same frozen name"
        let set = SetEntry()
        ctx.insert(set)
        set.sessionExercise = second
        set.weight = 75
        set.reps = 8
        set.isComplete = true
        try ctx.save()
        let window = try HostedAccessibility.show(
            NavigationStack { SessionDetailView(session: workout) }
                .modelContainer(ctx.container)
                .environment(\.weightUnit, .lb)
        )
        defer { window.isHidden = true }
        HostedAccessibility.waitUntil { labels(under: window).contains { $0.contains("75 lb by 8") } }
        let rendered = labels(under: window)
        #expect(rendered.contains { $0.contains("100 kg by 5") })
        #expect(rendered.contains { $0.contains("75 lb by 8") })
        #expect(hasExerciseVolume("500 kg", in: rendered))
        #expect(hasExerciseVolume("600 lb", in: rendered))
    }

    @MainActor
    @Test("missing overrides and removed catalog exercises use the environment unit",
          .hostedAccessibility, arguments: [false, true])
    func summaryAndDraftFallbackToGlobal(missingCatalogExercise: Bool) throws {
        let ctx = try LoggerFixtures.makeContext()
        let workout = try finishedWorkout(override: nil, in: ctx)
        let exercise = try #require(workout.exercises?.first)
        if missingCatalogExercise { exercise.exercise = nil }
        try ctx.save()
        let draft = WorkoutEditDraft(session: workout)
        #expect(draft.exercises.first?.unitOverride == nil)
        let window = try HostedAccessibility.show(
            NavigationStack { SessionDetailView(session: workout) }
                .modelContainer(ctx.container)
                .environment(\.weightUnit, .kg)
        )
        defer { window.isHidden = true }
        HostedAccessibility.waitUntil { labels(under: window).contains { $0.contains("Set 1,") } }
        let rendered = labels(under: window)
        #expect(rendered.contains { $0.contains("100 kg by 5") })
        #expect(hasExerciseVolume("500 kg", in: rendered))
        #expect(exercise.sets?.first?.weight == 100)
    }

    @MainActor
    @Test("editor volume uses transient override metadata and saving never converts weight",
          .hostedAccessibility, arguments: [WeightUnit.lb, .kg])
    func editorUsesEffectiveUnitWithoutConversion(global: WeightUnit) throws {
        let ctx = try LoggerFixtures.makeContext()
        let override: WeightUnit = global == .lb ? .kg : .lb
        let workout = try finishedWorkout(override: override, in: ctx)
        var draft = WorkoutEditDraft(session: workout)
        #expect(draft.exercises.first?.unitOverride == override)
        #expect(!draft.hasChanges)
        let window = try HostedAccessibility.show(
            NavigationStack { WorkoutEditView(session: workout, onDeleted: {}) }
                .modelContainer(ctx.container)
                .environment(\.weightUnit, global)
        )
        defer { window.isHidden = true }
        HostedAccessibility.waitUntil { hasExerciseVolume("500 \(override.rawValue)", in: labels(under: window)) }
        #expect(hasExerciseVolume("500 \(override.rawValue)", in: labels(under: window)))
        #expect(workout.exercises?.first?.sets?.first?.weight == 100)

        draft.exercises[0].rows[0].values.reps = 6
        try SessionEditService.save(draft.edit, to: workout, context: ctx)
        let fresh = ModelContext(ctx.container)
        let stored = try #require(try fresh.fetch(FetchDescriptor<SetEntry>()).first)
        #expect(stored.weight == 100 && stored.reps == 6)
        #expect(stored.sessionExercise?.exercise?.unitOverride == override)
    }

    @MainActor
    @Test("editor without an override falls back to the current environment unit", .hostedAccessibility)
    func editorFallsBackToGlobal() throws {
        let ctx = try LoggerFixtures.makeContext()
        let workout = try finishedWorkout(override: nil, in: ctx)
        let window = try HostedAccessibility.show(
            NavigationStack { WorkoutEditView(session: workout, onDeleted: {}) }
                .modelContainer(ctx.container)
                .environment(\.weightUnit, .kg)
        )
        defer { window.isHidden = true }
        HostedAccessibility.waitUntil { hasExerciseVolume("500 kg", in: labels(under: window)) }
        #expect(hasExerciseVolume("500 kg", in: labels(under: window)))
    }

    @MainActor
    @Test("the summary safely renders unsupported historical aggregate volume", .hostedAccessibility)
    func summarySafelyRendersUnsupportedVolume() throws {
        let ctx = try LoggerFixtures.makeContext()
        let workout = try finishedWorkout(override: .kg, in: ctx)
        let set = try #require(workout.exercises?.first?.sets?.first)
        set.weight = 1e19
        try ctx.save()
        let window = try HostedAccessibility.show(
            NavigationStack { SessionDetailView(session: workout) }
                .modelContainer(ctx.container)
                .environment(\.weightUnit, .lb)
        )
        defer { window.isHidden = true }
        HostedAccessibility.waitUntil { labels(under: window).contains { $0.contains("Set 1,") } }
        #expect(hasExerciseVolume("— kg", in: labels(under: window)))
        #expect(set.weight == 1e19)
    }

    @MainActor
    private func finishedWorkout(override: WeightUnit?, in ctx: ModelContext) throws -> Session {
        let exercise = LoggerFixtures.exercise("Override Bench", in: ctx)
        exercise.unitOverride = override
        let yesterday = Date.now.addingTimeInterval(-86_400)
        return try LoggerFixtures.session(
            exercise: exercise, startedAt: yesterday, completedAt: yesterday.addingTimeInterval(3_600),
            sets: [(100, 5, true)], in: ctx
        )
    }

    @MainActor
    private func labels(under root: NSObject) -> [String] {
        HostedAccessibility.elements(under: root).compactMap {
            HostedAccessibility.property("accessibilityLabel", of: $0) as? String
        }
    }

    private func hasExerciseVolume(_ value: String, in labels: [String]) -> Bool {
        labels.contains { $0.localizedCaseInsensitiveContains("1 set") && $0.localizedCaseInsensitiveContains(value) }
    }
}
