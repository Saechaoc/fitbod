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

import Foundation
import SwiftData

enum ActiveBlockSeed {
    static let launchArgument = "-fitbod-seed-active-block"

    @MainActor
    static func runIfRequested(in context: ModelContext) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return }
        seed(in: context)
        #endif
    }

    #if DEBUG
    static let routineName = "Live Routine"
    static let sessionName = "Live Push"
    static let blockName = "Live Block"
    private static let exerciseNames = ["Barbell Bench Press - Medium Grip", "Bench Press - Powerlifting"]

    @MainActor
    private static func seed(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Split>())) ?? []
        guard !existing.contains(where: { $0.name == routineName }) else { return }
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        guard let bench = exerciseNames.lazy.compactMap({ name in
            exercises.first { $0.name == name }
        }).first else { return }

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

        // Starting goes through the lifecycle service, as the Start button
        // does, so the block is active exactly the way a user's would be.
        try? BlockLifecycleService.start(block: block, context: context)
    }
    #endif
}
