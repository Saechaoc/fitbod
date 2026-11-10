// WorkoutEditDraft.swift
// fitbod
//
// The Edit workout screen's working copy of a finished workout: its start
// and its logged working sets by exercise. Nothing is written while the
// lifter edits; SAVE turns the draft into one WorkoutEdit for
// SessionEditService, and CANCEL drops it.

import Foundation

struct WorkoutEditDraft: Equatable {
    struct Row: Equatable, Identifiable {
        /// The set's id, or a new id for a set added here.
        let id: UUID
        var values: WorkoutEdit.Values
        /// The values as logged; nil for a set added here.
        let logged: WorkoutEdit.Values?
        /// The row edits a time, not reps. A logged set keeps the shape it
        /// was logged in; an added one takes what its exercise tracks now.
        let isTimed: Bool
        /// The row's weight is assistance, stored negative and shown positive.
        let isAssisted: Bool

        var isChanged: Bool { logged.map { $0 != values } ?? false }
    }

    struct Exercise: Equatable, Identifiable {
        let id: UUID
        let name: String
        /// Display metadata only: stored weights are never converted.
        let unitOverride: WeightUnit?
        /// What the exercise tracks now; nil when it is gone.
        let tracking: Tracking?
        /// What its timed rows edit beside their time.
        let timedValue: TimedValue?
        var rows: [Row]
        var deleted: Set<UUID> = []
    }

    let name: String
    let loggedStart: Date
    /// The workout's length, which a date change keeps.
    let duration: TimeInterval
    var startedAt: Date
    var exercises: [Exercise]

    /// Copies the finished workout's start and its completed working sets.
    @MainActor
    init(session: Session) {
        name = session.displayName
        loggedStart = session.startedAt
        startedAt = session.startedAt
        duration = (session.completedAt ?? session.startedAt).timeIntervalSince(session.startedAt)
        exercises = (session.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { exercise in
                let tracking = exercise.exercise?.tracking
                return Exercise(
                    id: exercise.id,
                    name: exercise.displayName,
                    unitOverride: exercise.exercise?.unitOverride,
                    tracking: tracking,
                    timedValue: exercise.exercise?.timedValue,
                    rows: SessionSetActions.ordered(exercise)
                        .filter(\.countsAsWork)
                        .map { set in
                            let values = WorkoutEdit.Values(set)
                            return Row(
                                id: set.id, values: values, logged: values, isTimed: set.isTimed,
                                isAssisted: Self.isAssisted(weight: set.weight, tracking: tracking)
                            )
                        }
                )
            }
    }

    /// The changes, as one edit for SessionEditService.
    var edit: WorkoutEdit {
        var edit = WorkoutEdit(startedAt: startedAt)
        for exercise in exercises {
            edit.deleted.formUnion(exercise.deleted)
            for row in exercise.rows {
                if row.logged == nil {
                    edit.added[exercise.id, default: []].append(row.values)
                } else if row.isChanged {
                    edit.changed[row.id] = row.values
                }
            }
        }
        return edit
    }

    var hasChanges: Bool {
        edit != WorkoutEdit(startedAt: loggedStart)
    }

    /// Appends a set copied from the exercise's last one, as the mock-up
    /// asks. It has the shape the exercise tracks now, which is the rule
    /// SessionEditService holds an added set to, so it copies the last set
    /// of that shape.
    mutating func addSet(to exerciseID: UUID) {
        guard let index = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let exercise = exercises[index]
        let timed = exercise.tracking?.isTimed ?? exercise.rows.last?.isTimed ?? false
        var values = exercise.rows.last { $0.isTimed == timed }?.values
            ?? WorkoutEdit.Values(weight: 0, reps: 0, rpe: nil)
        let assisted = !timed && Self.isAssisted(weight: values.weight, tracking: exercise.tracking)
        // The copy may be of a set logged before the exercise was retagged.
        if !timed { values.weight = Self.signed(values.weight, assisted: assisted) }
        exercises[index].rows.append(Row(
            id: UUID(), values: values, logged: nil, isTimed: timed, isAssisted: assisted
        ))
    }

    /// Whether a rep set's weight is assistance. The exercise's tracking
    /// decides; with none that speaks for rep sets (the exercise is gone or
    /// timed now) the stored sign does.
    static func isAssisted(weight: Double, tracking: Tracking?) -> Bool {
        guard let tracking, !tracking.isTimed else { return weight < 0 }
        return tracking == .assistedReps
    }

    /// A rep row's weight with the sign its column stands for: assistance
    /// is negative, a load positive, and zero stays plain zero.
    static func signed(_ weight: Double, assisted: Bool) -> Double {
        assisted && weight != 0 ? -abs(weight) : abs(weight)
    }

    mutating func deleteRow(_ rowID: UUID, from exerciseID: UUID) {
        guard let index = exercises.firstIndex(where: { $0.id == exerciseID }),
              let row = exercises[index].rows.first(where: { $0.id == rowID })
        else { return }
        exercises[index].rows.removeAll { $0.id == rowID }
        if row.logged != nil {
            exercises[index].deleted.insert(rowID)
        }
    }
}
