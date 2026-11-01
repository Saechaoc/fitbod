//
//  ActiveBlockSeed.swift
//  fitbod
//
//  DEBUG-only E2E hook. Launch with `-fitbod-seed-active-block` to get a
//  routine whose session sits on an active block, so the routine and the
//  session editors show the live-edit banner:
//
//    xcrun simctl launch <device> bodybuilding.fitbod -fitbod-seed-active-block
//
//  It creates a "Live Push" session template with the barbell bench press,
//  slots it into a "Live Routine" routine, and starts a "Live Block" on that
//  routine through BlockLifecycleService.start. The block has a name, one
//  accumulation phase and rotation scheduling, so it is ready to start with
//  one session and no training days. Nothing is logged and no workout is in
//  progress.
//
//  Use it without the other seed flags. Idempotent: does nothing when a
//  "Live Routine" routine already exists. Compiled out of release builds.
//
//  `-fitbod-seed-ended-block-recap` seeds the same routine and block, but
//  starts Live Block the week before last, logs one finished Live Push
//  workout in the middle of last week with every work set done, and ends
//  the block through BlockLifecycleService.end. Its review is left
//  unacknowledged and this week's recap unseen, so Today's next visit has
//  both due (T87). Launch it without the other seed flags, including
//  `-fitbod-seed-active-block`, and with `-fitbod-start-program`: on a
//  fresh store Today can first show before the seed runs.
//
//  `-fitbod-seed-ended-heavy-block` seeds the same ended block, but its
//  workout's work sets are 80,000 x 5, so the block's TONNAGE is 1,200,000
//  (T113). Launch it the same way, without the other seed flags.
//

import Foundation
import SwiftData

enum ActiveBlockSeed {
    static let launchArgument = "-fitbod-seed-active-block"

    @MainActor
    static func runIfRequested(in context: ModelContext) {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(launchArgument) {
            seed(in: context)
        } else if arguments.contains(endedBlockRecapLaunchArgument) {
            seedEndedBlockWithRecap(workSetWeight: 100, in: context)
        } else if arguments.contains(endedHeavyBlockLaunchArgument) {
            seedEndedBlockWithRecap(workSetWeight: 80_000, in: context)
        }
        #endif
    }

    #if DEBUG
    static let endedBlockRecapLaunchArgument = "-fitbod-seed-ended-block-recap"
    static let endedHeavyBlockLaunchArgument = "-fitbod-seed-ended-heavy-block"
    static let routineName = "Live Routine"
    static let sessionName = "Live Push"
    static let blockName = "Live Block"
    private static let exerciseNames = ["Barbell Bench Press - Medium Grip", "Bench Press - Powerlifting"]
    private static let day: TimeInterval = 24 * 3600

    @MainActor
    private static func seed(in context: ModelContext) {
        guard let live = makeLiveBlock(in: context) else { return }
        // Starting goes through the lifecycle service, as the Start button
        // does, so the block is active exactly the way a user's would be.
        try? BlockLifecycleService.start(block: live.block, context: context)
    }

    /// Live Block ended after one Live Push workout last week, whose work
    /// sets are each `workSetWeight` x 5.
    @MainActor
    private static func seedEndedBlockWithRecap(workSetWeight: Double, in context: ModelContext) {
        guard let live = makeLiveBlock(in: context), let template = live.slot.sessionTemplate else { return }
        let now = Date.now
        let weekStartsMonday = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first?.weekStartsMonday ?? true
        // Today's recap covers the week before this one.
        let lastWeek = now.mondayAtMidnightForToday(weekStartsMonday: weekStartsMonday).addingTimeInterval(-7 * day)
        try? BlockLifecycleService.start(block: live.block, context: context, now: lastWeek.addingTimeInterval(-7 * day))

        if let workout = try? SessionFactory.start(
            template: template, slot: live.slot, activeBlock: live.block,
            on: lastWeek.addingTimeInterval(3.5 * day), context: context
        ) {
            for se in workout.exercises ?? [] {
                for set in se.sets ?? [] {
                    set.isComplete = true
                    guard !set.isWarmup else { continue }
                    set.weight = workSetWeight
                    set.reps = 5
                    set.rpe = 8
                    set.completedAt = workout.startedAt.addingTimeInterval(Double(set.orderIndex) * 180)
                }
            }
            workout.completedAt = workout.startedAt.addingTimeInterval(45 * 60)
            workout.totalDurationSeconds = 45 * 60
            try? context.save()
        }

        // Ending goes through the lifecycle service, as END BLOCK does.
        try? BlockLifecycleService.end(block: live.block, context: context, now: now)
    }

    /// Live Push on Live Routine, and Live Block on that routine, saved but
    /// not started. Nil when Live Routine exists or the catalog has no
    /// bench press.
    @MainActor
    private static func makeLiveBlock(in context: ModelContext) -> (block: Block, slot: SplitSessionSlot)? {
        let existing = (try? context.fetch(FetchDescriptor<Split>())) ?? []
        guard !existing.contains(where: { $0.name == routineName }) else { return nil }
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        guard let bench = exerciseNames.lazy.compactMap({ name in
            exercises.first { $0.name == name }
        }).first else { return nil }

        let template = SessionTemplate()
        context.insert(template)
        template.name = sessionName
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

        let split = Split()
        context.insert(split)
        split.name = routineName

        let slot = SplitSessionSlot()
        context.insert(slot)
        slot.split = split
        slot.position = 0
        slot.sessionTemplate = template

        let block = Block()
        context.insert(block)
        block.name = blockName
        block.schedulingMode = .rotation
        block.split = split

        let phase = BlockPhase()
        context.insert(phase)
        phase.block = block
        phase.orderIndex = 0
        phase.nameRaw = BlockPhaseKind.accumulation.rawValue
        phase.weeks = 4
        try? context.save()
        return (block, slot)
    }
    #endif
}
