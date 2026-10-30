//
//  ProgressHistorySeed.swift
//  fitbod
//
//  DEBUG-only E2E hook. Launch with `-fitbod-seed-progress-history` to get
//  four finished workouts of two exercises, so the PR list and the
//  progress chart have history to rank and plot:
//
//    xcrun simctl launch <device> bodybuilding.fitbod -fitbod-seed-progress-history
//
//  It creates a "Bench & Squat" session template with the barbell bench
//  press and the barbell squat, and logs one finished workout a week for
//  the last four weeks, alternating hypertrophy and strength. Each
//  exercise has two completed warm-ups, one of them with an RPE, then its
//  work sets. The work sets repeat a set within a workout and across
//  workouts (the squat's heaviest is three straight sets of 160 x 3),
//  leave some RPEs blank, and cover the 1-6, 7-10 and 11+ rep buckets.
//  The bench press's first workout has 2,140 of volume at a mean RPE of
//  7.625. Nothing is in progress, and this week's recap is marked seen,
//  so Today opens without a sheet.
//
//  Idempotent: does nothing when a "Bench & Squat" template already
//  exists. Compiled out of release builds.
//

import Foundation
import SwiftData

enum ProgressHistorySeed {
    static let launchArgument = "-fitbod-seed-progress-history"

    @MainActor
    static func runIfRequested(in context: ModelContext) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return }
        seed(in: context)
        #endif
    }

    #if DEBUG
    static let templateName = "Bench & Squat"
    private static let benchNames = ["Barbell Bench Press - Medium Grip", "Bench Press - Powerlifting"]
    private static let squatNames = ["Barbell Squat", "Barbell Full Squat"]

    /// One logged set: weight, reps and RPE, nil when none was logged.
    private typealias LoggedSet = (weight: Double, reps: Int, rpe: Double?)

    private static let benchWarmups: [LoggedSet] = [(45, 5, 5), (65, 3, nil)]
    private static let squatWarmups: [LoggedSet] = [(60, 5, 5), (95, 3, nil)]

    /// Work sets per workout, oldest first.
    private static let workouts: [(intent: Intent, bench: [LoggedSet], squat: [LoggedSet])] = [
        (.hypertrophy,
         bench: [(100, 5, 8), (100, 5, 8), (100, 5, 8), (80, 8, 6.5)],
         squat: [(140, 5, 8), (140, 5, 8), (120, 8, 7)]),
        (.strength,
         bench: [(105, 3, 9), (102.5, 4, 8), (100, 5, nil)],
         squat: [(150, 3, 9), (140, 5, nil)]),
        (.hypertrophy,
         bench: [(85, 8, 8), (80, 10, 9), (75, 12, 9)],
         squat: [(130, 8, 8), (125, 10, 9)]),
        (.strength,
         bench: [(107.5, 2, 9.5), (95, 6, 8), (90, 5, 7)],
         squat: [(160, 3, 9), (160, 3, 9), (160, 3, 9), (145, 4, 8.5)]),
    ]

    @MainActor
    private static func seed(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<SessionTemplate>())) ?? []
        guard !existing.contains(where: { $0.name == templateName }) else { return }
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        func find(_ names: [String]) -> Exercise? {
            names.lazy.compactMap { name in exercises.first { $0.name == name } }.first
        }
        guard let bench = find(benchNames), let squat = find(squatNames) else { return }

        let template = SessionTemplate()
        context.insert(template)
        template.name = templateName
        template.intentRaw = Intent.hypertrophy.rawValue
        for (index, exercise) in [bench, squat].enumerated() {
            let item = SessionExerciseTemplate()
            context.insert(item)
            item.sessionTemplate = template
            item.exercise = exercise
            item.orderIndex = index
            item.targetSets = 3
            item.targetRepsLow = 5
            item.targetRepsHigh = 8
            item.prescribedRestSeconds = 180
        }

        // One finished workout a week, the newest a week ago.
        let now = Date.now
        for (index, plan) in workouts.enumerated() {
            let weeksAgo = workouts.count - index
            let start = now.addingTimeInterval(-Double(weeksAgo) * 7 * 24 * 3600)
            let workout = Session()
            context.insert(workout)
            workout.startedAt = start
            workout.completedAt = start.addingTimeInterval(55 * 60)
            workout.totalDurationSeconds = 55 * 60
            workout.intentRaw = plan.intent.rawValue
            workout.template = template
            workout.templateName = templateName
            workout.routineSnapshotName = templateName
            workout.sourceRoutineID = template.id
            log(bench, warmups: benchWarmups, work: plan.bench, order: 0, in: workout, at: start, context: context)
            log(squat, warmups: squatWarmups, work: plan.squat, order: 1, in: workout, at: start.addingTimeInterval(25 * 60), context: context)
        }

        // Last week has a finished workout, so Today would open on the
        // weekly recap. Mark it seen.
        if let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first {
            settings.weeklyRecapShownForWeekStart = now.mondayAtMidnightForToday(
                weekStartsMonday: settings.weekStartsMonday
            )
        }
        try? context.save()
    }

    /// Logs one exercise of a workout: completed warm-ups, then work sets,
    /// three minutes apart.
    @MainActor
    private static func log(
        _ exercise: Exercise,
        warmups: [LoggedSet],
        work: [LoggedSet],
        order: Int,
        in workout: Session,
        at start: Date,
        context: ModelContext
    ) {
        let entry = SessionExercise()
        context.insert(entry)
        entry.session = workout
        entry.exercise = exercise
        entry.exerciseNameSnapshot = exercise.name
        entry.orderIndex = order
        entry.targetSets = work.count
        entry.targetRepsLow = 5
        entry.targetRepsHigh = 8
        entry.prescribedRestSeconds = 180

        let sets = warmups.map { ($0, true) } + work.map { ($0, false) }
        for (index, (logged, isWarmup)) in sets.enumerated() {
            let set = SetEntry()
            context.insert(set)
            set.sessionExercise = entry
            set.orderIndex = index
            set.weight = logged.weight
            set.reps = logged.reps
            set.rpe = logged.rpe
            set.isWarmup = isWarmup
            set.setTypeRaw = isWarmup ? SetType.warmup.rawValue : SetType.working.rawValue
            set.isComplete = true
            set.completedAt = start.addingTimeInterval(Double(index) * 180)
        }
    }
    #endif
}
