//
//  CalibratingSetSeed.swift
//  fitbod
//
//  DEBUG-only E2E hook. Launch with `-fitbod-seed-calibrating-set` to get
//  a workout in progress whose sets show a calibrating weight range:
//
//    xcrun simctl launch <device> bodybuilding.fitbod -fitbod-seed-calibrating-set
//
//  It creates a "Calibrating Bench" session template, run by RPE
//  autoregulation, with the barbell bench press for 6 to 8 reps at RPE 8.
//  It logs one finished workout a week ago, three sets of 110 x 5 at
//  RPE 8, which is fewer sets than calibration needs, and starts today's
//  workout through SessionFactory.start. With the default barbell plates,
//  the logger's sets then show a calibrating range of "95 – 105 lb", and
//  Why this weight suggests 100 lb. Each set starts at last workout's
//  110 lb, which differs from the suggestion, so an untouched set shows
//  the range. This week's recap is marked seen, so Today opens on the
//  Resume slab.
//
//  Use it without the other seed flags: each seed starts a workout, and
//  only one can be in progress. Idempotent: does nothing when a
//  "Calibrating Bench" template already exists. Compiled out of release
//  builds.
//

import Foundation
import SwiftData

enum CalibratingSetSeed {
    static let launchArgument = "-fitbod-seed-calibrating-set"

    @MainActor
    static func runIfRequested(in context: ModelContext) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return }
        seed(in: context)
        #endif
    }

    #if DEBUG
    static let templateName = "Calibrating Bench"
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
        template.progressionKindRaw = ProgressionKind.rpe.rawValue

        let item = SessionExerciseTemplate()
        context.insert(item)
        item.sessionTemplate = template
        item.exercise = bench
        item.orderIndex = 0
        item.targetSets = 3
        item.targetRepsLow = 6
        item.targetRepsHigh = 8
        item.targetRPE = 8
        item.prescribedRestSeconds = 180
        try? context.save()

        // One finished workout a week ago: three RPE-logged sets, short of
        // the sets calibration needs, so today's prescription calibrates
        // from its top set.
        let now = Date.now
        let start = now.addingTimeInterval(-7 * 24 * 3600)
        if let workout = try? SessionFactory.start(template: template, on: start, context: context) {
            for se in workout.exercises ?? [] {
                for set in se.sets ?? [] where !set.isWarmup {
                    set.weight = 110
                    set.reps = 5
                    set.rpe = 8
                    set.isComplete = true
                    set.completedAt = start.addingTimeInterval(Double(set.orderIndex) * 180)
                }
                for warmup in (se.sets ?? []) where warmup.isWarmup {
                    warmup.isComplete = true
                }
            }
            workout.completedAt = start.addingTimeInterval(45 * 60)
            workout.totalDurationSeconds = 45 * 60
            try? context.save()
        }

        // Last week has a finished workout, so Today would open on the
        // weekly recap. Mark it seen, so Today opens on the Resume slab.
        if let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first {
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
