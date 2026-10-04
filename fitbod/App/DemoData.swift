//
//  DemoData.swift
//  fitbod
//
//  Opt-in demo content: two routines and three weeks of finished workouts
//  built from the seeded library, so History, previous performance and
//  the summary screens have realistic data for screenshots, layout audits
//  and previews.
//
//  Runs only when the app is launched with `-seed-demo-history` (see
//  `LaunchConfiguration`) and only into a store with no routines and no
//  workouts, so it can never mix with real training data. Sessions are
//  written exactly as a finished workout would be: snapshot fields copied
//  from the routine line, completed working sets, `completedAt` and
//  `totalDurationSeconds` stamped.
//

import Foundation
import SwiftData

@MainActor
enum DemoData {
    /// One routine line: which exercise, its prescription, and how the
    /// logged weight moves across the demo weeks.
    struct Line {
        /// free-exercise-db id first, then display-name fallbacks (the
        /// preview fixture has no external ids).
        let lookup: [String]
        let intent: Intent
        let sets: Int
        let repsLow: Int
        let repsHigh: Int
        let rpe: Double?
        let restSeconds: Int
        let startWeight: Double
        let weeklyStep: Double
        let generateWarmups: Bool
    }

    struct Template {
        let name: String
        let notes: String?
        let lines: [Line]
    }

    static let upper = Template(
        name: "Upper A · Strength",
        notes: "Heavy bench first. Keep pull-ups strict — full hang at the bottom.",
        lines: [
            Line(lookup: ["Barbell_Bench_Press_-_Medium_Grip", "Barbell Bench Press"], intent: .strength,
                 sets: 4, repsLow: 4, repsHigh: 6, rpe: 8, restSeconds: 180,
                 startWeight: 205, weeklyStep: 5, generateWarmups: true),
            Line(lookup: ["Weighted_Pull_Ups"], intent: .strength,
                 sets: 3, repsLow: 5, repsHigh: 8, rpe: 8, restSeconds: 150,
                 startWeight: 25, weeklyStep: 5, generateWarmups: false),
            Line(lookup: ["Incline_Dumbbell_Press"], intent: .hypertrophy,
                 sets: 3, repsLow: 8, repsHigh: 12, rpe: nil, restSeconds: 120,
                 startWeight: 65, weeklyStep: 5, generateWarmups: false),
            Line(lookup: ["Bent_Over_Barbell_Row", "Barbell Row"], intent: .hypertrophy,
                 sets: 3, repsLow: 8, repsHigh: 10, rpe: nil, restSeconds: 120,
                 startWeight: 155, weeklyStep: 5, generateWarmups: false),
            Line(lookup: ["Side_Lateral_Raise"], intent: .hypertrophy,
                 sets: 3, repsLow: 12, repsHigh: 15, rpe: nil, restSeconds: 60,
                 startWeight: 20, weeklyStep: 0, generateWarmups: false),
            Line(lookup: ["Triceps_Pushdown"], intent: .hypertrophy,
                 sets: 3, repsLow: 10, repsHigh: 15, rpe: nil, restSeconds: 60,
                 startWeight: 50, weeklyStep: 5, generateWarmups: false),
        ]
    )

    static let lower = Template(
        name: "Lower A · Squat Focus",
        notes: nil,
        lines: [
            Line(lookup: ["Barbell_Squat"], intent: .strength,
                 sets: 4, repsLow: 4, repsHigh: 6, rpe: 8, restSeconds: 210,
                 startWeight: 275, weeklyStep: 10, generateWarmups: true),
            Line(lookup: ["Romanian_Deadlift"], intent: .hypertrophy,
                 sets: 3, repsLow: 6, repsHigh: 10, rpe: nil, restSeconds: 150,
                 startWeight: 225, weeklyStep: 10, generateWarmups: false),
            Line(lookup: ["Leg_Press"], intent: .hypertrophy,
                 sets: 3, repsLow: 10, repsHigh: 15, rpe: nil, restSeconds: 120,
                 startWeight: 360, weeklyStep: 20, generateWarmups: false),
            Line(lookup: ["Lying_Leg_Curls"], intent: .hypertrophy,
                 sets: 3, repsLow: 10, repsHigh: 12, rpe: nil, restSeconds: 90,
                 startWeight: 90, weeklyStep: 5, generateWarmups: false),
            Line(lookup: ["Standing_Calf_Raises"], intent: .hypertrophy,
                 sets: 4, repsLow: 10, repsHigh: 15, rpe: nil, restSeconds: 60,
                 startWeight: 180, weeklyStep: 10, generateWarmups: false),
        ]
    )

    /// Inserts the demo routines and history when the store has neither.
    /// Returns `true` when anything was inserted.
    @discardableResult
    static func seedIfNeeded(in context: ModelContext, now: Date = .now) -> Bool {
        let routineCount = (try? context.fetchCount(FetchDescriptor<Routine>())) ?? 0
        let sessionCount = (try? context.fetchCount(FetchDescriptor<Session>())) ?? 0
        guard routineCount == 0, sessionCount == 0 else { return false }
        return seed(into: context, now: now)
    }

    /// Unconditional seed (previews and tests call this on a fresh store).
    @discardableResult
    static func seed(into context: ModelContext, now: Date = .now) -> Bool {
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        guard !exercises.isEmpty else { return false }

        let upperRoutine = makeRoutine(upper, exercises: exercises, context: context, now: now)
        let lowerRoutine = makeRoutine(lower, exercises: exercises, context: context, now: now)
        let routines = [upperRoutine, lowerRoutine].compactMap { $0 }
        guard !routines.isEmpty else { return false }

        // Two workouts a week for three weeks, alternating upper / lower,
        // oldest first so weights climb toward today.
        let calendar = Calendar.current
        let daysAgo = [20, 17, 13, 10, 6, 3]
        for (index, offset) in daysAgo.enumerated() {
            let routine = routines[index % routines.count]
            let template = routine.name == upper.name ? upper : lower
            let week = index / 2
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now),
                  let start = calendar.date(bySettingHour: 18, minute: 5 + index * 3, second: 0, of: day)
            else { continue }
            makeSession(from: routine, template: template, week: week, startedAt: start, context: context)
        }
        try? context.save()
        return true
    }

    // MARK: - Builders

    private static func resolve(_ line: Line, in exercises: [Exercise]) -> Exercise? {
        for key in line.lookup {
            if let match = exercises.first(where: { $0.externalID == key || $0.name == key }) {
                return match
            }
        }
        return nil
    }

    private static func makeRoutine(_ template: Template, exercises: [Exercise], context: ModelContext, now: Date) -> Routine? {
        let resolved = template.lines.compactMap { line in resolve(line, in: exercises).map { (line, $0) } }
        guard !resolved.isEmpty else { return nil }

        let routine = Routine()
        routine.name = template.name
        routine.notes = template.notes
        routine.createdAt = Calendar.current.date(byAdding: .day, value: -24, to: now) ?? now
        routine.updatedAt = routine.createdAt
        context.insert(routine)

        for (index, pair) in resolved.enumerated() {
            let (line, exercise) = pair
            let item = RoutineExercise()
            item.routine = routine
            item.exercise = exercise
            item.orderIndex = index
            item.intentRaw = line.intent.rawValue
            item.targetSets = line.sets
            item.targetRepsLow = line.repsLow
            item.targetRepsHigh = line.repsHigh
            item.targetRPE = line.rpe
            item.prescribedRestSeconds = line.restSeconds
            item.progressionKindRaw = line.rpe == nil ? ProgressionKind.double.rawValue : ProgressionKind.rpe.rawValue
            item.generateWarmups = line.generateWarmups
            context.insert(item)
        }
        return routine
    }

    private static func makeSession(from routine: Routine, template: Template, week: Int, startedAt: Date, context: ModelContext) {
        let session = Session()
        session.startedAt = startedAt
        session.routineSnapshotName = routine.name
        session.sourceRoutineID = routine.id
        context.insert(session)

        var clock = startedAt.addingTimeInterval(6 * 60)
        let lines = (routine.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        for item in lines {
            guard let line = template.lines.first(where: { candidate in
                candidate.lookup.contains { $0 == item.exercise?.externalID || $0 == item.exercise?.name }
            }) else { continue }

            let logged = SessionExercise()
            logged.session = session
            logged.exercise = item.exercise
            logged.orderIndex = item.orderIndex
            logged.intentRaw = item.intentRaw
            logged.targetSets = item.targetSets
            logged.targetRepsLow = item.targetRepsLow
            logged.targetRepsHigh = item.targetRepsHigh
            logged.targetRPE = item.targetRPE
            logged.prescribedRestSeconds = item.prescribedRestSeconds
            logged.progressionKindRaw = item.progressionKindRaw
            let weight = line.startWeight + Double(week) * line.weeklyStep
            logged.prescribedWeight = weight
            context.insert(logged)

            for setIndex in 0..<line.sets {
                let entry = SetEntry()
                entry.sessionExercise = logged
                entry.orderIndex = setIndex
                entry.weight = weight
                // Reps fall off a little across sets; later weeks add one.
                entry.reps = max(line.repsLow, min(line.repsHigh, line.repsHigh - setIndex / 2 - (week == 0 ? 1 : 0)))
                if let rpe = line.rpe {
                    entry.rpe = min(10, rpe + Double(setIndex) * 0.5)
                }
                entry.setTypeRaw = SetType.working.rawValue
                entry.isComplete = true
                clock = clock.addingTimeInterval(TimeInterval(line.restSeconds + 45))
                entry.completedAt = clock
                entry.restAfterSeconds = line.restSeconds
                context.insert(entry)
            }
        }

        let finishedAt = clock.addingTimeInterval(3 * 60)
        session.completedAt = finishedAt
        session.totalDurationSeconds = Int(finishedAt.timeIntervalSince(startedAt))
    }
}
