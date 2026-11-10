import Foundation

/// An offer for a pending set. Entered values take precedence independently.
public struct WorkoutSetSuggestion: Equatable, Sendable {
    public let weight: Double?
    public let reps: Int?
    public let durationSeconds: Int?
    public let distanceMeters: Double?
    public let level: Double?

    public init(
        weight: Double? = nil, reps: Int? = nil,
        durationSeconds: Int? = nil, distanceMeters: Double? = nil, level: Double? = nil
    ) {
        self.weight = weight
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.level = level
    }

    func durationSeconds(for entry: SetEntry) -> Int? {
        entry.durationSeconds ?? (entry.isComplete ? nil : durationSeconds)
    }

    func distanceMeters(for entry: SetEntry) -> Double? {
        entry.distanceMeters ?? (entry.isComplete ? nil : distanceMeters)
    }

    func level(for entry: SetEntry) -> Double? {
        entry.level ?? (entry.isComplete ? nil : level)
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
    private let tracking: Tracking?

    init(exercise: SessionExercise, prior: [SetEntry]) {
        self.exercise = exercise
        let tracking = exercise.exercise?.tracking
        self.tracking = tracking
        let eligiblePrior = prior.filter { Self.isReference($0, tracking: tracking) }
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
        let working = SessionSetActions.ordered(exercise).filter(Self.isWorking)
        var lastCompleted = precedingExerciseSet()
        var offers: [UUID: WorkoutSetSuggestion] = [:]

        for (index, entry) in working.enumerated() {
            if entry.isComplete {
                if Self.isReference(entry, tracking: tracking) { lastCompleted = entry }
                continue
            }
            let previous = prior.isEmpty ? nil : prior[min(index, prior.count - 1)]
            if tracking?.isTimed == true {
                // No progression: repeat the set just done, or the same set last time.
                // Only the value its row shows comes along with the time.
                if let reference = lastCompleted ?? previous {
                    let value = exercise.exercise?.timedValue
                    offers[entry.id] = WorkoutSetSuggestion(
                        weight: value == .weight && reference.weight > 0 ? reference.weight : nil,
                        durationSeconds: reference.durationSeconds,
                        distanceMeters: value == .distance ? reference.distanceMeters : nil,
                        level: value == .level ? reference.level : nil
                    )
                }
                continue
            }
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

    private func precedingExerciseSet() -> SetEntry? {
        guard let id = exercise.exercise?.id else { return nil }
        let earlier = (exercise.session?.exercises ?? [])
            .filter { $0.orderIndex < exercise.orderIndex && $0.exercise?.id == id }
            .sorted { $0.orderIndex > $1.orderIndex }
        for log in earlier {
            if let set = SessionSetActions.ordered(log).last(where: { Self.isReference($0, tracking: tracking) }) {
                return set
            }
        }
        return nil
    }

    private static func isWorking(_ entry: SetEntry) -> Bool {
        !entry.isWarmup && entry.setType == .working
    }

    private static func isReference(_ entry: SetEntry, tracking: Tracking?) -> Bool {
        entry.isComplete && isWorking(entry)
            && SessionSetActions.isValidSet(
                weight: entry.weight, reps: entry.reps,
                durationSeconds: entry.durationSeconds, tracking: tracking
            )
    }

    private static func sameLoad(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= 0.001
    }
}
