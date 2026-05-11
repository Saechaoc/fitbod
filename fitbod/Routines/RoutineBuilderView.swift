//
//  RoutineBuilderView.swift
//  fitbod
//
//  Wave-3 plan 03-02 — the user-facing keystone of ROUTINE-01: the
//  single-screen routine builder with inline exercise add, drag-handle
//  reorder, and per-exercise prescription editor. Pushed onto the
//  Routines tab's `NavigationStack` (from `RoutinesListView`) in both
//  create mode (`editing == nil`) and edit mode (`editing == routine`).
//
//  ## State shape (FOUND-06 / MV-VM-lite)
//
//  The view binds to a single `@Bindable RoutineDraft`. There is NO
//  parallel ViewModel; the draft IS the mutation surface. Persistence
//  happens only on Save tap via `draft.save(into:context:)` — every
//  in-between keystroke and stepper tap mutates the draft in memory
//  only, so the user can Cancel without leaving any side effects in
//  the SwiftData store.
//
//  ## Drag-handle reorder (RESEARCH §6 Pitfall 10)
//
//  `.environment(\.editMode, .constant(.active))` keeps the drag
//  handles always visible (UI-SPEC § Routine builder § Interaction
//  patterns). `.onMove(...)` reorders the draft's `exercises` array AND
//  rewrites every `RoutineExerciseDraft.orderIndex` from 0..<count so
//  the persisted SwiftData order matches the visual order after save.
//
//  ## Dirty-check / Cancel confirmation
//
//  The "Cancel" toolbar button presents the UI-SPEC § Routine builder
//  "Discard Changes?" `confirmationDialog` if the draft has been
//  modified since `onAppear`. Dirty is computed via a snapshot hash
//  (name + exercise count + sum of targetSets) — light enough to run
//  every body redraw without measurable cost at the expected scale
//  (≤20 exercises per routine).
//
//  ## Empty routine guard
//
//  An empty routine (no exercises) cannot be saved (`draft.isValid ==
//  false` disables the toolbar Save button). The Form body shows a
//  faint "Add an exercise to begin." placeholder when `exercises.isEmpty`
//  per UI-SPEC § Empty states.
//

import SwiftUI
import SwiftData

public struct RoutineBuilderView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Bindable public var draft: RoutineDraft

    /// nil = create mode; non-nil = edit mode (existing Routine).
    public let editing: Routine?

    @State private var expandedExerciseIDs: Set<UUID> = []
    @State private var presentingDiscardConfirm = false
    @State private var initialSnapshot: String = ""

    public init(draft: RoutineDraft, editing: Routine? = nil) {
        self.draft = draft
        self.editing = editing
    }

    public var body: some View {
        Form {
            // MARK: Name + folder
            Section {
                TextField("Routine name", text: $draft.name)
            }

            // MARK: Exercises
            Section("Exercises") {
                if draft.exercises.isEmpty {
                    Text("Add an exercise to begin.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(draft.exercises) { exDraft in
                        RoutineExerciseCard(
                            draft: exDraft,
                            isExpanded: Binding(
                                get: { expandedExerciseIDs.contains(stableKey(for: exDraft)) },
                                set: { isOpen in
                                    let key = stableKey(for: exDraft)
                                    if isOpen { expandedExerciseIDs.insert(key) }
                                    else { expandedExerciseIDs.remove(key) }
                                }
                            )
                        )
                    }
                    .onMove { source, destination in
                        draft.exercises.move(fromOffsets: source, toOffset: destination)
                        // RESEARCH §6 Pitfall 10 — rewrite orderIndex on
                        // every reorder so the save path persists the
                        // visual order verbatim.
                        for (i, ex) in draft.exercises.enumerated() {
                            ex.orderIndex = i
                        }
                    }
                    .onDelete { offsets in
                        draft.exercises.remove(atOffsets: offsets)
                        for (i, ex) in draft.exercises.enumerated() {
                            ex.orderIndex = i
                        }
                    }
                }
                InlineExerciseSearchRow { exercise in
                    draft.append(exercise: exercise)
                }
            }

            // MARK: Notes
            Section {
                TextField(
                    "Notes (optional)",
                    text: Binding(
                        get: { draft.notes ?? "" },
                        set: { draft.notes = $0.isEmpty ? nil : $0 }
                    ),
                    axis: .vertical
                )
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle(editing == nil ? "New Routine" : draft.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    if hasUnsavedChanges {
                        presentingDiscardConfirm = true
                    } else {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    save()
                }
                .disabled(!draft.isValid)
                .foregroundStyle(Color.accentColor)
            }
        }
        .confirmationDialog(
            "Discard Changes?",
            isPresented: $presentingDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {
                presentingDiscardConfirm = false
            }
        }
        .onAppear {
            initialSnapshot = snapshotHash()
        }
    }

    // MARK: - Stable key for the expansion set

    /// Each `RoutineExerciseDraft` has an optional `id: UUID?` — nil
    /// for freshly-appended exercises that haven't been saved yet.
    /// We need a stable key for the expansion `Set` so the expanded
    /// state survives unrelated body redraws. Fall back to
    /// `ObjectIdentifier`'s integer representation hashed into a UUID
    /// when the persistent id isn't available. Since the
    /// `RoutineExerciseDraft` is `@Observable` final class, its
    /// instance identity is stable for the lifetime of the draft.
    private func stableKey(for exDraft: RoutineExerciseDraft) -> UUID {
        if let id = exDraft.id { return id }
        // Hash ObjectIdentifier into a UUID-shaped key. The result is
        // stable across body redraws (the object stays in memory) but
        // is NOT the persisted id (which the save path back-fills).
        let oid = ObjectIdentifier(exDraft)
        let hash = UInt64(bitPattern: Int64(oid.hashValue))
        let upper = (hash >> 32) & 0xFFFFFFFF
        let lower = hash & 0xFFFFFFFF
        return UUID(uuid: (
            UInt8((upper >> 24) & 0xFF), UInt8((upper >> 16) & 0xFF),
            UInt8((upper >> 8) & 0xFF), UInt8(upper & 0xFF),
            UInt8((lower >> 24) & 0xFF), UInt8((lower >> 16) & 0xFF),
            UInt8((lower >> 8) & 0xFF), UInt8(lower & 0xFF),
            0, 0, 0, 0, 0, 0, 0, 0
        ))
    }

    // MARK: - Dirty-check

    private var hasUnsavedChanges: Bool {
        snapshotHash() != initialSnapshot
    }

    /// Cheap fingerprint for the dirty-check. Captures the load-bearing
    /// inputs that change in a normal builder session: name, exercise
    /// count, total targetSets sum, and the joined exercise ids.
    private func snapshotHash() -> String {
        let counts = draft.exercises.map { $0.targetSets }.reduce(0, +)
        let ids = draft.exercises.map { $0.id?.uuidString ?? "new" }.joined(separator: ",")
        return "\(draft.name)|\(draft.exercises.count)|\(counts)|\(ids)"
    }

    // MARK: - Save

    private func save() {
        let routine: Routine
        if let editing {
            routine = editing
        } else {
            routine = Routine()
            ctx.insert(routine)
        }
        draft.save(into: routine, context: ctx)
        try? ctx.save()
        dismiss()
    }
}
