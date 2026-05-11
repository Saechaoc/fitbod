//
//  PerSetNoteSheet.swift
//  fitbod
//
//  Wave-4 plan 04-03 — per-set form-note editor. Presented as a sheet from
//  the SetRow's notes button (the `square.and.pencil` icon anchored before
//  the completion checkmark by plan 04-01 as a TODO; this plan ships the
//  real sheet plus the button wire on the SetRow).
//
//  ## UI-SPEC § Session logger verbatim copy
//
//      Per-set notes sheet title:              "Set {N} Note"
//      Per-set notes placeholder:              "e.g. right knee caved on rep 7"
//      Per-set notes "Done" toolbar:           "Done"
//
//  The "Set {N} Note" title uses `entry.orderIndex + 1` to render the set
//  number in user-facing 1-based form.
//
//  ## Binding semantics
//
//  Binds directly to the `@Bindable entry: SetEntry`'s `notes: String?`
//  field with the same empty-string → nil normalization as
//  `WorkoutNotesSheet`. Keeps "has notes?" predicates clean for any later
//  surface (e.g. an "all sets with form notes" history filter).
//

import SwiftUI

public struct PerSetNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable public var entry: SetEntry

    public init(entry: SetEntry) {
        self.entry = entry
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. right knee caved on rep 7", text: Binding( // UI-SPEC verbatim placeholder
                        get: { entry.notes ?? "" },
                        set: { entry.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...)
                }
            }
            .navigationTitle("Set \(entry.orderIndex + 1) Note")               // UI-SPEC verbatim format
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
