import Foundation
import SwiftData

/// A starting weight for a variant with no matching workout of its own
/// (RM-022): the top working set of the newest finished workout, at this
/// workout's intent, of another exercise in its family with the same
/// equipment, loading, tracking and unit. The exercise card reads it when it
/// shows and never stores it, so it is not a record, progression history or
/// Last time. A set logged from it is an ordinary set.
struct SiblingEstimate: Equatable {
    let weight: Double
    /// The sibling's name, such as "Bench Press (Barbell)".
    let siblingName: String

    /// "Estimated 110 lb from Bench Press (Barbell)".
    func label(unit: WeightUnit) -> String {
        "Estimated \(NumberText.weight(weight)) \(unit.rawValue) from \(siblingName)"
    }

    /// `find` in a context of its own, off the main actor: three siblings
    /// with four years of history each take about 70 ms to read.
    @concurrent
    static func find(
        exerciseID: UUID, intentRaw: String, excludingSessionID: UUID, in container: ModelContainer
    ) async -> SiblingEstimate? {
        find(
            exerciseID: exerciseID, intentRaw: intentRaw, excludingSessionID: excludingSessionID,
            context: ModelContext(container)
        )
    }

    /// The estimate for the exercise `exerciseID` in the workout
    /// `excludingSessionID` at `intentRaw`, or nil when the exercise needs
    /// none or no sibling has one. Equipment that takes a machine gets none,
    /// since loads compare only within one machine (RM-066).
    static func find(
        exerciseID: UUID, intentRaw: String, excludingSessionID: UUID, context: ModelContext
    ) -> SiblingEstimate? {
        var lookup = FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == exerciseID })
        lookup.fetchLimit = 1
        func lastWorkout(of id: UUID) -> (session: Session, sets: [SetEntry])? {
            PreviousMatchingIntent.lastWorkingSets(
                in: PreviousMatchingIntent.logs(of: id, context: context),
                intentRaw: intentRaw,
                excludingSessionID: excludingSessionID,
                counting: { $0.reps > 0 }
            )
        }
        guard let exercise = (try? context.fetch(lookup))?.first,
              exercise.tracking.progressesLoad, !exercise.equipment.takesMachine,
              let family = exercise.familyName, !family.isEmpty,
              // A finished workout of its own gives it loads of its own.
              lastWorkout(of: exerciseID) == nil
        else { return nil }

        let equipment = exercise.equipmentRaw
        let siblings = (try? context.fetch(FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.familyName == family && $0.equipmentRaw == equipment && $0.id != exerciseID }
        ))) ?? []
        return siblings
            .filter {
                // Weights relabel and never convert, so a sibling in another
                // unit says nothing about this one.
                $0.loadingRaw == exercise.loadingRaw && $0.tracking == exercise.tracking
                    && $0.unitOverrideRaw == exercise.unitOverrideRaw
            }
            .compactMap { sibling -> (startedAt: Date, estimate: SiblingEstimate)? in
                guard let last = lastWorkout(of: sibling.id),
                      let top = PreviousMatchingIntent.topWorkingSet(in: last), top.weight > 0
                else { return nil }
                return (last.session.startedAt, SiblingEstimate(weight: top.weight, siblingName: sibling.name))
            }
            // The newest workout wins. Two siblings in one workout: the lighter
            // top set, the safer start, then the name, so fetch order never decides.
            .max {
                ($0.startedAt, -$0.estimate.weight, $0.estimate.siblingName)
                    < ($1.startedAt, -$1.estimate.weight, $1.estimate.siblingName)
            }?
            .estimate
    }

    /// `log`'s lift has a working set done in its workout, in this log or
    /// another, so it has a load of its own and shows no estimate. A done
    /// drop, failure or rest-pause set does not count, since the offers
    /// never start from one.
    static func liftDone(in log: SessionExercise) -> Bool {
        let id = log.exercise?.id
        return (log.session?.exercises ?? []).contains { other in
            other.exercise?.id == id && (other.sets ?? []).contains { $0.isComplete && WorkoutSetSuggestions.isWorking($0) }
        }
    }
}
