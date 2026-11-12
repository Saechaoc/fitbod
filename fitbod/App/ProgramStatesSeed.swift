//
//  ProgramStatesSeed.swift
//  fitbod
//
//  DEBUG-only E2E hook. One launch argument for each Program state that no
//  other seed reaches, so the state can be opened and captured without
//  tapping through the app (RM-011):
//
//    xcrun simctl launch <device> bodybuilding.fitbod -fitbod-seed-program-drafts -fitbod-start-program
//
//    -fitbod-seed-program-drafts      Drafts only: "Hypertrophy Block" with no
//                                     routine, created last, so it leads;
//                                     "Strength Block" with no phases; and an
//                                     untitled block.
//    -fitbod-seed-program-past        No live block and three finished ones:
//                                     "Summer Block" and "Winter Block", which
//                                     ended 30 and 200 days ago, and another
//                                     "Winter Block" that ended 380 days ago,
//                                     in an earlier year for most of this one.
//    -fitbod-seed-program-long-names  Long names on the routine, the active
//                                     block, a ready block, a draft and a past
//                                     block.
//    -fitbod-seed-program-archived    An archived routine and nothing else.
//
//  The routine is TodayStatesSeed's Push A, Pull A and Legs A. A finished
//  block ran through BlockLifecycleService with logged workouts, and its
//  review is marked seen. Use one flag at a time, on an empty store.
//  Idempotent: does nothing when the store holds a routine or a block.
//  Compiled out of release builds.
//

import Foundation
import SwiftData

enum ProgramStatesSeed {

    @MainActor
    static func runIfRequested(in context: ModelContext) {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let state = State.allCases.first(where: { arguments.contains($0.launchArgument) }) else { return }
        seed(state, in: context, now: .now)
        #endif
    }

    #if DEBUG
    enum State: String, CaseIterable {
        case drafts, past, longNames = "long-names", archived

        var launchArgument: String { "-fitbod-seed-program-\(rawValue)" }
    }

    private static let day: TimeInterval = 24 * 3600

    @MainActor
    static func seed(_ state: State, in context: ModelContext, now: Date) {
        let routines = (try? context.fetchCount(FetchDescriptor<Split>())) ?? 0
        let blocks = (try? context.fetchCount(FetchDescriptor<Block>())) ?? 0
        guard routines + blocks == 0 else { return }
        let catalog = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []

        let split = Split()
        context.insert(split)
        split.name = state == .longNames ? "Push Pull Legs with Extra Arm and Calf Work" : TodayStatesSeed.routineName
        let slots = [TodayStatesSeed.push, TodayStatesSeed.pull, TodayStatesSeed.legs].enumerated().map { position, plan in
            let slot = SplitSessionSlot()
            context.insert(slot)
            slot.split = split
            slot.position = position
            slot.sessionTemplate = TodayStatesSeed.makeSession(plan, catalog: catalog, in: context)
            return slot
        }
        try? context.save()

        func makeBlock(_ name: String, weeks: Int, on routine: Split?, createdDaysAgo: Double) -> Block {
            let phases: [(kind: BlockPhaseKind, weeks: Int)] =
                weeks == 0 ? [] : [(.accumulation, weeks - 3), (.intensification, 2), (.deload, 1)]
            let block = BlockStatesSeed.makeBlock(name, phases: phases, split: routine, in: context)
            // A block's startDate is its creation date until it starts (O-14).
            block.startDate = now.addingTimeInterval(-createdDaysAgo * day)
            return block
        }
        /// Runs a block for its weeks, ending `endedDaysAgo` days ago, with a workout every other day.
        func finished(_ name: String, weeks: Int, endedDaysAgo: Double, workouts: Int) {
            let end = now.addingTimeInterval(-endedDaysAgo * day)
            let start = end.addingTimeInterval(-Double(weeks * 7) * day)
            let block = makeBlock(name, weeks: weeks, on: split, createdDaysAgo: endedDaysAgo + Double(weeks * 7))
            try? context.save()
            try? BlockLifecycleService.start(block: block, context: context, now: start)
            for index in 0..<workouts {
                TodayStatesSeed.finish(slots[index % slots.count], block: block,
                                       startedAt: start.addingTimeInterval(Double(2 * index + 1) * day),
                                       duration: 50 * 60, in: context)
            }
            try? BlockLifecycleService.end(block: block, context: context, now: end)
            block.reviewedAt = end
        }

        switch state {
        case .drafts:
            _ = makeBlock("Hypertrophy Block", weeks: 6, on: nil, createdDaysAgo: 1)
            _ = makeBlock("Strength Block", weeks: 0, on: split, createdDaysAgo: 3)
            _ = makeBlock("", weeks: 6, on: split, createdDaysAgo: 6)
        case .past:
            finished("Winter Block", weeks: 4, endedDaysAgo: 380, workouts: 2)
            finished("Winter Block", weeks: 8, endedDaysAgo: 200, workouts: 4)
            finished("Summer Block", weeks: 6, endedDaysAgo: 30, workouts: 3)
        case .longNames:
            finished("The Previous Twelve Week Strength and Hypertrophy Block", weeks: 6, endedDaysAgo: 30, workouts: 2)
            let active = makeBlock("Twelve Week Strength and Hypertrophy Block", weeks: 6, on: split, createdDaysAgo: 10)
            try? context.save()
            try? BlockLifecycleService.start(block: active, context: context, now: now.addingTimeInterval(-8 * day))
            _ = makeBlock("Peaking Block for the Spring Powerlifting Meet", weeks: 6, on: split, createdDaysAgo: 2)
            _ = makeBlock("Off-Season Volume Block Waiting on a Routine", weeks: 6, on: nil, createdDaysAgo: 1)
        case .archived:
            split.isArchived = true
        }

        // A finished workout can sit in last week, which would open Today on the weekly recap.
        if let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first {
            settings.weeklyRecapShownForWeekStart = now.mondayAtMidnightForToday(
                weekStartsMonday: settings.weekStartsMonday
            )
        }
        try? context.save()
    }
    #endif
}
