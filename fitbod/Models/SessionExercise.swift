//
//  SessionExercise.swift
//  fitbod
//
//  Per-exercise logged data within a Session. Fields here are *snapshots*
//  of the parent RoutineExercise — copied at session-start time, never
//  re-read from the template (PITFALLS #1).
//
//  `prescribedWeight: Double?` is populated by Phase 3's
//  ProgressionStrategy based on the user's history. It is the weight the
//  user is *prescribed* for the session, distinct from the weight they
//  actually log (which lives on SetEntry).
//
//  Session intent and progression kind live on `Session`, not here
//  (see Session.swift).
//
//  `exerciseNameSnapshot` freezes the exercise name at log time, so a
//  later rename or deletion in the library never rewrites history.
//
//  Cascade rules (CONTEXT.md Area 4):
//    - SessionExercise → SetEntry: cascade (sets are owned)
//    - Exercise → SessionExercise: **nullify** (LIB-05). The `exercise`
//      field is a plain optional relationship with no forward declaration
//      from Exercise; SwiftData's default rule for non-owning inverses is
//      nullify, so deleting a library entry sets `exercise = nil` on
//      historical session rows. This preserves the history while
//      surfacing "your library exercise was removed" via the nil read.
//      The cascade-test in 01-03 (`CascadeRuleTests/
//      exerciseToSessionExerciseNullifies`) proves the behavior.
//

import Foundation
import SwiftData

@Model
public final class SessionExercise {
    @Attribute(.unique) public var id: UUID = UUID()
    public var session: Session? = nil
    public var exercise: Exercise? = nil
    public var orderIndex: Int = 0

    public var targetSets: Int = 3
    public var targetRepsLow: Int = 8
    public var targetRepsHigh: Int = 12
    public var targetRPE: Double? = nil
    public var targetRIR: Int? = nil
    public var prescribedRestSeconds: Int = 120
    public var tempo: String? = nil
    public var tracksTempo: Bool = false
    public var tracksPartialReps: Bool = false
    public var prescribedWeight: Double? = nil
    public var pinnedNote: String? = nil

    /// Log-time snapshot of the exercise name. Written by
    /// `SessionFactory.start` and whenever an exercise is added or swapped
    /// mid-session, so renaming the catalog entry later never rewrites
    /// history. Defaulted so existing stores migrate without a stage;
    /// rows logged before this field existed read "" and fall back to
    /// the live name via `displayName`.
    public var exerciseNameSnapshot: String = ""

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.sessionExercise)
    public var sets: [SetEntry]? = []

    public init() {}
}

extension SessionExercise {
    /// The name to show for this logged exercise: the log-time snapshot
    /// when present, else the live catalog name (pre-snapshot rows), else "".
    public var displayName: String {
        if !exerciseNameSnapshot.isEmpty { return exerciseNameSnapshot }
        return exercise?.name ?? ""
    }
}
