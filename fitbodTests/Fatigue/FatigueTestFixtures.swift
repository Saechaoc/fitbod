//
//  FatigueTestFixtures.swift
//  fitbodTests
//
//  Shared in-memory fixture factory for every Phase 5 Fatigue test
//  suite. Wave 0 ships two fully-implemented helpers — `makeContext()`
//  and `weeklySessions(...)` — that downstream plans 02, 03, 04, 06
//  build their GREEN tests on. The 11 named edge-case factories
//  (matching RESEARCH §4 table) ship as signatures + `fatalError` stubs
//  this plan so that any downstream test calling them prematurely
//  crashes loudly instead of silently passing.
//
//  Pattern mirrors `PreviousMatchingIntentTests.makeContext()` and
//  `InMemoryContainer.makeCurrent()`: FitbodModelContainer.make(inMemory: true) +
//  FitbodModelContainer.make over an in-memory ModelContainer.
//

import Foundation
import SwiftData
@testable import fitbod

@MainActor
enum FatigueTestFixtures {

    // MARK: - Container

    /// Fresh in-memory V6 ModelContext over FitbodModelContainer.make(inMemory: true) +
    /// FitbodModelContainer.make. Mirrors PreviousMatchingIntentTests
    /// shape verbatim; swap V5→V6.
    static func makeContext() throws -> ModelContext {
        let container = try FitbodModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    // MARK: - Weekly sessions builder

    /// Build a deterministic in-memory week of working sets for one
    /// exercise at one intent. Each weight[i] / reps[i] pair becomes a
    /// `Session` started on `weekStart + i*86400` seconds, with one
    /// `SessionExercise` and one working-set `SetEntry`.
    ///
    /// - Parameters:
    ///   - exercise: Pre-inserted Exercise to attach. Caller is
    ///     responsible for inserting + saving the Exercise into the
    ///     context first (so its id is stable).
    ///   - weights: One weight per session. Length determines session count.
    ///   - reps: One rep count per session. Must equal weights.count.
    ///   - rpe: Optional per-session RPE; empty array means "no RPE
    ///     logged". Otherwise must equal weights.count.
    ///   - intent: Session-level intent (PIVOT-02 lives on Session, not
    ///     SessionExercise).
    ///   - weekStart: Date anchor; session i is `weekStart + i*86400`.
    ///   - context: ModelContext to insert into.
    /// - Returns: The created Sessions in insertion order.
    @discardableResult
    static func weeklySessions(
        forExercise exercise: Exercise,
        weights: [Double],
        reps: [Int],
        rpe: [Double?] = [],
        intent: Intent = .strength,
        weekStart: Date,
        in context: ModelContext
    ) throws -> [Session] {
        precondition(weights.count == reps.count,
                     "weights.count (\(weights.count)) must equal reps.count (\(reps.count))")
        if !rpe.isEmpty {
            precondition(rpe.count == weights.count,
                         "rpe.count (\(rpe.count)) must equal weights.count (\(weights.count))")
        }

        var created: [Session] = []
        for i in 0..<weights.count {
            let session = Session()
            session.startedAt = weekStart.addingTimeInterval(Double(i) * 86_400)
            session.completedAt = session.startedAt.addingTimeInterval(45 * 60)
            session.routineSnapshotName = "Test"
            // PIVOT-02 / PIVOT-05: intent on Session.
            session.intentRaw = intent.rawValue
            context.insert(session)

            let se = SessionExercise()
            se.session = session
            se.exercise = exercise
            se.targetSets = 1
            se.orderIndex = 0
            context.insert(se)

            let entry = SetEntry()
            entry.sessionExercise = se
            entry.orderIndex = 0
            entry.weight = weights[i]
            entry.reps = reps[i]
            entry.rpe = rpe.isEmpty ? nil : rpe[i]
            entry.isWarmup = false
            entry.isComplete = true
            entry.setTypeRaw = "working"
            entry.completedAt = session.startedAt
            context.insert(entry)

            created.append(session)
        }
        try context.save()
        return created
    }

    // MARK: - Named edge-case factories (Wave 0 stubs)
    //
    // Implementations live in the downstream plan that turns each
    // consumer suite GREEN. Calling any of these from Wave 0 is a
    // programming error and crashes loudly.

    static func stalledWindow(in context: ModelContext) throws -> (Exercise, [Session]) {
        fatalError("FatigueTestFixtures.stalledWindow — not yet implemented; see Phase 5 plan 03 (Slice D PlateauDetector).")
    }

    static func progressingWindow(in context: ModelContext) throws -> (Exercise, [Session]) {
        fatalError("FatigueTestFixtures.progressingWindow — not yet implemented; see Phase 5 plan 03 (Slice D PlateauDetector).")
    }

    static func threeSessionWindow(in context: ModelContext) throws -> (Exercise, [Session]) {
        fatalError("FatigueTestFixtures.threeSessionWindow — not yet implemented; see Phase 5 plan 03 (Slice D PlateauDetector).")
    }

    static func fourSessionsOneHighRep(in context: ModelContext) throws -> (Exercise, [Session]) {
        fatalError("FatigueTestFixtures.fourSessionsOneHighRep — not yet implemented; see Phase 5 plan 03 (Slice D PlateauDetector).")
    }

    static func belowMAVWithStall(in context: ModelContext) throws -> (Exercise, [Session], MuscleVolumeTarget) {
        fatalError("FatigueTestFixtures.belowMAVWithStall — not yet implemented; see Phase 5 plan 03 (Slice D suggestedAction → addVolume branch).")
    }

    static func rpeCreepStall(in context: ModelContext) throws -> (Exercise, [Session]) {
        fatalError("FatigueTestFixtures.rpeCreepStall — not yet implemented; see Phase 5 plan 03 (Slice D suggestedAction → dropIntensity branch).")
    }

    static func blockWeek3Stall(in context: ModelContext) throws -> (Exercise, [Session], Block) {
        fatalError("FatigueTestFixtures.blockWeek3Stall — not yet implemented; see Phase 5 plan 03 (Slice D suggestedAction → deload branch).")
    }

    static func bareStall(in context: ModelContext) throws -> (Exercise, [Session]) {
        fatalError("FatigueTestFixtures.bareStall — not yet implemented; see Phase 5 plan 03 (Slice D suggestedAction → tryVariation default branch).")
    }

    static func noBlockStall(in context: ModelContext) throws -> (Exercise, [Session]) {
        fatalError("FatigueTestFixtures.noBlockStall — not yet implemented; see Phase 5 plan 03 (Slice D no-active-block heuristic path).")
    }

    static func exerciseWithOverride(in context: ModelContext) throws -> Exercise {
        fatalError("FatigueTestFixtures.exerciseWithOverride — not yet implemented; see Phase 5 plan 03 (SET-06 per-exercise override consumption).")
    }

    static func intentSplitHistory(in context: ModelContext) throws -> (Exercise, [Session]) {
        fatalError("FatigueTestFixtures.intentSplitHistory — not yet implemented; see Phase 5 plan 03 (intent-split per-exercise stream isolation).")
    }
}
