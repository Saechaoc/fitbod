//
//  DemoWorkoutSeed.swift
//  fitbod
//
//  DEBUG-only E2E hook. Launch with `-fitbod-seed-demo-workout` to get a
//  realistic in-progress workout without building a training block:
//
//    xcrun simctl launch <device> bodybuilding.fitbod -fitbod-seed-demo-workout
//
//  It creates a "Push A" session template from real catalog exercises,
//  logs one finished Push A earlier this week (so the PREVIOUS column,
//  summary PRs and Today's weekly volume have history), and starts
//  today's Push A through SessionFactory.start, exactly like the Today
//  CTA would. Today then shows the Resume slab. Idempotent: does nothing
//  when a "Push A" template already exists. Compiled out of release builds.
//
//  Two more flags seed finished Push As around an empty workout, one
//  finished with no logged work sets (decision 6), for the session counts
//  and Compare. Each logged Push A lifts 2.5 more than the one before.
//  Neither leaves a workout in progress, and both mark this week's recap
//  seen, so Today opens without a sheet:
//
//    -fitbod-seed-empty-workout   a logged Push A 30 minutes ago, then an
//                                 empty one 15 minutes ago
//    -fitbod-seed-empty-between   logged Push As six days and one day
//                                 ago, and an empty one three days ago
//

import Foundation
import SwiftData

enum DemoWorkoutSeed {
    static let launchArgument = "-fitbod-seed-demo-workout"
    static let emptyWorkoutArgument = "-fitbod-seed-empty-workout"
    static let emptyBetweenArgument = "-fitbod-seed-empty-between"

    @MainActor
    static func runIfRequested(in context: ModelContext) {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(launchArgument) {
            seed(in: context)
        } else if arguments.contains(emptyWorkoutArgument) {
            seedFinished([(30 * 60, 10, true), (15 * 60, 5, false)], in: context)
        } else if arguments.contains(emptyBetweenArgument) {
            let day: TimeInterval = 24 * 3600
            seedFinished([(6 * day, 55, true), (3 * day, 55, false), (1 * day, 55, true)], in: context)
        }
        #endif
    }

    #if DEBUG
    /// (catalog name candidates, sets, reps low/high, rest seconds, prior-session weight)
    private static let plan: [(names: [String], sets: Int, low: Int, high: Int, rest: Int, priorWeight: Double)] = [
        (["Barbell Bench Press - Medium Grip", "Bench Press - Powerlifting"], 3, 5, 8, 180, 100),
        (["Incline Dumbbell Press"], 3, 8, 12, 120, 30),
        (["Barbell Shoulder Press", "Dumbbell Shoulder Press"], 3, 6, 10, 150, 50),
        (["Cable Seated Lateral Raise", "Side Lateral Raise"], 3, 12, 15, 60, 10),
        (["Triceps Pushdown", "Triceps Pushdown - Rope Attachment"], 3, 10, 15, 60, 25),
    ]

    @MainActor
    private static func seed(in context: ModelContext) {
        guard let pushA = makePushA(in: context) else { return }

        // A finished Push A: every working set done at the bottom of the
        // rep range. Weekly volume counts sessions by start date, so it
        // starts three days ago, or at the start of the week when the week
        // is younger than that; otherwise Today's volume would be empty on
        // the first days of every week. Just after midnight on the first
        // day there is no room before today's workout, so it falls back to
        // last week.
        let now = Date.now
        let weekStartsMonday = (try? context.fetch(FetchDescriptor<UserSettings>()))?
            .first?.weekStartsMonday ?? true
        let weekStart = now.mondayAtMidnightForToday(weekStartsMonday: weekStartsMonday)
        let priorStart = min(
            max(now.addingTimeInterval(-3 * 24 * 3600), weekStart),
            now.addingTimeInterval(-70 * 60)
        )
        finishPushA(pushA.template, startedAt: priorStart, minutes: 55, weights: pushA.weights, in: context)

        // Today's workout, started 12 minutes ago, nothing logged yet.
        _ = try? SessionFactory.start(
            template: pushA.template,
            on: Date.now.addingTimeInterval(-12 * 60),
            context: context
        )
    }

    /// Finished Push As, oldest first: how long ago each started, how many
    /// minutes it ran, and whether its sets were logged or none were.
    @MainActor
    private static func seedFinished(
        _ workouts: [(startedAgo: TimeInterval, minutes: Int, logged: Bool)],
        in context: ModelContext
    ) {
        guard let pushA = makePushA(in: context) else { return }
        let now = Date.now
        var loggedCount = 0
        for workout in workouts {
            finishPushA(
                pushA.template,
                startedAt: now.addingTimeInterval(-workout.startedAgo),
                minutes: workout.minutes,
                weights: workout.logged ? pushA.weights.mapValues { $0 + 2.5 * Double(loggedCount) } : nil,
                in: context
            )
            if workout.logged { loggedCount += 1 }
        }

        // A workout last week would open Today on the weekly recap.
        if let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first {
            settings.weeklyRecapShownForWeekStart = now.mondayAtMidnightForToday(
                weekStartsMonday: settings.weekStartsMonday
            )
            try? context.save()
        }
    }

    /// The "Push A" template from real catalog exercises, and the weight
    /// each exercise is first logged at. Nil when it already exists.
    @MainActor
    private static func makePushA(in context: ModelContext) -> (template: SessionTemplate, weights: [UUID: Double])? {
        let existing = (try? context.fetch(FetchDescriptor<SessionTemplate>())) ?? []
        guard !existing.contains(where: { $0.name == "Push A" }) else { return nil }
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []

        let template = SessionTemplate()
        context.insert(template)
        template.name = "Push A"
        template.intentRaw = Intent.hypertrophy.rawValue

        var priorWeights: [UUID: Double] = [:]
        for (index, row) in plan.enumerated() {
            guard let exercise = row.names.lazy.compactMap({ name in
                exercises.first { $0.name == name }
            }).first else { continue }
            let item = SessionExerciseTemplate()
            context.insert(item)
            item.sessionTemplate = template
            item.exercise = exercise
            item.orderIndex = index
            item.targetSets = row.sets
            item.targetRepsLow = row.low
            item.targetRepsHigh = row.high
            item.prescribedRestSeconds = row.rest
            priorWeights[exercise.id] = row.priorWeight
        }
        try? context.save()
        return (template, priorWeights)
    }

    /// Starts a Push A at `start` and finishes it `minutes` later. With
    /// `weights`, every set is done: the warm-ups, and each working set at
    /// the bottom of its rep range. Without, nothing is logged, so it is
    /// an empty workout.
    @MainActor
    private static func finishPushA(
        _ template: SessionTemplate,
        startedAt start: Date,
        minutes: Int,
        weights: [UUID: Double]?,
        in context: ModelContext
    ) {
        guard let workout = try? SessionFactory.start(template: template, on: start, context: context) else { return }
        if let weights {
            for se in workout.exercises ?? [] {
                for set in se.sets ?? [] where !set.isWarmup {
                    set.weight = weights[se.exercise?.id ?? UUID()] ?? 20
                    set.reps = se.targetRepsLow
                    set.rpe = 8
                    set.isComplete = true
                    set.completedAt = start.addingTimeInterval(Double(set.orderIndex) * 180)
                }
                for warmup in (se.sets ?? []) where warmup.isWarmup {
                    warmup.isComplete = true
                }
            }
        }
        workout.completedAt = start.addingTimeInterval(Double(minutes) * 60)
        workout.totalDurationSeconds = minutes * 60
        try? context.save()
    }
    #endif
}
