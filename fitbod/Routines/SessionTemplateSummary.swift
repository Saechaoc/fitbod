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

    /// Summary from (sets, rest seconds) pairs, one per exercise.
    public init(prescriptions: [(sets: Int, restSeconds: Int)]) {
        let sets = prescriptions.reduce(0) { $0 + max(0, $1.sets) }
        let seconds = prescriptions.reduce(0) { total, p in
            total + max(0, p.sets) * (max(0, p.restSeconds) + Self.workSecondsPerSet)
        }
        self.init(
            exerciseCount: prescriptions.count,
            workingSets: sets,
            estimatedMinutes: Int((Double(seconds) / 60).rounded())
        )
    }

    public init(template: SessionTemplate) {
        self.init(prescriptions: (template.exercises ?? []).map {
            (sets: $0.targetSets, restSeconds: $0.prescribedRestSeconds)
        })
    }

    @MainActor
    public init(draft: RoutineDraft) {
        self.init(prescriptions: draft.exercises.map {
            (sets: $0.targetSets, restSeconds: $0.prescribedRestSeconds)
        })
    }

    /// "5 exercises · 15 sets · ~52 min". Empty templates read "No exercises yet".
    public var line: String {
        guard exerciseCount > 0 else { return "No exercises yet" }
        let ex = BRUCountLabel.text(exerciseCount, "exercise")
        let sets = BRUCountLabel.text(workingSets, "set")
        return "\(ex) · \(sets) · ~\(estimatedMinutes) min"
    }
}

/// One-line prescription for an exercise row: "3 × 8–10 · @8 · 2:00 rest".
public func prescriptionLine(
    sets: Int,
    repsLow: Int,
    repsHigh: Int,
    rpe: Double?,
    restSeconds: Int
) -> String {
    let reps = repsLow == repsHigh ? "\(repsLow)" : "\(repsLow)–\(repsHigh)"
    var parts = ["\(sets) × \(reps)"]
    if let rpe {
        let text = rpe.rounded() == rpe ? String(Int(rpe)) : String(format: "%.1f", rpe)
        parts.append("@\(text)")
    }
    parts.append("\(restSeconds / 60):\(String(format: "%02d", restSeconds % 60)) rest")
    return parts.joined(separator: " · ")
}
