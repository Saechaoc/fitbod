//
//  ExerciseHistorySummary.swift
//  fitbod
//
//  "Your history" for one exercise: every finished session that logged it
//  (all intents), newest first, with its top set — plus the best set and
//  estimated 1RM across that history. Powers the exercise detail screen's
//  previous-performance section.
//

import Foundation
import SwiftData

public struct ExerciseHistorySummary: Sendable {
    public struct Entry: Identifiable, Sendable {
        public let id: UUID
        public let date: Date
        public let routineName: String
        public let intentRaw: String
        public let setCount: Int
        public let top: PreviousPerformance.Line
    }

    public let entries: [Entry]
    public let best: PreviousPerformance.Line?
    public let bestEstimatedOneRepMax: Double?

    public var lastDate: Date? { entries.first?.date }
    public var isEmpty: Bool { entries.isEmpty }

    public static func load(exerciseID: UUID, context: ModelContext) -> ExerciseHistorySummary {
        let all = (try? context.fetch(FetchDescriptor<SessionExercise>())) ?? []
        var entries: [Entry] = []
        for se in all where se.exercise?.id == exerciseID {
            guard let session = se.session, session.completedAt != nil else { continue }
            let lines = WorkoutLogging.workingSets(of: se)
                .filter { $0.isComplete && $0.reps > 0 }
                .map { PreviousPerformance.Line(weight: $0.weight, reps: $0.reps, rpe: $0.rpe) }
            guard let top = lines.max(by: { a, b in
                if a.weight != b.weight { return a.weight < b.weight }
                return a.reps < b.reps
            }) else { continue }
            entries.append(Entry(
                id: se.id,
                date: session.startedAt,
                routineName: session.routineSnapshotName,
                intentRaw: se.intentRaw,
                setCount: lines.count,
                top: top
            ))
        }
        entries.sort { $0.date > $1.date }
        let best = entries.map(\.top).max { a, b in
            if a.weight != b.weight { return a.weight < b.weight }
            return a.reps < b.reps
        }
        let bestE1RM = entries
            .compactMap { OneRepMax.epley(weight: $0.top.weight, reps: $0.top.reps) }
            .max()
        return ExerciseHistorySummary(entries: entries, best: best, bestEstimatedOneRepMax: bestE1RM)
    }
}
