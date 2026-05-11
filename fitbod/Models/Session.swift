//
//  Session.swift
//  fitbod
//
//  Instance — a logged workout. The "instance" half of the snapshot-and-
//  decouple pattern. Phase 1 ships the schema; Phase 2 ships
//  `SessionFactory.start(routine:date:...)` which populates a Session by
//  copying the Routine's RoutineExercise list into SessionExercise rows.
//
//  `sourceRoutineID: UUID?` is a *soft* reference to the source template
//  (not a SwiftData relationship) so deleting the template never deletes
//  the history. `routineSnapshotName: String` records the template name
//  at session-start time, surviving subsequent template renames.
//
//  Indexes per FOUND-04:
//    - startedAt: calendar / history queries
//    - sourceRoutineID: "all sessions from this routine"
//
//  Cascade: deleting a Session cascades into SessionExercise (and through
//  SessionExercise → SetEntry, giving us the documented Session →
//  SessionExercise → SetEntry cascade chain).
//

import Foundation
import SwiftData

@Model
public final class Session {
    #Index<Session>([\.startedAt], [\.sourceRoutineID])

    @Attribute(.unique) public var id: UUID = UUID()
    public var startedAt: Date = Date.now
    public var completedAt: Date? = nil
    public var routineSnapshotName: String = ""
    public var sourceRoutineID: UUID? = nil
    public var block: Block? = nil
    public var notes: String? = nil
    public var totalDurationSeconds: Int? = nil

    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    public var exercises: [SessionExercise]? = []

    public init() {}
}
