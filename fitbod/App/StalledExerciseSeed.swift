//
//  StalledExerciseSeed.swift
//  fitbod
//
//  DEBUG-only E2E hook. Launch with `-fitbod-seed-stalled-exercise` to get
//  a workout in progress whose bench press has stalled:
//
//    xcrun simctl launch <device> bodybuilding.fitbod -fitbod-seed-stalled-exercise
//
//  It creates a "Bench Stall" session template with the barbell bench
//  press, logs one finished workout a week across the bench press's
//  plateau window (its own `plateauWindowOverride`, else the user's
//  setting), each with the same top set, 100 x 5 at RPE 8, and starts
//  today's workout through SessionFactory.start. The logger then shows the
//  STALLED badge and a suggested action. The history sits before this
//  week, so this week's chest volume is below MAV and the suggestion is
//  ADD VOLUME. This week's recap is marked seen, so Today opens on the
//  Resume slab.
//
//  Use it without `-fitbod-seed-demo-workout`: each seed starts a workout,
//  and only one can be in progress. Idempotent: does nothing when a
//  "Bench Stall" template already exists. Compiled out of release builds.
//

import Foundation
import SwiftData

enum StalledExerciseSeed {
    static let launchArgument = "-fitbod-seed-stalled-exercise"

    @MainActor
    static func runIfRequested(in context: ModelContext) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return }
        seed(in: context)
        #endif
    }

    #if DEBUG
    static let templateName = "Bench Stall"
    private static let exerciseNames = ["Barbell Bench Press - Medium Grip", "Bench Press - Powerlifting"]

    @MainActor
    private static func seed(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<SessionTemplate>())) ?? []
        guard !existing.contains(where: { $0.name == templateName }) else { return }
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        guard let bench = exerciseNames.lazy.compactMap({ name in
            exercises.first { $0.name == name }
        }).first else { return }

        let template = SessionTemplate()
        context.insert(template)
        template.name = templateName
        template.intentRaw = Intent.hypertrophy.rawValue

        let item = SessionExerciseTemplate()
        context.insert(item)
        item.sessionTemplate = template
        item.exercise = bench
        item.orderIndex = 0
        item.targetSets = 3
        item.targetRepsLow = 5
        item.targetRepsHigh = 8
        item.prescribedRestSeconds = 180
        try? context.save()

        // One finished workout a week, the newest a week ago, so the whole
        // window sits before this week and the top set never moves.
        let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first
        let window = max(1, bench.plateauWindowOverride ?? settings?.plateauWindowSessions ?? 4)
        let now = Date.now
        for weeksAgo in (1...window).reversed() {
            let start = now.addingTimeInterval(-Double(weeksAgo) * 7 * 24 * 3600)
            guard let workout = try? SessionFactory.start(template: template, on: start, context: context) else { return }
            for se in workout.exercises ?? [] {
                for set in se.sets ?? [] where !set.isWarmup {
                    set.weight = 100
                    set.reps = 5
                    set.rpe = 8
                    set.isComplete = true
                    set.completedAt = start.addingTimeInterval(Double(set.orderIndex) * 180)
                }
                for warmup in (se.sets ?? []) where warmup.isWarmup {
                    warmup.isComplete = true
                }
            }
            workout.completedAt = start.addingTimeInterval(55 * 60)
            workout.totalDurationSeconds = 55 * 60
            try? context.save()
        }

        // Last week has a finished workout, so Today would open on the
        // weekly recap. Mark it seen, so Today opens on the Resume slab.
        if let settings {
            settings.weeklyRecapShownForWeekStart = now.mondayAtMidnightForToday(
                weekStartsMonday: settings.weekStartsMonday
            )
            try? context.save()
        }

        // Today's workout, started 12 minutes ago, nothing logged yet.
        _ = try? SessionFactory.start(
            template: template,
            on: now.addingTimeInterval(-12 * 60),
            context: context
        )
    }
    #endif
}
