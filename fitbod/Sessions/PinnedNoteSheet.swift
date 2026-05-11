//
//  PinnedNoteSheet.swift
//  fitbod
//
//  Wave-4 plan 04-03 — per-exercise pinned-note editor. Presented as a
//  sheet from the SessionExerciseCard's long-press menu "Edit Pinned Note"
//  entry (anchored as a TODO in plan 04-02; this plan ships the real
//  sheet) AND from tapping the inline `PinnedNoteCapsule` when a pinned
//  note is already populated.
//
//  ## UI-SPEC § Session logger verbatim copy
//
//      Pinned-note tap action navigation title:    "Pinned Note"
//      Pinned-note sheet "Save" / "Cancel" toolbar:    "Save" / "Cancel"
//
//  ## Binding semantics
//
//  Binds directly to the `@Bindable sessionExercise: SessionExercise`'s
//  `pinnedNote: String?` field with the same empty-string → nil
//  normalization as the other two notes sheets — this allows the inline
//  `PinnedNoteCapsule` render predicate (`if let note = se.pinnedNote,
//  !note.isEmpty`) to be the simple non-nil check.
//
//  Both "Save" and "Cancel" toolbar buttons simply dismiss the sheet —
//  the TextField writes through on every keystroke via the binding, so
//  "Save" is a UX affordance rather than a persistence action. This
//  matches the UI-SPEC's `WorkoutNotesSheet` pattern (Done-only) extended
//  with an explicit Cancel because the pinned note is a longer-lived
//  surface (it persists across sessions via the snapshot field on
//  SessionExercise, so users want a clear "I changed my mind" exit).
//

import SwiftUI

public struct PinnedNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable public var sessionExercise: SessionExercise

    public init(sessionExercise: SessionExercise) {
        self.sessionExercise = sessionExercise
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Pinned note", text: Binding(
                        get: { sessionExercise.pinnedNote ?? "" },
                        set: { sessionExercise.pinnedNote = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...)
                }
            }
            .navigationTitle("Pinned Note")                                    // UI-SPEC verbatim
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { dismiss() }
                }
            }
        }
    }
}
