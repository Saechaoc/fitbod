// SessionMachine.swift
// fitbod
//
// The machine a logged exercise is done on (RM-066): the default a new log
// starts with, the choices the machine picker offers, naming a machine, and
// a change partway through a workout. A machine belongs to one workout's log,
// so choosing one never touches another workout or the exercise itself.

import Foundation
import SwiftData

/// Known machine models, bundled read-only in `machine-models.json`: the
/// picker suggests the ones that train an exercise's family, so a common
/// machine is one tap away before the lifter has named any. Every model is a
/// plate-loaded or selectorized machine, so only `.machine` exercises get
/// suggestions; a cable station, a Smith machine or a treadmill is named by
/// the lifter.
enum MachineCatalog {
    struct Model: Decodable, Hashable, Sendable {
        let manufacturer: String
        let model: String
        /// The exercise families the machine trains.
        let families: [String]

        var displayName: String { MachineProfile.displayName(manufacturer: manufacturer, model: model) }
    }

    /// shortcut: a missing or unreadable file only drops the suggestions;
    /// `MachineProfileTests.machineCatalog` fails on it before it ships.
    static let models: [Model] = {
        guard let url = Bundle.main.url(forResource: "machine-models", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return [] }
        return (try? JSONDecoder().decode([Model].self, from: data)) ?? []
    }()

    /// The known models that train `family`, by name.
    static func models(forFamily family: String?) -> [Model] {
        guard let family else { return [] }
        return models.filter { $0.families.contains(family) }.sorted { $0.displayName < $1.displayName }
    }
}

enum SessionMachine {
    /// The machine the exercise was last done on, in `session` (the workout
    /// in progress) or else in its last finished workout: a new log of it
    /// starts there. Only a log with a finished working set counts, so a
    /// machine picked and then left unused is not the last one. Nil when that
    /// log named none, when the exercise has no such log, or when its
    /// equipment takes no machine.
    static func lastUsed(for exercise: Exercise?, during session: Session?, in context: ModelContext) -> MachineProfile? {
        guard let exercise, exercise.equipment.takesMachine else { return nil }
        let used = PreviousMatchingIntent.logs(of: exercise.id, context: context).compactMap { log in
            log.session.flatMap {
                ($0.completedAt != nil || $0.id == session?.id) && hasFinishedWorkingSets(log)
                    ? (log: log, startedAt: $0.startedAt) : nil
            }
        }
        return used.max { ($0.startedAt, $0.log.orderIndex) < ($1.startedAt, $1.log.orderIndex) }?.log.machine
    }

    /// What the machine picker offers for one exercise.
    struct Choices {
        /// The machines this exercise has been logged on, the most recent
        /// first, this workout's included.
        var usedForExercise: [MachineProfile] = []
        /// Known models for the exercise's family that no listed machine
        /// matches yet; none unless its equipment is `.machine`.
        var suggested: [MachineCatalog.Model] = []
        /// Other machines logged lately on the same kind of equipment, the
        /// most recent first, at most five.
        var recent: [MachineProfile] = []
    }

    static func choices(for exercise: Exercise?, in context: ModelContext) -> Choices {
        guard let exercise else { return Choices() }
        var descriptor = FetchDescriptor<SessionExercise>(predicate: #Predicate { $0.machine != nil })
        descriptor.relationshipKeyPathsForPrefetching = [\.session, \.machine, \.exercise]
        let named = ((try? context.fetch(descriptor)) ?? [])
            .compactMap { log in log.machine.map { (log: log, machine: $0, at: log.session?.startedAt ?? .distantPast) } }
            .sorted { $0.at > $1.at }

        func machines(where include: (SessionExercise) -> Bool, skipping skipped: Set<UUID>) -> [MachineProfile] {
            var seen = skipped
            return named.compactMap { include($0.log) && seen.insert($0.machine.id).inserted ? $0.machine : nil }
        }
        let used = machines(where: { $0.exercise?.id == exercise.id }, skipping: [])
        let recent = machines(
            where: { $0.exercise?.equipment == exercise.equipment }, skipping: Set(used.map(\.id))
        )
        let listed = used + recent.prefix(5)
        let known = exercise.equipment == .machine ? MachineCatalog.models(forFamily: exercise.familyName) : []
        let suggested = known.filter { model in
            !listed.contains { $0.matches(manufacturer: model.manufacturer, model: model.model) }
        }
        return Choices(usedForExercise: used, suggested: suggested, recent: Array(recent.prefix(5)))
    }

    /// The machine with these names, whatever their case and spacing, or a
    /// new one inserted into `context` and left for the caller to save. Nil
    /// when both names are empty.
    static func findOrCreate(manufacturer: String?, model: String?, in context: ModelContext) -> MachineProfile? {
        let manufacturer = MachineProfile.cleaned(manufacturer)
        let model = MachineProfile.cleaned(model)
        guard manufacturer != nil || model != nil else { return nil }
        let all = (try? context.fetch(FetchDescriptor<MachineProfile>())) ?? []
        if let existing = all.first(where: { $0.matches(manufacturer: manufacturer, model: model) }) {
            return existing
        }
        let machine = MachineProfile()
        context.insert(machine)
        machine.manufacturer = manufacturer
        machine.model = model
        return machine
    }

    /// True when the log already has a finished working set, so a machine
    /// change must say whether those sets move with it.
    static func hasFinishedWorkingSets(_ sessionExercise: SessionExercise) -> Bool {
        (sessionExercise.sets ?? []).contains { $0.isComplete && !$0.isWarmup }
    }

    /// Puts `sessionExercise` on the machine with these names (both nil
    /// for none) in this workout only, with the prescription that
    /// machine's history gives. A machine is created only here, so a pick
    /// the lifter abandons leaves nothing behind. With
    /// `splittingFinishedSets`, finished working sets stay on the old
    /// machine in a copy of the log, for a switch partway through; without
    /// it they move with the log, for a correction. Saves, or rolls back
    /// and returns false.
    @MainActor
    static func change(
        _ sessionExercise: SessionExercise,
        toManufacturer manufacturer: String?,
        model: String?,
        splittingFinishedSets: Bool,
        context: ModelContext
    ) -> Bool {
        guard let session = sessionExercise.session else { return false }
        let machine = findOrCreate(manufacturer: manufacturer, model: model, in: context)
        guard sessionExercise.machine?.id != machine?.id else { return true }
        if splittingFinishedSets {
            SwapExerciseSheet.preserveCompletedSets(of: sessionExercise, in: session, context: context)
        }
        sessionExercise.machine = machine
        return SwapExerciseSheet.represcribe(sessionExercise, in: session, context: context)
    }
}
