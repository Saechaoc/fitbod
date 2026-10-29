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

import Foundation
import SwiftData

enum DemoWorkoutSeed {
    static let launchArgument = "-fitbod-seed-demo-workout"

    @MainActor
    static func runIfRequested(in context: ModelContext) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return }
        seed(in: context)
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
        let existing = (try? context.fetch(FetchDescriptor<SessionTemplate>())) ?? []
        guard !existing.contains(where: { $0.name == "Push A" }) else { return }
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
        if let prior = try? SessionFactory.start(template: template, on: priorStart, context: context) {
            for se in prior.exercises ?? [] {
                for set in se.sets ?? [] where !set.isWarmup {
                    set.weight = priorWeights[se.exercise?.id ?? UUID()] ?? 20
                    set.reps = se.targetRepsLow
                    set.rpe = 8
                    set.isComplete = true
                    set.completedAt = priorStart.addingTimeInterval(Double(set.orderIndex) * 180)
                }
                for warmup in (se.sets ?? []) where warmup.isWarmup {
                    warmup.isComplete = true
                }
            }
            prior.completedAt = priorStart.addingTimeInterval(55 * 60)
            prior.totalDurationSeconds = 55 * 60
            try? context.save()
        }

        // Today's workout, started 12 minutes ago, nothing logged yet.
        _ = try? SessionFactory.start(
            template: template,
            on: Date.now.addingTimeInterval(-12 * 60),
            context: context
        )
    }
    #endif
}
