//
//  PowerbuildingSeed.swift
//  fitbod
//
//  DEBUG-only E2E hook. Launch with `-fitbod-seed-powerbuilding` to get a
//  block whose one-word name is wider than the small phone's hero, on a
//  routine whose sessions each hold one exercise (ticket T26):
//
//    xcrun simctl launch <device> bodybuilding.fitbod -fitbod-seed-powerbuilding
//
//  It creates an "Upper Lower" routine with three sessions of one exercise,
//  three sets of 5-8 and 3:00 rest each: "Upper A" (the barbell bench
//  press), "Lower A" (the barbell squat) and "Upper B" (the barbell row).
//  Two blocks are named "Powerbuilding", with accumulation 3 weeks,
//  intensification 1 week and deload 1 week:
//
//    - active, on the routine with rotation, started yesterday through
//      BlockLifecycleService.start, so it is in week 1 of 5, accumulation,
//      with nothing logged.
//    - draft, with no routine, starting in a week, so the block overview
//      shows its name in the hero.
//
//  Nothing is in progress, and this week's recap is marked seen, so Today
//  opens on the active block. Use it without the other seed flags: the
//  other block seeds start their own blocks, which would end this one.
//  Idempotent: does nothing when an "Upper Lower" routine already exists.
//  Compiled out of release builds.
//

import Foundation
import SwiftData

enum PowerbuildingSeed {
    static let launchArgument = "-fitbod-seed-powerbuilding"

    @MainActor
    static func runIfRequested(in context: ModelContext) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return }
        seed(in: context)
        #endif
    }

    #if DEBUG
    static let routineName = "Upper Lower"
    static let blockName = "Powerbuilding"

    /// (session name, catalog name candidates)
    private static let sessions: [(name: String, exercises: [String])] = [
        ("Upper A", ["Barbell Bench Press - Medium Grip", "Bench Press - Powerlifting"]),
        ("Lower A", ["Barbell Squat", "Barbell Full Squat"]),
        ("Upper B", ["Bent Over Barbell Row", "Barbell Shoulder Press"]),
    ]

    private static let phases: [(kind: BlockPhaseKind, weeks: Int)] = [
        (.accumulation, 3), (.intensification, 1), (.deload, 1),
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
        }
        try? context.save()

        let now = Date.now
        let active = makeBlock(split: split, in: context)
        try? context.save()
        // Starting goes through the lifecycle service, as the Start button
        // does, dated yesterday.
        try? BlockLifecycleService.start(block: active, context: context, now: now.addingTimeInterval(-day))

        let draft = makeBlock(split: nil, in: context)
        draft.startDate = now.addingTimeInterval(7 * day)

        if let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first {
            settings.weeklyRecapShownForWeekStart = now.mondayAtMidnightForToday(
                weekStartsMonday: settings.weekStartsMonday
            )
        }
        try? context.save()
    }

    @MainActor
    private static func makeBlock(split: Split?, in context: ModelContext) -> Block {
        let block = Block()
        context.insert(block)
        block.name = blockName
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
