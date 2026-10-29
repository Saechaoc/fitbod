//
//  PRKind.swift
//  fitbod
//
//  Wave-2 plan 06-02 — runtime-only enums for PR detection (CONTEXT
//  D-10 / D-11 / D-16). Neither is persisted on a `@Model` type;
//  both are pure SwiftUI / value-type state consumed by PRDetector,
//  ExercisePRsView, and InSessionPRBanner.
//
//  PRKind canonical UI order (UI-SPEC § In-session PR banner copy):
//    weight → reps → volume → e1RM
//  String rawValues match the export schema column names for diff-
//  friendliness (e1rm lower-cased intentionally).
//
//  RepBucket buckets reps into the same three ranges used by the
//  e1RM formula partitioning (CONTEXT D-04):
//    strength      reps  1..6
//    hypertrophy   reps  7..10
//    highRep       reps 11..∞    (e1RM PR suppressed per PROG-02)
//

import Foundation

/// The four PR kinds tracked per `(exercise, intent, repBucket)` tuple.
public enum PRKind: String, CaseIterable, Sendable {
    case weight
    case reps
    case volume
    case e1RM = "e1rm"
}

extension PRKind {
    /// What VoiceOver says for this kind of record.
    public var spokenName: String {
        switch self {
        case .weight: return "weight"
        case .reps:   return "reps"
        case .volume: return "volume"
        case .e1RM:   return "estimated one-rep max"
        }
    }
}

/// Rep-range bucket used to partition the PR table so a 5RM weight
/// PR does not compete with an 8RM weight PR.
public enum RepBucket: String, CaseIterable, Sendable {
    case strength    = "1-6"
    case hypertrophy = "7-10"
    case highRep     = "11+"

    /// Map a rep count onto its bucket; returns nil for non-positive reps.
    public static func bucket(for reps: Int) -> RepBucket? {
        guard reps > 0 else { return nil }
        if reps <= 6 { return .strength }
        if reps <= 10 { return .hypertrophy }
        return .highRep
    }
}
