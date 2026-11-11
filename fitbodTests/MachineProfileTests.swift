//
//  MachineProfileTests.swift
//  fitbodTests
//
//  RM-066: a logged exercise names the machine it was done on. Loads
//  compare only within one machine: last time, the prescription, PRs,
//  the stall check and Compare read that machine's workouts, and a
//  machine without a workout of its own shows another one's for
//  reference without carrying its load over. A new log starts on the
//  exercise's last machine, and a change mid-workout moves or keeps the
//  finished sets.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("Machine profiles", .serialized)
struct MachineProfileTests {

    private let day: TimeInterval = 24 * 3600

    // MARK: - Names

    @Test("a machine's name, cleaned text, and one machine per name whatever the case and spacing")
    func names() throws {
        #expect(MachineProfile.displayName(manufacturer: "Panatta", model: "Super Hack Squat") == "Panatta Super Hack Squat")
        #expect(MachineProfile.displayName(manufacturer: "Hammer Strength", model: "hammer strength Row") == "hammer strength Row")
        #expect(MachineProfile.displayName(manufacturer: nil, model: "Blue sled") == "Blue sled")
        #expect(MachineProfile.displayName(manufacturer: "Cybex", model: nil) == "Cybex")
        #expect(MachineProfile.cleaned("  Super   Hack\tSquat ") == "Super Hack Squat")
        #expect(MachineProfile.cleaned("   ") == nil)

        let ctx = try LoggerFixtures.makeContext()
        let first = try #require(SessionMachine.findOrCreate(manufacturer: "Panatta", model: "Super Hack Squat", in: ctx))
        let again = SessionMachine.findOrCreate(manufacturer: " panatta", model: "super  hack squat ", in: ctx)
        #expect(again?.id == first.id)
        // The maker typed into the name is the same machine, as it shows the same name.
        #expect(SessionMachine.findOrCreate(manufacturer: nil, model: "Panatta super hack squat", in: ctx)?.id == first.id)
        #expect(SessionMachine.findOrCreate(manufacturer: nil, model: " ", in: ctx) == nil)
        #expect(try ctx.fetchCount(FetchDescriptor<MachineProfile>()) == 1)
    }

    // MARK: - The default

    @Test("a new log starts on the machine the exercise was last done on, in this workout or the last finished one")
    func newLogStartsOnTheLastMachine() throws {
        let ctx = try LoggerFixtures.makeContext()
        let hack = machineExercise("Hack Squat (Machine)", in: ctx)
        let arsenal = machine("Arsenal Strength", "Reloaded Linear Hack Squat", in: ctx)
        let panatta = machine("Panatta", "Super Hack Squat", in: ctx)
        try workout(hack, daysAgo: 7, on: arsenal, sets: [(200, 8)], in: ctx)
        try workout(hack, daysAgo: 3, on: panatta, sets: [(150, 8)], in: ctx)
        #expect(SessionMachine.lastUsed(for: hack, during: nil, in: ctx)?.id == panatta.id)
        // A later workout that put it on the Arsenal but did no set there
        // leaves the Panatta the last one used.
        let skipped = try LoggerFixtures.session(
            exercise: hack, startedAt: Date.now.addingTimeInterval(-day), completedAt: Date.now.addingTimeInterval(-day / 2),
            sets: [(weight: 200, reps: 0, complete: false)], in: ctx
        )
        skipped.exercises?.first?.machine = arsenal
        try ctx.save()
        #expect(SessionMachine.lastUsed(for: hack, during: nil, in: ctx)?.id == panatta.id)

        // A barbell takes no machine, whatever its logs say.
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        try workout(bench, daysAgo: 2, on: arsenal, sets: [(100, 5)], in: ctx)
        #expect(SessionMachine.lastUsed(for: bench, during: nil, in: ctx) == nil)

        // Starting from a routine puts the log on that machine.
        let template = try LoggerFixtures.template("Legs", exercises: [hack], in: ctx)
        let session = try SessionFactory.start(template: template, context: ctx)
        let log = try #require(session.exercises?.first)
        #expect(log.machine?.id == panatta.id)
        // Its last time and prescription come from the Panatta's 150.
        let hint = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: hack.id, intentRaw: session.intentRaw, context: ctx,
            excludingSessionID: session.id, machineID: log.machine?.id
        )
        #expect(hint?.weight == 150 && hint?.onOtherMachine == false)

        // A set done on the Arsenal in the workout in progress makes it the
        // last machine there, so the exercise added again starts on it.
        let current = try workout(hack, daysAgo: 0, on: arsenal, sets: [(210, 6)], finished: false, in: ctx)
        #expect(SessionMachine.lastUsed(for: hack, during: current, in: ctx)?.id == arsenal.id)
        #expect(SessionMachine.lastUsed(for: hack, during: nil, in: ctx)?.id == panatta.id)
    }

    // MARK: - Comparing loads

    @Test("last time reads the log's own machine, and another machine's set only as a reference")
    func lastTimeReadsOneMachine() throws {
        let ctx = try LoggerFixtures.makeContext()
        let hack = machineExercise("Hack Squat (Machine)", in: ctx)
        let arsenal = machine("Arsenal Strength", "Reloaded Linear Hack Squat", in: ctx)
        let panatta = machine("Panatta", "Super Hack Squat", in: ctx)
        let unused = machine("Cybex", "Hack Squat", in: ctx)
        try workout(hack, daysAgo: 7, on: arsenal, sets: [(200, 8)], in: ctx)
        try workout(hack, daysAgo: 3, on: panatta, sets: [(150, 8)], in: ctx)

        func hit(_ machine: MachineProfile?) -> PreviousMatchingIntentHit? {
            PreviousMatchingIntent.fetchTopWorkingSet(
                exerciseID: hack.id, intentRaw: Intent.strength.rawValue, context: ctx, machineID: machine?.id
            )
        }
        #expect(hit(arsenal)?.weight == 200 && hit(arsenal)?.onOtherMachine == false)
        #expect(hit(panatta)?.weight == 150 && hit(panatta)?.onOtherMachine == false)
        // No workout on the Cybex, or without a machine: the newest workout
        // on any machine, marked as another machine's.
        for machine in [unused, nil] {
            let reference = try #require(hit(machine))
            #expect(reference.weight == 150 && reference.onOtherMachine)
            #expect(reference.machineName == "Panatta Super Hack Squat")
        }
    }

    @Test("the prescription progresses one machine's sets and carries nothing over to another")
    func prescriptionReadsOneMachine() throws {
        let ctx = try LoggerFixtures.makeContext()
        let hack = machineExercise("Hack Squat (Machine)", in: ctx)
        let arsenal = machine("Arsenal Strength", "Reloaded Linear Hack Squat", in: ctx)
        let panatta = machine("Panatta", "Super Hack Squat", in: ctx)
        // Every set at the top of the range, so the Arsenal earns a bump.
        try workout(hack, daysAgo: 7, on: arsenal, sets: [(200, 8), (200, 8), (200, 8)], in: ctx)
        let today = Session()
        ctx.insert(today)
        today.intentRaw = Intent.strength.rawValue

        func prescription(on machine: MachineProfile?) -> SessionFactory.ExercisePrescription {
            SessionFactory.prescription(
                for: hack, targetRepsLow: 5, targetRepsHigh: 8, targetRPE: nil, in: today,
                strategy: DoubleProgressionStrategy(), userSettings: nil, context: ctx, machine: machine
            )
        }
        let same = prescription(on: arsenal)
        #expect(same.explanation.bumpOccurred && same.explanation.suggestedWeight != nil)
        #expect(same.previousWorkingSets.count == 3 && same.otherMachineReference == nil)

        for other in [panatta, nil] {
            let fresh = prescription(on: other)
            #expect(fresh.weight == 0 && fresh.explanation.suggestedWeight == nil)
            #expect(fresh.previousWorkingSets.isEmpty, "no set offers from another machine")
            #expect(fresh.otherMachineReference?.weight == 200)
            #expect(fresh.otherMachineReference?.machineName == "Arsenal Strength Reloaded Linear Hack Squat")
        }
    }

    @Test("a PR is the best on its own machine")
    func prsCountPerMachine() throws {
        let ctx = try LoggerFixtures.makeContext()
        let hack = machineExercise("Hack Squat (Machine)", in: ctx)
        let arsenal = machine("Arsenal Strength", "Reloaded Linear Hack Squat", in: ctx)
        let panatta = machine("Panatta", "Super Hack Squat", in: ctx)
        try workout(hack, daysAgo: 9, on: arsenal, sets: [(200, 8)], in: ctx)
        try workout(hack, daysAgo: 5, on: panatta, sets: [(150, 8)], in: ctx)
        let best = try workout(hack, daysAgo: 1, on: panatta, sets: [(160, 8)], in: ctx)

        let sets = try ctx.fetch(FetchDescriptor<SetEntry>())
        var table = PRTable()
        let hits = PRDetector.replay(sets, into: &table)
        let bestSet = try #require(best.exercises?.first?.sets?.first)
        let kinds = hits.first { $0.set.id == bestSet.id }?.kinds ?? []
        #expect(kinds.contains(.weight), "160 beats the Panatta's 150; the Arsenal's 200 does not count")
    }

    @Test("the stall check reads one machine's workouts")
    func stallCheckReadsOneMachine() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let hack = machineExercise("Hack Squat (Machine)", in: ctx)
        let settings = UserSettings.default()
        ctx.insert(settings)
        let arsenal = machine("Arsenal Strength", "Reloaded Linear Hack Squat", in: ctx)
        let sessions = try FatigueTestFixtures.weeklySessions(
            forExercise: hack, weights: [100, 100, 100, 100], reps: [5, 5, 5, 5],
            weekStart: Date.now.addingTimeInterval(-7 * day), in: ctx
        )
        for session in sessions { session.exercises?.first?.machine = arsenal }
        try ctx.save()

        func signal(_ machine: MachineProfile?) -> PlateauSignal {
            PlateauDetector.evaluate(
                exerciseID: hack.id, intent: .strength, in: ctx, settings: settings, machineID: machine?.id
            )
        }
        guard case .stalled = signal(arsenal) else {
            Issue.record("four flat workouts on the Arsenal stall it, got \(signal(arsenal))")
            return
        }
        #expect(signal(nil) == .notEnoughData)
        #expect(signal(machine("Panatta", "Super Hack Squat", in: ctx)) == .notEnoughData)
    }

    @Test("Compare matches each machine's sets with the last workout on that machine")
    func compareReadsOneMachine() throws {
        let ctx = try LoggerFixtures.makeContext()
        let hack = machineExercise("Hack Squat (Machine)", in: ctx)
        let panatta = machine("Panatta", "Super Hack Squat", in: ctx)
        let arsenal = machine("Arsenal Strength", "Reloaded Linear Hack Squat", in: ctx)
        let tenDaysAgo = try workout(hack, daysAgo: 10, on: panatta, sets: [(130, 8)], in: ctx)
        let fiveDaysAgo = try workout(hack, daysAgo: 5, on: arsenal, sets: [(200, 8)], in: ctx)
        let today = try workout(hack, daysAgo: 0, on: panatta, sets: [(140, 8)], in: ctx)
        // The last set today was on the Arsenal, after a switch.
        let switched = SessionExercise()
        ctx.insert(switched)
        switched.session = today
        switched.exercise = hack
        switched.machine = arsenal
        switched.orderIndex = 1
        let set = SetEntry()
        ctx.insert(set)
        set.sessionExercise = switched
        set.weight = 210
        set.reps = 6
        set.isComplete = true
        set.completedAt = today.startedAt
        let routineID = UUID()
        for session in [tenDaysAgo, fiveDaysAgo, today] { session.sourceRoutineID = routineID }
        try ctx.save()

        let rows = SessionComparator.compare(current: today, context: ctx)
        #expect(rows.map(\.machineName) == [panatta.displayName, arsenal.displayName])
        #expect(rows.first?.lastWeekTopSet?.weight == 130, "the Panatta sets compare with the Panatta workout")
        #expect(rows.first?.deltaWeight == 10)
        #expect(rows.last?.lastWeekTopSet?.weight == 200)
        #expect(rows.last?.deltaWeight == 10)
    }

    // MARK: - Changing the machine

    @Test("a correction moves the finished sets to the new machine")
    func correctionMovesTheFinishedSets() throws {
        let ctx = try LoggerFixtures.makeContext()
        let (session, log, arsenal) = try workoutInProgress(in: ctx)

        #expect(SessionMachine.change(
            log, toManufacturer: "Panatta", model: "Super Hack Squat", splittingFinishedSets: false, context: ctx
        ))
        #expect(session.exercises?.count == 1)
        #expect(log.machine?.displayName == "Panatta Super Hack Squat" && log.machine?.id != arsenal.id)
        let sets = SessionSetActions.ordered(log)
        #expect(sets.filter(\.isComplete).map(\.weight) == [200, 200], "finished sets keep their values")
        #expect(sets.filter { !$0.isComplete }.allSatisfy { $0.weight == 0 && $0.reps == 0 },
                "a set still to do is cleared for the new machine's offer")
    }

    @Test("a switch partway through keeps the finished sets on the old machine")
    func switchKeepsTheFinishedSets() throws {
        let ctx = try LoggerFixtures.makeContext()
        let (session, log, arsenal) = try workoutInProgress(in: ctx)

        #expect(SessionMachine.change(
            log, toManufacturer: "Panatta", model: "Super Hack Squat", splittingFinishedSets: true, context: ctx
        ))
        let logs = (session.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        #expect(logs.count == 2)
        #expect(logs.first?.machine?.id == arsenal.id)
        #expect(logs.first.map(SessionSetActions.ordered)?.map(\.weight) == [200, 200])
        #expect(logs.last?.id == log.id && log.machine?.model == "Super Hack Squat")
        #expect(SessionSetActions.ordered(log).allSatisfy { !$0.isComplete })

        // The sets still to do get no offer from the Arsenal's 200.
        let offers = WorkoutSetSuggestions(exercise: log, prior: []).offers()
        #expect(!offers.isEmpty && offers.values.allSatisfy { $0.weight == nil })

        // Choosing the machine it is on changes nothing.
        #expect(SessionMachine.change(
            log, toManufacturer: "panatta", model: "super hack squat", splittingFinishedSets: true, context: ctx
        ))
        #expect(session.exercises?.count == 2)
    }

    @Test("a swap starts the new exercise on its own last machine, and undo brings the old one back")
    func swapAndUndo() throws {
        let ctx = try LoggerFixtures.makeContext()
        let hack = machineExercise("Hack Squat (Machine)", in: ctx)
        let press = machineExercise("Leg Press (Machine)", in: ctx)
        let arsenal = machine("Arsenal Strength", "Reloaded Linear Hack Squat", in: ctx)
        let cybex = machine("Cybex", "Leg Press", in: ctx)
        try workout(press, daysAgo: 4, on: cybex, sets: [(300, 10)], in: ctx)
        let session = try workout(hack, daysAgo: 0, on: arsenal, sets: [(0, 0)], finished: false, in: ctx)
        let log = try #require(session.exercises?.first)
        log.sets?.first?.isComplete = false
        try ctx.save()

        let original = VariationUndoSnapshot(log)
        #expect(SwapExerciseSheet.swap(log, to: press, context: ctx))
        #expect(log.machine?.id == cybex.id)
        try original.restore(to: log, context: ctx)
        #expect(log.exercise?.id == hack.id && log.machine?.id == arsenal.id)
    }

    // MARK: - History

    @Test("history names each workout's machine and filters by machine, the most recent first")
    func historyByMachine() throws {
        let ctx = try LoggerFixtures.makeContext()
        let hack = machineExercise("Hack Squat (Machine)", in: ctx)
        let arsenal = machine("Arsenal Strength", "Reloaded Linear Hack Squat", in: ctx)
        let panatta = machine("Panatta", "Super Hack Squat", in: ctx)
        try workout(hack, daysAgo: 9, on: nil, sets: [(180, 8)], in: ctx)
        try workout(hack, daysAgo: 6, on: arsenal, sets: [(200, 8), (200, 8)], in: ctx)
        try workout(hack, daysAgo: 2, on: panatta, sets: [(150, 8)], in: ctx)
        let logs = PreviousMatchingIntent.logs(of: hack.id, context: ctx)

        let all = ExerciseHistoryView.completedSets(from: logs, intent: nil)
        #expect(ExerciseHistoryView.machineOptions(in: all).map(\.label) == [
            "Panatta Super Hack Squat", "Arsenal Strength Reloaded Linear Hack Squat", "No machine",
        ])
        let rows = ExerciseHistoryView.rows(from: all, prSetIDs: [])
        #expect(rows.map(\.machineLabel) == ["Panatta Super Hack Squat", "Arsenal Strength Reloaded Linear Hack Squat", nil])

        let onArsenal = ExerciseHistoryView.completedSets(from: logs, intent: nil, machine: .machine(arsenal.id))
        #expect(onArsenal.map(\.setEntry.weight) == [200, 200])
        let onNone = ExerciseHistoryView.completedSets(from: logs, intent: nil, machine: .noMachine)
        #expect(onNone.map(\.setEntry.weight) == [180])
    }

    // MARK: - The picker

    @Test("the picker lists this exercise's machines newest first, known models it lacks, then other recent machines")
    func pickerChoices() throws {
        let ctx = try LoggerFixtures.makeContext()
        let hack = machineExercise("Hack Squat (Machine)", in: ctx)
        hack.familyName = "Hack Squat"
        let press = machineExercise("Leg Press (Machine)", in: ctx)
        let panatta = machine("Panatta", "Super Hack Squat", in: ctx)
        let gym = machine(nil, "Gym 2 hack", in: ctx)
        let cybex = machine("Cybex", "Leg Press", in: ctx)
        try workout(hack, daysAgo: 10, on: panatta, sets: [(150, 8)], in: ctx)
        try workout(hack, daysAgo: 5, on: gym, sets: [(140, 8)], in: ctx)
        try workout(press, daysAgo: 3, on: cybex, sets: [(300, 10)], in: ctx)

        let choices = SessionMachine.choices(for: hack, in: ctx)
        #expect(choices.usedForExercise.map(\.id) == [gym.id, panatta.id])
        #expect(choices.recent.map(\.id) == [cybex.id])
        #expect(choices.suggested.map(\.displayName) == [
            "Arsenal Strength Reloaded Hip Hack Press", "Arsenal Strength Reloaded Linear Hack Squat",
        ], "the Panatta is listed already, so it is not suggested again")

        // The known models are machines, so a cable raise gets none.
        let raise = Exercise.previewSample(name: "Lateral Raise (Cable)", equipment: .cable, mechanic: .isolation)
        ctx.insert(raise)
        raise.familyName = "Lateral Raise"
        #expect(!MachineCatalog.models(forFamily: "Lateral Raise").isEmpty)
        #expect(SessionMachine.choices(for: raise, in: ctx).suggested.isEmpty)
    }

    @Test("the bundled machine models name real makers and families, once each")
    func machineCatalog() throws {
        let models = MachineCatalog.models
        #expect(models.count == 80)
        let keys = models.map { "\($0.manufacturer)|\($0.model)".lowercased() }
        #expect(Set(keys).count == keys.count, "a model is listed twice")
        let families = Set(try ExerciseCatalog.bundled().filter { !$0.isHidden }.compactMap(\.familyName))
        for model in models {
            #expect(MachineBrand(rawValue: model.manufacturer) != nil, "\(model.displayName) has an unknown maker")
            #expect(!model.families.isEmpty, "\(model.displayName) trains no family")
            for family in model.families where !families.contains(family) {
                Issue.record("\(model.displayName) names \(family), which no listed row is in")
            }
        }
    }

    // MARK: - Helpers

    private func machineExercise(_ name: String, in ctx: ModelContext) -> Exercise {
        let exercise = Exercise.previewSample(name: name, equipment: .machine, mechanic: .compound)
        ctx.insert(exercise)
        return exercise
    }

    private func machine(_ manufacturer: String?, _ model: String, in ctx: ModelContext) -> MachineProfile {
        let machine = MachineProfile()
        ctx.insert(machine)
        machine.manufacturer = manufacturer
        machine.model = model
        return machine
    }

    /// A strength workout of one exercise on `machine`, every set done.
    @discardableResult
    private func workout(
        _ exercise: Exercise, daysAgo: Double, on machine: MachineProfile?, sets: [(Double, Int)],
        finished: Bool = true, in ctx: ModelContext
    ) throws -> Session {
        let start = Date.now.addingTimeInterval(-daysAgo * day)
        let session = try LoggerFixtures.session(
            exercise: exercise, startedAt: start, completedAt: finished ? start.addingTimeInterval(3600) : nil,
            sets: sets.map { (weight: $0.0, reps: $0.1, complete: true) }, in: ctx
        )
        session.exercises?.first?.machine = machine
        try ctx.save()
        return session
    }

    /// A hack squat in progress on the Arsenal: two sets done at 200, one to do.
    private func workoutInProgress(in ctx: ModelContext) throws -> (Session, SessionExercise, MachineProfile) {
        let hack = machineExercise("Hack Squat (Machine)", in: ctx)
        let arsenal = machine("Arsenal Strength", "Reloaded Linear Hack Squat", in: ctx)
        let session = try workout(hack, daysAgo: 0, on: arsenal, sets: [(200, 8), (200, 8), (200, 8)], finished: false, in: ctx)
        let log = try #require(session.exercises?.first)
        SessionSetActions.ordered(log).last?.isComplete = false
        try ctx.save()
        return (session, log, arsenal)
    }
}
