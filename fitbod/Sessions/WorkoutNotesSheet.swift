//
//  WorkoutNotesSheet.swift
//  fitbod
//
//  Wave-4 plan 04-03 — workout-level notes editor. Presented as a sheet
//  from the SessionLoggerView header's "Notes" chip (the `square.and.pencil`
//  button anchored in plan 04-01 as a TODO; this plan ships the real sheet).
//
//  ## UI-SPEC § Session logger verbatim copy
//
//      Workout-level notes sheet title:        "Workout Notes"
//      Workout-level notes placeholder:        "Notes for this session"
//      Workout-level notes "Done" toolbar:     "Done"
//
//  ## Binding semantics
//
//  Binds directly to the `@Bindable session: Session`'s `notes: String?`
//  field via a `Binding(get:set:)` that normalizes empty strings to `nil`
//  on write — keeps the persisted column free of blank entries so any
//  downstream "has notes?" predicate stays simple (`session.notes != nil`).
//
//  UI-SPEC anti-pattern explicitly avoided: there is NO "Save" button.
//  The toolbar carries only "Done" (top-bar trailing). The TextField writes
//  through to the model on every keystroke via the binding; the sheet's
//  dismissal is decoupled from persistence.
//

import SwiftUI

public struct WorkoutNotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable public var session: Session

    public init(session: Session) {
        self.session = session
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Notes for this session", text: Binding(         // UI-SPEC verbatim placeholder
                        get: { session.notes ?? "" },
                        set: { session.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(5...)
                }
            }
            .navigationTitle("Workout Notes")                                  // UI-SPEC verbatim
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }                               // UI-SPEC verbatim
                }
            }
        }
    }
}
