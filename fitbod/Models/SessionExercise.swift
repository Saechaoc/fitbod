//
//  SessionExercise.swift
//  fitbod
//
//  Per-exercise logged data within a Session. The fields between
//  `intentRaw` and `progressionKindRaw` are *snapshots* of the parent
//  RoutineExercise — copied at session-start time, never re-read from the
//  template (PITFALLS #1).
//
//  `prescribedWeight: Double?` is populated by Phase 3's
//  ProgressionStrategy based on the user's history. It is the weight the
//  user is *prescribed* for the session, distinct from the weight they
//  actually log (which lives on SetEntry).
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
//  Indexed: `intentRaw` for the intent-split history charts (Phase 4).
//

import Foundation
import SwiftData

@Model
public final class SessionExercise {
    #Index<SessionExercise>([\.intentRaw])

    @Attribute(.unique) public var id: UUID = UUID()
    public var session: Session? = nil
    public var exercise: Exercise? = nil
    public var orderIndex: Int = 0

    public var intentRaw: String = "hypertrophy"
    public var targetSets: Int = 3
    public var targetRepsLow: Int = 8
    public var targetRepsHigh: Int = 12
    public var targetRPE: Double? = nil
    public var targetRIR: Int? = nil
    public var prescribedRestSeconds: Int = 120
    public var tempo: String? = nil
    public var progressionKindRaw: String = "double"
    public var prescribedWeight: Double? = nil
    public var pinnedNote: String? = nil

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.sessionExercise)
    public var sets: [SetEntry]? = []

    public init() {}
}

extension SessionExercise {
    public var intent: Intent { Intent(rawValue: intentRaw) ?? .hypertrophy }
    public var progressionKind: ProgressionKind {
        ProgressionKind(rawValue: progressionKindRaw) ?? .double
    }
}
