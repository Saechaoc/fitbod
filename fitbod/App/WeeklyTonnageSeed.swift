//
//  WeeklyTonnageSeed.swift
//  fitbod
//
//  DEBUG-only E2E hook. Launch with `-fitbod-seed-weekly-tonnage` and an
//  optional week count to give the Weekly Tonnage chart that many weeks of
//  data, eight when the count is missing:
//
//    xcrun simctl launch <device> bodybuilding.fitbod -fitbod-seed-weekly-tonnage 1
//
//  It logs one finished "Tonnage Weeks" workout of the barbell bench press
//  on each of the last N Sundays, all at one time of day: 09:00, or earlier
//  when it runs on a Sunday morning, so the newest one is over. Sunday is
//  the day the device calendar, which starts weeks on Sunday in the US, and
//  the week-start setting, Monday by default, disagree about. Each workout
//  has three work sets of 5, at 100 in the newest week and 2.5 less for
//  each week before it, so the newest week holds 1,500 of tonnage. Nothing
//  is in progress, and this week's recap is marked seen, so Today opens
//  without a sheet.
//
//  Add `-fitbod-week-starts-sunday` to set the week-start setting to
//  Sunday first, because Settings has no control for it.
//
//  Use it without the other seed flags. Idempotent: does nothing when a
//  "Tonnage Weeks" workout already exists. Compiled out of release builds.
//

import Foundation
import SwiftData

enum WeeklyTonnageSeed {
    static let launchArgument = "-fitbod-seed-weekly-tonnage"
    static let weekStartsSundayArgument = "-fitbod-week-starts-sunday"

    @MainActor
    static func runIfRequested(in context: ModelContext) {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(weekStartsSundayArgument),
           let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first {
            settings.weekStartsMonday = false
            try? context.save()
        }
        guard let index = arguments.firstIndex(of: launchArgument) else { return }
        let weeks = arguments.dropFirst(index + 1).first.flatMap { Int($0) } ?? 8
        seed(weeks: max(weeks, 1), in: context)
        #endif
    }

    #if DEBUG
    static let workoutName = "Tonnage Weeks"
    private static let benchNames = ["Barbell Bench Press - Medium Grip", "Bench Press - Powerlifting"]

    @MainActor
    private static func seed(weeks: Int, in context: ModelContext) {
        let name = workoutName
        let existing = (try? context.fetch(FetchDescriptor<Session>(
            predicate: #Predicate { $0.routineSnapshotName == name }
        ))) ?? []
        guard existing.isEmpty else { return }
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        guard let bench = benchNames.lazy.compactMap({ name in
            exercises.first { $0.name == name }
        }).first else { return }

        let now = Date.now
        let calendar = Calendar(identifier: .gregorian)
        guard let newest = newestStart(before: now, in: calendar) else { return }
        for weeksAgo in 0..<weeks {
            guard let start = calendar.date(byAdding: .day, value: -7 * weeksAgo, to: newest) else { continue }
            let weight = 100 - 2.5 * Double(weeksAgo)
            log(bench, weight: weight, at: start, context: context)
        }

        // The newest workout can sit in last week, so Today would open on
        // the weekly recap. Mark it seen.
        if let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first {
            settings.weeklyRecapShownForWeekStart = now.mondayAtMidnightForToday(
                weekStartsMonday: settings.weekStartsMonday
            )
        }
        try? context.save()
    }

    /// The newest workout's start: 09:00 on the latest Sunday, or earlier
    /// that Sunday so its hour-long workout is over by `now`, else 09:00 the
    /// Sunday before. It is always less than a week old. Last 8 wk holds
    /// whole weeks, so with weeks starting on Monday the oldest of eight
    /// workouts falls out of it unless the newest is today's.
    private static func newestStart(before now: Date, in calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        let daysSinceSunday = calendar.component(.weekday, from: today) - 1
        guard let sunday = calendar.date(byAdding: .day, value: -daysSinceSunday, to: today),
              let nine = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: sunday) else { return nil }
        let latest = now.addingTimeInterval(-3600)
        if latest >= sunday { return min(nine, latest) }
        return calendar.date(byAdding: .day, value: -7, to: nine)
    }

    /// One finished workout: three work sets of 5 at `weight`, three
    /// minutes apart.
    @MainActor
    private static func log(_ exercise: Exercise, weight: Double, at start: Date, context: ModelContext) {
        let workout = Session()
        context.insert(workout)
        workout.startedAt = start
        workout.completedAt = start.addingTimeInterval(55 * 60)
        workout.totalDurationSeconds = 55 * 60
        workout.intentRaw = Intent.strength.rawValue
        workout.templateName = workoutName
        workout.routineSnapshotName = workoutName

        let entry = SessionExercise()
        context.insert(entry)
        entry.session = workout
        entry.exercise = exercise
        entry.exerciseNameSnapshot = exercise.name
        entry.orderIndex = 0
        entry.targetSets = 3
        entry.targetRepsLow = 5
        entry.targetRepsHigh = 5
        entry.prescribedRestSeconds = 180

        for index in 0..<3 {
            let set = SetEntry()
            context.insert(set)
            set.sessionExercise = entry
            set.orderIndex = index
            set.weight = weight
            set.reps = 5
            set.rpe = 8
            set.isWarmup = false
            set.setTypeRaw = SetType.working.rawValue
            set.isComplete = true
            set.completedAt = start.addingTimeInterval(Double(index) * 180)
        }
    }
    #endif
}
