// SessionTemplateSummary.swift
// fitbod
//
// Derived numbers for a session template (UI: "Session"): exercise count,
// working-set count and an estimated duration. Shared by the session
// builder header, the session detail screen and Today's session list so the
// three never disagree.
//
// Duration model: every working set costs its prescribed rest plus a fixed
// work interval. Warm-up ramps are excluded (they are generated at start).
// Cardio is one bout with no sets or rest; it costs its planned time
// (RM-062).

import Foundation

public struct SessionTemplateSummary: Equatable, Sendable {
    public let exerciseCount: Int
    public let workingSets: Int
    public let estimatedMinutes: Int

    /// Seconds a working set takes under the bar, excluding rest.
    public static let workSecondsPerSet = 40

    public init(exerciseCount: Int, workingSets: Int, estimatedMinutes: Int) {
        self.exerciseCount = exerciseCount
        self.workingSets = workingSets
        self.estimatedMinutes = estimatedMinutes
    }

    /// Summary from (sets, rest seconds) pairs, one per exercise, and the
    /// planned time of the cardio among them, which counts no sets.
    public init(prescriptions: [(sets: Int, restSeconds: Int)], cardioSeconds: Int = 0) {
        let sets = prescriptions.reduce(0) { $0 + max(0, $1.sets) }
        let seconds = prescriptions.reduce(max(0, cardioSeconds)) { total, p in
            total + max(0, p.sets) * (max(0, p.restSeconds) + Self.workSecondsPerSet)
        }
        self.init(
            exerciseCount: prescriptions.count,
            workingSets: sets,
            estimatedMinutes: Int((Double(seconds) / 60).rounded())
        )
    }

    public init(template: SessionTemplate) {
        let exercises = template.exercises ?? []
        self.init(
            prescriptions: exercises.map {
                $0.exercise?.isCardio == true
                    ? (sets: 0, restSeconds: 0)
                    : (sets: $0.targetSets, restSeconds: $0.prescribedRestSeconds)
            },
            cardioSeconds: exercises.filter { $0.exercise?.isCardio == true }.reduce(0) { $0 + $1.plannedSeconds }
        )
    }

    @MainActor
    public init(draft: RoutineDraft) {
        self.init(
            prescriptions: draft.exercises.map {
                $0.exercise?.isCardio == true
                    ? (sets: 0, restSeconds: 0)
                    : (sets: $0.targetSets, restSeconds: $0.prescribedRestSeconds)
            },
            cardioSeconds: draft.exercises.filter { $0.exercise?.isCardio == true }.reduce(0) { $0 + $1.plannedSeconds }
        )
    }

    /// "5 exercises · 15 sets · ~52 min"; a session of cardio alone has no
    /// sets to count: "1 exercise · ~20 min". Empty templates read "No
    /// exercises yet".
    public var line: String {
        guard exerciseCount > 0 else { return "No exercises yet" }
        let sets = workingSets > 0 ? [BRUCountLabel.text(workingSets, "set")] : []
        return ([BRUCountLabel.text(exerciseCount, "exercise")] + sets + ["~\(estimatedMinutes) min"])
            .joined(separator: " · ")
    }
}

/// One-line prescription for an exercise row: "3 × 8–10 · @8 · 2:00 rest".
/// A timed exercise has no rep or effort target: "1 set · 2:00 rest".
public func prescriptionLine(
    sets: Int,
    repsLow: Int,
    repsHigh: Int,
    rpe: Double?,
    restSeconds: Int,
    isTimed: Bool = false
) -> String {
    let reps = repsLow == repsHigh ? "\(repsLow)" : "\(repsLow)–\(repsHigh)"
    var parts = [isTimed ? BRUCountLabel.text(sets, "set") : "\(sets) × \(reps)"]
    if let rpe, !isTimed {
        let text = rpe.rounded() == rpe ? String(Int(rpe)) : String(format: "%.1f", rpe)
        parts.append("@\(text)")
    }
    parts.append("\(restSeconds / 60):\(String(format: "%02d", restSeconds % 60)) rest")
    return parts.joined(separator: " · ")
}
