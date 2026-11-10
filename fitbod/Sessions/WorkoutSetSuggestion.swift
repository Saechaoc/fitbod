import Foundation

/// An offer for a pending set. Entered values take precedence independently.
public struct WorkoutSetSuggestion: Equatable, Sendable {
    public let weight: Double?
    public let reps: Int?

    public init(weight: Double? = nil, reps: Int? = nil) {
        self.weight = weight
        self.reps = reps
    }

    func weight(for entry: SetEntry) -> Double {
        if entry.isComplete || entry.weight != 0 || entry.wasManualOverride { return entry.weight }
        return weight ?? 0
    }

    func reps(for entry: SetEntry) -> Int {
        if entry.isComplete || entry.reps != 0 { return entry.reps }
        return reps ?? 0
    }
}

/// Resolves the editable offers for one exercise without writing to the workout.
struct WorkoutSetSuggestions {
    private let exercise: SessionExercise
    private let prior: [SetEntry]
    private let highestPriorWeight: Double?
    private let prescribedWeight: Double?
    private let targetReps: ClosedRange<Int>?
    private let programmed: Bool
    private let blockProgrammed: Bool

    init(exercise: SessionExercise, prior: [SetEntry]) {
        self.exercise = exercise
        let equipment = exercise.exercise?.equipment
        let eligiblePrior = prior.filter { Self.isReference($0, equipment: equipment) }
        self.prior = eligiblePrior
        highestPriorWeight = eligiblePrior.map(\.weight).max()
        prescribedWeight = exercise.prescribedWeight.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        targetReps = exercise.targetRepsLow > 0 && exercise.targetRepsLow <= exercise.targetRepsHigh
            ? exercise.targetRepsLow...exercise.targetRepsHigh
            : nil
        let hasProgram = Self.hasProgram(exercise.session)
        programmed = hasProgram
        blockProgrammed = hasProgram && exercise.session?.block != nil
    }

    /// An empty workout can belong to the active block for volume accounting.
    /// It has an authored plan only when started from a template or slot.
    static func hasProgram(_ session: Session?) -> Bool {
        guard let session else { return false }
        return session.sourceRoutineID != nil || session.template != nil || session.slot != nil
    }

    func offers() -> [UUID: WorkoutSetSuggestion] {
        let equipment = exercise.exercise?.equipment
        let working = SessionSetActions.ordered(exercise).filter(Self.isWorking)
        var lastCompleted = precedingExerciseSet(equipment: equipment)
        var offers: [UUID: WorkoutSetSuggestion] = [:]

        for (index, entry) in working.enumerated() {
            if entry.isComplete {
                if Self.isReference(entry, equipment: equipment) { lastCompleted = entry }
                continue
            }
            let previous = prior.isEmpty ? nil : prior[min(index, prior.count - 1)]
            let fromCurrent = !blockProgrammed && lastCompleted != nil
            let reference = fromCurrent ? lastCompleted : previous ?? lastCompleted
            let startingWeight = initialWeight(previous: previous)
            let weight = blockProgrammed
                ? startingWeight ?? lastCompleted?.weight
                : lastCompleted?.weight ?? startingWeight
            let effectiveWeight = WorkoutSetSuggestion(weight: weight).weight(for: entry)
            let reps = repOffer(at: effectiveWeight, reference: reference, fromCurrent: fromCurrent)
            offers[entry.id] = WorkoutSetSuggestion(weight: weight, reps: reps)
        }
        return offers
    }

    private func initialWeight(previous: SetEntry?) -> Double? {
        guard let prescribedWeight else { return previous?.weight }
        if !programmed, let previous, let highestPriorWeight,
           Self.sameLoad(prescribedWeight, highestPriorWeight) {
            // With a held load and no authored plan, replay the matching set.
            return previous.weight
        }
        return prescribedWeight
    }

    private func repOffer(at weight: Double, reference: SetEntry?, fromCurrent: Bool) -> Int? {
        if fromCurrent { return reference?.reps }
        guard programmed, let targetReps else {
            if let reference, weight <= reference.weight + 0.001 { return reference.reps }
            // A real increase from the selected progression model starts the rep range over.
            if let prescribedWeight, Self.sameLoad(weight, prescribedWeight),
               let highestPriorWeight, weight > highestPriorWeight + 0.001 {
                return self.targetReps?.lowerBound
            }
            return nil
        }

        let kind = exercise.session?.progressionKind ?? .default
        if kind == .rpe || kind == .hybrid {
            // These strategies calculate load against the upper rep target.
            return targetReps.upperBound
        }
        guard let reference, weight <= reference.weight + 0.001 else {
            return targetReps.lowerBound
        }

        let repeated = min(max(reference.reps, targetReps.lowerBound), targetReps.upperBound)
        if !blockProgrammed, kind == .double, Self.sameLoad(weight, reference.weight),
           reference.reps >= targetReps.lowerBound, repeated < targetReps.upperBound,
           (reference.rpe ?? 0) < (exercise.targetRPE ?? 10) {
            return repeated + 1
        }
        return repeated
    }

    private func precedingExerciseSet(equipment: Equipment?) -> SetEntry? {
        guard let id = exercise.exercise?.id else { return nil }
        let earlier = (exercise.session?.exercises ?? [])
            .filter { $0.orderIndex < exercise.orderIndex && $0.exercise?.id == id }
            .sorted { $0.orderIndex > $1.orderIndex }
        for log in earlier {
            if let set = SessionSetActions.ordered(log).last(where: { Self.isReference($0, equipment: equipment) }) {
                return set
            }
        }
        return nil
    }

    private static func isWorking(_ entry: SetEntry) -> Bool {
        !entry.isWarmup && entry.setType == .working
    }

    private static func isReference(_ entry: SetEntry, equipment: Equipment?) -> Bool {
        entry.isComplete && isWorking(entry)
            && SessionSetActions.isValidSet(weight: entry.weight, reps: entry.reps, equipment: equipment)
    }

    private static func sameLoad(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= 0.001
    }
}
