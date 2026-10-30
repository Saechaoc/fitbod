//
//  SkipNextSessionWarmupTests.swift
//  fitbodTests
//
//  Ticket T88 (finding F98). A routine exercise's "Skip warm-ups this
//  session only" gives it no ramp at the next workout start, exactly as
//  when its warm-up is off, so the next qualifying compound gets the ramp.
//  That start clears the flag even when it built no ramp, so the start
//  after it builds the ramp again.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SkipNextSessionWarmup", .serialized)
struct SkipNextSessionWarmupTests {

    /// The first workout starts on this day.
    private let today = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("skip warm-ups this session only skips the next start's ramp, then clears")
    func skipNextSessionSkipsOneStart() throws {
        let ctx = try LoggerFixtures.makeContext()
        let fx = try makeFixture(in: ctx)
        fx.bench.warmupOverride = WarmupConfig(enabled: true, skipNextSession: true)

        let first = try startWorkout(fx, on: today, in: ctx)

        #expect(warmups(of: first.bench).isEmpty)
        // As when the bench press's warm-up is off, the row gets the ramp.
        #expect(warmups(of: first.row).count == 4)
        #expect(fx.bench.warmupOverride == WarmupConfig(enabled: true, skipNextSession: false))

        try finish(first.session, in: ctx)
        let next = try startWorkout(fx, on: today.addingTimeInterval(2 * 24 * 3600), in: ctx)

        #expect(warmups(of: next.bench).count == 4)
        #expect(warmups(of: next.row).isEmpty)
    }

    @Test("the skip is cleared at a start that gives another exercise the ramp")
    func skipClearedWhenAnotherExerciseGetsTheRamp() throws {
        let ctx = try LoggerFixtures.makeContext()
        let fx = try makeFixture(in: ctx)
        fx.row.warmupOverride = WarmupConfig(enabled: true, skipNextSession: true)

        let first = try startWorkout(fx, on: today, in: ctx)

        #expect(warmups(of: first.bench).count == 4)
        #expect(warmups(of: first.row).isEmpty)
        #expect(fx.row.warmupOverride == WarmupConfig(enabled: true, skipNextSession: false))
    }

    @Test("clearing the skip leaves a warm-up that is off still off")
    func clearingSkipKeepsWarmupOff() throws {
        let ctx = try LoggerFixtures.makeContext()
        let fx = try makeFixture(in: ctx)
        fx.bench.warmupOverride = WarmupConfig(enabled: false, skipNextSession: true)

        let first = try startWorkout(fx, on: today, in: ctx)

        #expect(warmups(of: first.bench).isEmpty)
        #expect(fx.bench.warmupOverride == WarmupConfig(enabled: false, skipNextSession: false))
    }

    // MARK: - Helpers

    /// The template and its two prescription rows: a barbell bench press,
    /// then a barbell row.
    private struct Fixture {
        let template: SessionTemplate
        let bench: SessionExerciseTemplate
        let row: SessionExerciseTemplate
    }

    /// A barbell bench press then a barbell row, each with a finished
    /// workout a week ago heavy enough for a ramp, on a 20 kg bar with the
    /// default kg plates. Without an override a start gives the bench press
    /// the workout's ramp and the row none.
    private func makeFixture(in ctx: ModelContext) throws -> Fixture {
        let inventory = PlateInventory()
        ctx.insert(inventory)
        inventory.equipmentKind = .barbell
        inventory.barWeight = 20
        inventory.availablePlates = PlateInventoryDefaults.make(for: .barbell, unitSystem: .kg)

        let bench = LoggerFixtures.exercise("Barbell Bench Press", in: ctx)
        let row = LoggerFixtures.exercise("Barbell Row", in: ctx)
        let lastWeek = today.addingTimeInterval(-7 * 24 * 3600)
        for (exercise, weight) in [(bench, 100.0), (row, 80.0)] {
            try LoggerFixtures.session(exercise: exercise, startedAt: lastWeek, completedAt: lastWeek.addingTimeInterval(3600),
                                       sets: [(weight, 5, true), (weight, 5, true), (weight, 5, true)], in: ctx)
        }
        let template = try LoggerFixtures.template("Press & Pull", exercises: [bench, row], in: ctx)
        let rows = (template.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        try #require(rows.count == 2)
        return Fixture(template: template, bench: rows[0], row: rows[1])
    }

    /// Starts a workout from the template and returns it with its two exercises.
    private func startWorkout(
        _ fx: Fixture,
        on date: Date,
        in ctx: ModelContext
    ) throws -> (session: Session, bench: SessionExercise, row: SessionExercise) {
        let session = try SessionFactory.start(template: fx.template, on: date, context: ctx)
        let exercises = (session.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        try #require(exercises.count == 2)
        return (session, exercises[0], exercises[1])
    }

    private func finish(_ session: Session, in ctx: ModelContext) throws {
        session.completedAt = session.startedAt.addingTimeInterval(3600)
        try ctx.save()
    }

    private func warmups(of sessionExercise: SessionExercise) -> [SetEntry] {
        SessionSetActions.ordered(sessionExercise).filter(\.isWarmup)
    }
}
