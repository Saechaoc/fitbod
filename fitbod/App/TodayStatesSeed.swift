//
//  TodayStatesSeed.swift
//  fitbod
//
//  DEBUG-only E2E hook. One launch argument for each Today state that no
//  other seed reaches, so the state can be opened and captured without
//  tapping through the app (RM-006):
//
//    xcrun simctl launch <device> bodybuilding.fitbod -fitbod-seed-today-done
//
//    -fitbod-seed-today-ready   T-READY: no active block and two ready blocks.
//                               "Spring Block" was created first, so it leads.
//    -fitbod-seed-today-empty   T-FIX: an active rotation block whose next
//                               session, "Push B", has no exercises.
//    -fitbod-seed-today-done    T-DONE: an active block with Push A and then
//                               Pull A finished today.
//    -fitbod-seed-today-rest    T-REST: an active weekly block whose training
//                               days leave today out.
//    -fitbod-seed-today-attach  T-ATTACH: an active block whose routine is
//                               gone, as restored data can leave it.
//    -fitbod-seed-today-pick    T-PICK: no block; a routine whose Push A was
//                               finished two days ago and whose Legs A is
//                               empty; and "Arms", a session in no routine.
//
//  Every state uses a "Push Pull Legs" routine. A workout finished today is
//  stamped between local midnight and launch, its sets inside it, so it
//  stays on today at any hour. This week's recap is marked seen, so Today
//  opens on the state. Use one flag at a time, on an empty store.
//  Idempotent: does nothing when a "Push Pull Legs" routine already exists.
//  Compiled out of release builds.
//
//  The other states have seeds already: T-TODAY is
//  `-fitbod-seed-block-states`, T-RESUME is `-fitbod-seed-demo-workout`, and
//  T-FIRST is an empty store.
//

import Foundation
import SwiftData

enum TodayStatesSeed {

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
        case ready, empty, done, rest, attach, pick

        var launchArgument: String { "-fitbod-seed-today-\(rawValue)" }
    }

    static let routineName = "Push Pull Legs"
    static let blockName = "Spring Block"
    static let laterReadyBlockName = "Summer Block"
    static let emptySessionName = "Push B"
    static let standaloneSessionName = "Arms"

    typealias SessionPlan = (name: String, exercises: [String])
    private static let push: SessionPlan = ("Push A", ["Barbell Bench Press - Medium Grip", "Barbell Shoulder Press"])
    private static let pull: SessionPlan = ("Pull A", ["Bent Over Barbell Row", "Wide-Grip Lat Pulldown"])
    private static let legs: SessionPlan = ("Legs A", ["Barbell Squat", "Romanian Deadlift"])
    private static let arms: SessionPlan = (standaloneSessionName, ["Barbell Curl", "Triceps Pushdown"])
    /// Every catalog exercise the seeds name; a test store needs these rows first.
    static var catalogNames: [String] { [push, pull, legs, arms].flatMap(\.exercises) }

    /// Six weeks in three phases, so a block started eight days ago reads "Week 2 of 6".
    private static let phases: [(kind: BlockPhaseKind, weeks: Int)] = [
        (.accumulation, 3), (.intensification, 2), (.deload, 1),
    ]
    private static let day: TimeInterval = 24 * 3600

    @MainActor
    static func seed(_ state: State, in context: ModelContext, now: Date) {
        let routines = (try? context.fetch(FetchDescriptor<Split>())) ?? []
        guard !routines.contains(where: { $0.name == routineName }) else { return }
        let catalog = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []

        // The routine's sessions in slot order; no exercise names makes an empty session.
        let plans: [SessionPlan] = switch state {
        case .empty: [(emptySessionName, []), pull, legs]
        case .pick: [push, pull, (legs.name, [])]
        default: [push, pull, legs]
        }
        let split = Split()
        context.insert(split)
        split.name = routineName
        let slots = plans.enumerated().map { position, plan in
            let slot = SplitSessionSlot()
            context.insert(slot)
            slot.split = split
            slot.position = position
            slot.sessionTemplate = makeSession(plan, catalog: catalog, in: context)
            return slot
        }
        try? context.save()

        func makeBlock(_ name: String) -> Block {
            BlockStatesSeed.makeBlock(name, phases: phases, split: split, in: context)
        }
        switch state {
        case .ready:
            // A block's startDate is its creation date until it starts (O-14).
            makeBlock(blockName).startDate = now.addingTimeInterval(-6 * day)
            makeBlock(laterReadyBlockName).startDate = now.addingTimeInterval(-2 * day)
        case .empty:
            start(makeBlock(blockName), at: now, in: context)
        case .done:
            let block = makeBlock(blockName)
            start(block, at: now, in: context)
            let midnight = Calendar.current.startOfDay(for: now)
            let sinceMidnight = now.timeIntervalSince(midnight)
            finish(slots[0], block: block, startedAt: midnight.addingTimeInterval(sinceMidnight * 0.2),
                   duration: min(47 * 60, sinceMidnight * 0.25), in: context)
            finish(slots[1], block: block, startedAt: midnight.addingTimeInterval(sinceMidnight * 0.6),
                   duration: min(35 * 60, sinceMidnight * 0.25), in: context)
        case .rest:
            let block = makeBlock(blockName)
            block.schedulingMode = .fixedWeekly
            // One training day per session, none of them today: tomorrow, then every other day.
            let today = Calendar.current.component(.weekday, from: now)
            block.trainingDays = TrainingDaysWriter.sort(weekdays: [1, 3, 5].map { (today - 1 + $0) % 7 + 1 })
            start(block, at: now, in: context)
        case .attach:
            let block = makeBlock(blockName)
            start(block, at: now, in: context)
            block.split = nil
        case .pick:
            _ = makeSession(arms, catalog: catalog, in: context)
            finish(slots[0], block: nil, startedAt: now.addingTimeInterval(-2 * day), duration: 47 * 60, in: context)
        }

        // A workout two days ago can sit in last week, which would open Today on the weekly recap.
        if let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first {
            settings.weeklyRecapShownForWeekStart = now.mondayAtMidnightForToday(
                weekStartsMonday: settings.weekStartsMonday
            )
        }
        try? context.save()
    }

    @MainActor
    private static func makeSession(_ plan: SessionPlan, catalog: [Exercise], in context: ModelContext) -> SessionTemplate {
        let template = SessionTemplate()
        context.insert(template)
        template.name = plan.name
        template.intentRaw = Intent.hypertrophy.rawValue
        let exercises = plan.exercises.compactMap { name in catalog.first { $0.name == name } }
        assert(exercises.count == plan.exercises.count, "the catalog lacks an exercise \(plan.name) names")
        for (index, exercise) in exercises.enumerated() {
            let item = SessionExerciseTemplate()
            context.insert(item)
            item.sessionTemplate = template
            item.exercise = exercise
            item.orderIndex = index
            item.targetSets = 3
            item.targetRepsLow = 8
            item.targetRepsHigh = 12
            item.prescribedRestSeconds = 120
        }
        return template
    }

    /// Starts the block eight days before `now` through the lifecycle service, as the Start button does.
    @MainActor
    private static func start(_ block: Block, at now: Date, in context: ModelContext) {
        try? context.save()
        try? BlockLifecycleService.start(block: block, context: context, now: now.addingTimeInterval(-8 * day))
    }

    /// Starts the slot's session as the app does, logs every set and finishes the workout.
    @MainActor
    private static func finish(
        _ slot: SplitSessionSlot, block: Block?, startedAt: Date, duration: TimeInterval, in context: ModelContext
    ) {
        guard let template = slot.sessionTemplate,
              let workout = try? SessionFactory.start(
                  template: template, slot: slot, activeBlock: block, on: startedAt, context: context
              )
        else { return }
        let sets = (workout.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .flatMap { ($0.sets ?? []).sorted { $0.orderIndex < $1.orderIndex } }
        for (index, set) in sets.enumerated() {
            set.isComplete = true
            set.completedAt = startedAt.addingTimeInterval(duration * Double(index + 1) / Double(sets.count + 1))
            guard !set.isWarmup else { continue }
            set.weight = 100
            set.reps = 8
            set.rpe = 8
        }
        workout.completedAt = startedAt.addingTimeInterval(duration)
        workout.totalDurationSeconds = Int(duration)
        try? context.save()
    }
    #endif
}
