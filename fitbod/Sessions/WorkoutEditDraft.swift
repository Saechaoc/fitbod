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

        var isChanged: Bool { logged.map { $0 != values } ?? false }
    }

    struct Exercise: Equatable, Identifiable {
        let id: UUID
        let name: String
        /// Display metadata only: stored weights are never converted.
        let unitOverride: WeightUnit?
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
                Exercise(
                    id: exercise.id,
                    name: exercise.displayName,
                    unitOverride: exercise.exercise?.unitOverride,
                    rows: SessionSetActions.ordered(exercise)
                        .filter(\.countsAsWork)
                        .map { set in
                            let values = WorkoutEdit.Values(weight: set.weight, reps: set.reps, rpe: set.rpe)
                            return Row(id: set.id, values: values, logged: values)
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

    /// Appends a set copied from the exercise's last one, as the mock-up asks.
    mutating func addSet(to exerciseID: UUID) {
        guard let index = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let values = exercises[index].rows.last?.values ?? WorkoutEdit.Values(weight: 0, reps: 0, rpe: nil)
        exercises[index].rows.append(Row(id: UUID(), values: values, logged: nil))
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
