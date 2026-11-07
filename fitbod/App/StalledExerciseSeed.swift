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
        let variationUndo = ProcessInfo.processInfo.arguments.contains("-fitbod-seed-variation-undo")
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) || variationUndo else { return }
        seed(in: context, variationUndo: variationUndo)
        #endif
    }

    #if DEBUG
    static let templateName = "Bench Stall"
    private static let exerciseNames = ["Barbell Bench Press - Medium Grip", "Bench Press - Powerlifting"]

    @MainActor
    private static func seed(in context: ModelContext, variationUndo: Bool) {
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

        if variationUndo {
            seedVariationHistory(for: bench, exercises: exercises, settings: settings, now: now, in: context)
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

    /// Meets MAV without RPE creep or an active block, and logs a matching
    /// candidate so the real TryVariationSheet can offer a selectable row.
    @MainActor
    private static func seedVariationHistory(
        for bench: Exercise,
        exercises: [Exercise],
        settings: UserSettings?,
        now: Date,
        in context: ModelContext
    ) {
        guard let primary = (bench.muscleStimuli ?? [])
            .filter({ $0.role == "primary" }).max(by: { $0.weight < $1.weight }),
              let slug = primary.muscle?.slug, primary.weight > 0,
              let target = (try? context.fetch(FetchDescriptor<MuscleVolumeTarget>()))?
                .first(where: { $0.muscle?.slug == slug }),
              let count = Int(exactly: (Double(target.mav) / primary.weight).rounded(.up)), count > 0,
              let candidate = exercises.first(where: {
                  $0.name == "Dumbbell Bench Press" && $0.mechanicRaw == bench.mechanicRaw
                      && $0.primaryMuscleSlugsJoined.contains("|\(slug)|")
              })
        else { return }

        let weekStart = now.mondayAtMidnightForToday(weekStartsMonday: settings?.weekStartsMonday ?? true)
        let volumeWorkout = Session()
        context.insert(volumeWorkout)
        volumeWorkout.startedAt = weekStart
        volumeWorkout.completedAt = min(now, weekStart.addingTimeInterval(3_600))
        volumeWorkout.intentRaw = Intent.hypertrophy.rawValue
        volumeWorkout.routineSnapshotName = "Bench volume"
        let benchLog = SessionExercise()
        context.insert(benchLog)
        benchLog.session = volumeWorkout
        benchLog.exercise = bench
        benchLog.exerciseNameSnapshot = bench.name
        for index in 0..<count {
            let set = SetEntry()
            context.insert(set)
            set.sessionExercise = benchLog
            set.orderIndex = index
            set.weight = 100
            set.reps = 5
            set.rpe = 8
            set.isComplete = true
            set.completedAt = volumeWorkout.completedAt ?? now
        }

        let history = Session()
        context.insert(history)
        history.startedAt = now.addingTimeInterval(-8 * 86_400)
        history.completedAt = history.startedAt.addingTimeInterval(3_600)
        history.intentRaw = Intent.hypertrophy.rawValue
        let candidateLog = SessionExercise()
        context.insert(candidateLog)
        candidateLog.session = history
        candidateLog.exercise = candidate
        candidateLog.exerciseNameSnapshot = candidate.name
        let set = SetEntry()
        context.insert(set)
        set.sessionExercise = candidateLog
        set.weight = 60
        set.reps = 8
        set.rpe = 8
        set.isComplete = true
        set.completedAt = history.completedAt ?? now
        try? context.save()
    }
    #endif
}
