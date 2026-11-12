//
//  StalledExercises.swift
//  fitbod
//
//  RM-019: the stalled exercises outside a workout. Every finished stream of
//  one exercise, intent and machine goes through the plateau check the
//  workout's exercise card runs (`PlateauDetector`), so the Stalled list on
//  Progress and the chart's stall mark show the stalls the STALLED badge
//  shows, each with the suggestion its chip shows. Advice only: nothing
//  here writes to the store or changes a routine.
//

import Foundation
import SwiftData

/// One stalled exercise: an exercise, intent and machine whose finished
/// workouts stall it, with the suggestion the workout's card would offer.
struct ExerciseStall: Identifiable {
    let exercise: Exercise
    let intent: Intent
    /// The machine its workouts were on (RM-066); nil for logs without one,
    /// which are a group of their own.
    let machine: MachineProfile?
    /// The workouts the stall check read, newest first: one per workout of
    /// the exercise's plateau window.
    let workouts: [PlateauWorkout]
    let action: SuggestedAction

    var id: String { "\(exercise.id)-\(intent.rawValue)-\(machine?.id.uuidString ?? "none")" }

    /// The row's sub-line: the machine when there is one, how many workouts
    /// are flat, and the newest workout's top set, as in "flat 4 workouts ·
    /// top 205 lb × 8 @ 8.5". `unit` labels the weight; it never converts it.
    func summary(unit: WeightUnit) -> String {
        var parts: [String] = []
        if let machine { parts.append(machine.displayName) }
        parts.append("flat \(BRUCountLabel.text(workouts.count, "workout"))")
        if let last = workouts.first {
            let set = SetText.result(
                weight: last.weight, reps: last.reps,
                durationSeconds: nil, distanceMeters: nil, level: nil, unit: unit
            )
            parts.append("top \(set)" + (last.rpe.map { " @ \(NumberText.weight($0))" } ?? ""))
        }
        return parts.joined(separator: " · ")
    }
}

enum StalledExercises {

    /// Every stalled exercise in the finished workouts of `logs`, the most
    /// recently trained first. Pass the logs a view's query already holds
    /// (every log on Progress, one exercise's on its chart); nil fetches
    /// every log.
    ///
    /// The card's plateau check runs on each stream's own logs, so the
    /// number of fetches does not grow with history; what no stream decides
    /// (this week's volume, the MAV targets, the active block) is read once
    /// per call. On the main actor: call it from a `.task(id:)` keyed on the
    /// finished workouts and `HistoryEdits.version`, never from a render.
    @MainActor
    static func find(
        in context: ModelContext,
        settings: UserSettings,
        logs: [SessionExercise]? = nil,
        now: Date = .now
    ) -> [ExerciseStall] {
        let logs = logs ?? (try? context.fetch(FetchDescriptor<SessionExercise>())) ?? []

        // Each stream's finished logs: one stream per exercise, intent and machine.
        struct Stream: Hashable {
            let exerciseID: UUID
            let intent: Intent
            let machineID: UUID?
        }
        var streams: [Stream: (exercise: Exercise, machine: MachineProfile?, logs: [SessionExercise])] = [:]
        for log in logs {
            guard let session = log.session, session.completedAt != nil,
                  let intent = Intent(rawValue: session.intentRaw),
                  let exercise = log.exercise else { continue }
            let stream = Stream(exerciseID: exercise.id, intent: intent, machineID: log.machine?.id)
            streams[stream, default: (exercise, log.machine, [])].logs.append(log)
        }

        let facts = PlateauDetector.SuggestionFacts(context: context, settings: settings, now: now)
        var stalls: [ExerciseStall] = []
        for (stream, owner) in streams {
            let read = PlateauDetector.evaluateWindow(
                exerciseID: stream.exerciseID, intent: stream.intent, in: context,
                settings: settings, now: now, machineID: stream.machineID,
                prefetched: .init(exercise: owner.exercise, logs: owner.logs)
            )
            guard let action = PlateauDetector.suggestedAction(
                for: read, exercise: owner.exercise, settings: settings, facts: facts
            ) else { continue }
            stalls.append(ExerciseStall(
                exercise: owner.exercise, intent: stream.intent, machine: owner.machine,
                workouts: read.workouts, action: action
            ))
        }
        return stalls.sorted { lhs, rhs in
            let (left, right) = (lhs.workouts.first?.startedAt ?? .distantPast, rhs.workouts.first?.startedAt ?? .distantPast)
            return left != right ? left > right : lhs.id < rhs.id
        }
    }

    /// How many exercises have stalled. One exercise stalled in two intents,
    /// or on two machines, is two rows but one exercise.
    static func exerciseCount(_ stalls: [ExerciseStall]) -> Int {
        Set(stalls.map(\.exercise.id)).count
    }

    /// The stalls by intent, in the order the chart's legend keys intents
    /// (hypertrophy, strength, power, endurance, technique), each intent's
    /// stalls in the order given.
    static func sections(_ stalls: [ExerciseStall]) -> [(intent: Intent, stalls: [ExerciseStall])] {
        Dictionary(grouping: stalls, by: \.intent)
            .map { (intent: $0.key, stalls: $0.value) }
            .sorted { ChartLineStyle(intent: $0.intent) < ChartLineStyle(intent: $1.intent) }
    }
}
