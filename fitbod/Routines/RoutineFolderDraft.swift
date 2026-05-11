//
//  RoutineFolderDraft.swift
//  fitbod
//
//  Ephemeral mutable wrapper for the new-folder / rename-folder sheet.
//  Follows the Phase 1 `CustomExerciseDraft` pattern (FOUND-07): an
//  `@Observable` value-shaped form holder with a `var isValid: Bool`
//  computed gate that drives the "Save" toolbar button's `.disabled(...)`
//  state.
//
//  NOT a ViewModel. The Phase 2 anti-pattern list (plan 03-01 §
//  "Anti-Patterns to Avoid") forbids a parallel `RoutinesListViewModel`
//  mirroring `@Query<RoutineFolder>` — this draft only carries the
//  in-flight mutable name string, never persistent state. The view
//  consumes `@Query<RoutineFolder>` directly for read paths.
//
//  Trimming on isValid mirrors the CustomExerciseDraft convention so a
//  whitespace-only name ("   ") is rejected like an empty one.
//

import Foundation

@Observable
@MainActor
public final class RoutineFolderDraft {
    public var name: String = ""

    public init() {}

    /// True when `name` is non-empty after trimming leading/trailing
    /// whitespace. Drives the "Save" button enablement in
    /// `NewFolderSheet`.
    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
