//
//  BlockStatesSeed.swift
//  fitbod
//
//  DEBUG-only E2E hook. Launch with `-fitbod-seed-block-states` to get one
//  block in each live state on a shared routine:
//
//    xcrun simctl launch <device> bodybuilding.fitbod -fitbod-seed-block-states
//
//  It creates a "States Routine" routine with two sessions, "Upper A" (the
//  barbell bench press) and "Upper B" (the barbell row), and three blocks
//  that start on different days, so they number 1, 2 and 3:
//
//    - "Spring Block", active: accumulation 2 weeks, intensification 1 week
//      and deload 1 week on rotation, started three days ago through
//      BlockLifecycleService.start. Upper A was logged two days ago with
//      every work set done. Upper B was finished yesterday with nothing
//      logged, so it is an empty workout and does not count (decision 6).
//      Ending the block now ends it during week 1, in its first phase.
//    - "Summer Block", ready: accumulation 3 weeks and deload 1 week, fixed
//      weekly on Monday and Thursday, one day per session, starting
//      tomorrow at midnight.
//    - "Autumn Block", draft: accumulation 4 weeks and no routine, starting
//      in a week, so its first missing piece is the routine.
//
//  Nothing is in progress, and this week's recap is marked seen, so Today
//  opens on the active block. Use it without the other seed flags: the
//  active-block seed starts its own block, which would end this one.
//  Idempotent: does nothing when a "States Routine" routine already
//  exists. Compiled out of release builds.
//

import Foundation
import SwiftData

enum BlockStatesSeed {
    static let launchArgument = "-fitbod-seed-block-states"

    @MainActor
    static func runIfRequested(in context: ModelContext) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return }
        seed(in: context)
        #endif
    }

    #if DEBUG
    static let routineName = "States Routine"
    static let activeBlockName = "Spring Block"
    static let readyBlockName = "Summer Block"
    static let draftBlockName = "Autumn Block"
    static let loggedSessionName = "Upper A"
    static let emptySessionName = "Upper B"

    /// (session name, catalog name candidates)
    private static let sessions: [(name: String, exercises: [String])] = [
        (loggedSessionName, ["Barbell Bench Press - Medium Grip", "Bench Press - Powerlifting"]),
        (emptySessionName, ["Bent Over Barbell Row", "Barbell Shoulder Press"]),
    ]

    private static let day: TimeInterval = 24 * 3600

    @MainActor
    private static func seed(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Split>())) ?? []
        guard !existing.contains(where: { $0.name == routineName }) else { return }
        let catalog = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let exercises = sessions.compactMap { session in
            session.exercises.lazy.compactMap { name in catalog.first { $0.name == name } }.first
        }
        guard exercises.count == sessions.count else { return }

        let split = Split()
        context.insert(split)
        split.name = routineName

        var slots: [SplitSessionSlot] = []
        for (position, (session, exercise)) in zip(sessions, exercises).enumerated() {
            let template = SessionTemplate()
            context.insert(template)
            template.name = session.name
            template.intentRaw = Intent.strength.rawValue

            let item = SessionExerciseTemplate()
            context.insert(item)
            item.sessionTemplate = template
            item.exercise = exercise
            item.orderIndex = 0
            item.targetSets = 3
            item.targetRepsLow = 5
            item.targetRepsHigh = 8
            item.prescribedRestSeconds = 180

            let slot = SplitSessionSlot()
            context.insert(slot)
            slot.split = split
            slot.position = position
            slot.sessionTemplate = template
            slots.append(slot)
        }
        try? context.save()

        let now = Date.now
        let active = makeBlock(
            activeBlockName,
            phases: [(.accumulation, 2), (.intensification, 1), (.deload, 1)],
            split: split,
            in: context
        )
        try? context.save()
        // Starting goes through the lifecycle service, as the Start button
        // does, dated three days ago.
        try? BlockLifecycleService.start(block: active, context: context, now: now.addingTimeInterval(-3 * day))

        if let upperA = slots.first, let template = upperA.sessionTemplate,
           let workout = try? SessionFactory.start(
               template: template, slot: upperA, activeBlock: active,
               on: now.addingTimeInterval(-2 * day), context: context
           ) {
            for se in workout.exercises ?? [] {
                for set in se.sets ?? [] {
                    set.isComplete = true
                    guard !set.isWarmup else { continue }
                    set.weight = 100
                    set.reps = 5
                    set.rpe = 8
                    set.completedAt = workout.startedAt.addingTimeInterval(Double(set.orderIndex) * 180)
                }
            }
            workout.completedAt = workout.startedAt.addingTimeInterval(45 * 60)
            workout.totalDurationSeconds = 45 * 60
            try? context.save()
        }
        if let upperB = slots.last, let template = upperB.sessionTemplate,
           let workout = try? SessionFactory.start(
               template: template, slot: upperB, activeBlock: active,
               on: now.addingTimeInterval(-1 * day), context: context
           ) {
            workout.completedAt = workout.startedAt.addingTimeInterval(5 * 60)
            workout.totalDurationSeconds = 5 * 60
            try? context.save()
        }

        let ready = makeBlock(
            readyBlockName,
            phases: [(.accumulation, 3), (.deload, 1)],
            split: split,
            in: context
        )
        ready.startDate = Calendar.current.startOfDay(for: now.addingTimeInterval(day))
        ready.schedulingMode = .fixedWeekly
        // Monday and Thursday, one training day per session.
        ready.trainingDays = TrainingDaysWriter.sort(weekdays: [2, 5])

        let draft = makeBlock(draftBlockName, phases: [(.accumulation, 4)], split: nil, in: context)
        draft.startDate = now.addingTimeInterval(7 * day)

        // A finished workout may sit in last week, which would open Today on
        // the weekly recap. Mark it seen.
        if let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first {
            settings.weeklyRecapShownForWeekStart = now.mondayAtMidnightForToday(
                weekStartsMonday: settings.weekStartsMonday
            )
        }
        try? context.save()
    }

    @MainActor
    private static func makeBlock(
        _ name: String,
        phases: [(kind: BlockPhaseKind, weeks: Int)],
        split: Split?,
        in context: ModelContext
    ) -> Block {
        let block = Block()
        context.insert(block)
        block.name = name
        block.schedulingMode = .rotation
        block.split = split
        for (index, row) in phases.enumerated() {
            let phase = BlockPhase()
            context.insert(phase)
            phase.block = block
            phase.orderIndex = index
            phase.nameRaw = row.kind.rawValue
            phase.weeks = row.weeks
        }
        return block
    }
    #endif
}
