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
//  ## Plan 03-03 additions
//
//  - `pendingSupersetAssignment: RoutineExerciseDraft?` state holds the
//    long-pressed exercise's draft while the SupersetAssignmentSheet is
//    presented. The sheet writes the chosen `supersetGroupID` directly
//    to the draft (not the persisted RE row); the persisted write
//    happens at Save time via `RoutineDraft.save(into:)`.
//  - The `RoutineExerciseCard` long-press menu's `onAssignSuperset`
//    closure sets `pendingSupersetAssignment`; the sheet item-binding
//    presents the sheet. The sheet's `SupersetGroup` insertions are
//    persisted immediately (so the @Query in the sheet sees them
//    next time), but the per-exercise assignment lives on the draft.
//  - **Edit-mode gate**: the SupersetAssignmentSheet needs a persisted
//    `Routine` (the SupersetGroup.routineID weak ref must point at a
//    real Routine). In create mode (editing == nil) we present an alert
//    asking the user to save first. In edit mode (editing != nil) the
//    sheet presents immediately.
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
    @State private var pendingSupersetAssignment: RoutineExerciseDraft? = nil
    @State private var presentingSaveFirstAlert: Bool = false
    @State private var pendingWarmupSheet: RoutineExerciseDraft? = nil

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
                            ),
                            onAssignSuperset: { exDraft in
                                handleAssignSuperset(exDraft)
                            },
                            onRemoveFromSuperset: { exDraft in
                                exDraft.supersetGroupID = nil
                            },
                            onDuplicate: { exDraft in
                                duplicateExercise(exDraft)
                            },
                            onRemove: { exDraft in
                                removeExercise(exDraft)
                            },
                            onEditWarmup: { exDraft in
                                pendingWarmupSheet = exDraft
                            }
                        )
                        // Reclaim the full row width — active edit mode
                        // otherwise reserves a narrow center column for
                        // the row content, which crushed the
                        // prescription editor into ~40% width.
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
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
        .sheet(
            isPresented: Binding(
                get: { pendingSupersetAssignment != nil },
                set: { if !$0 { pendingSupersetAssignment = nil } }
            )
        ) {
            // The save-first gate above guarantees `editing != nil` when
            // this sheet is presented. The SupersetGroup.routineID weak
            // ref needs a persisted Routine to point at.
            if let editing, let exDraft = pendingSupersetAssignment {
                SupersetAssignmentSheet(routine: editing, exerciseDraft: exDraft)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { pendingWarmupSheet != nil },
                set: { if !$0 { pendingWarmupSheet = nil } }
            )
        ) {
            // Bind WarmupConfigSheet directly to the draft's warmupOverride.
            // The draft is @Observable so mutations flow back to the card's
            // PrescriptionEditorRow toggle automatically.
            if let exDraft = pendingWarmupSheet {
                @Bindable var bd = exDraft
                WarmupConfigSheet(config: $bd.warmupOverride)
                    .presentationDetents([.medium])
            }
        }
        .alert(
            "Save Routine First",
            isPresented: $presentingSaveFirstAlert
        ) {
            Button("OK", role: .cancel) {
                presentingSaveFirstAlert = false
            }
        } message: {
            Text("Save the routine before grouping exercises into a superset.")
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

    // MARK: - Long-press menu handlers (plan 03-03)

    /// "Move to Superset…" / "Make Superset" menu actions both route
    /// here. The sheet needs a persisted Routine to anchor the
    /// SupersetGroup.routineID weak ref against — in create mode we
    /// surface a "Save Routine First" alert per the plan's edge-case
    /// guidance ("gate visibility on `editing != nil`"). The simpler
    /// path of saving inline would create a partially-built routine in
    /// the store before the user has chosen to commit; the alert keeps
    /// the create-mode user flow predictable.
    private func handleAssignSuperset(_ exDraft: RoutineExerciseDraft) {
        if editing == nil {
            presentingSaveFirstAlert = true
            return
        }
        pendingSupersetAssignment = exDraft
    }

    /// "Duplicate Exercise" menu action — inserts a clone of the
    /// long-pressed draft at `index + 1`. In-builder duplication only
    /// (not persisted until Save). The clone copies every prescription
    /// field verbatim and gets a fresh in-memory identity; per-set
    /// overrides are NOT cloned at this layer (the user can re-add
    /// them after duplication if needed — the in-builder duplicate is
    /// a quick "give me another row like this" affordance, not the
    /// routine-level deep copy that `RoutineDuplicator` handles).
    private func duplicateExercise(_ exDraft: RoutineExerciseDraft) {
        guard let index = draft.exercises.firstIndex(where: { $0 === exDraft }) else {
            return
        }
        let clone = RoutineExerciseDraft()
        clone.exercise = exDraft.exercise
        clone.intent = exDraft.intent
        clone.targetSets = exDraft.targetSets
        clone.targetRepsLow = exDraft.targetRepsLow
        clone.targetRepsHigh = exDraft.targetRepsHigh
        clone.targetRPE = exDraft.targetRPE
        clone.prescribedRestSeconds = exDraft.prescribedRestSeconds
        clone.progressionKind = exDraft.progressionKind
        clone.tempo = exDraft.tempo
        clone.tracksTempo = exDraft.tracksTempo
        clone.tracksPartialReps = exDraft.tracksPartialReps
        // NOTE: supersetGroupID is intentionally NOT copied — the
        // duplicate starts as a standalone exercise. The user can
        // long-press it and assign a superset explicitly.
        clone.supersetGroupID = nil
        draft.exercises.insert(clone, at: index + 1)
        // Rewrite orderIndex on the affected suffix.
        for (i, ex) in draft.exercises.enumerated() {
            ex.orderIndex = i
        }
    }

    /// "Remove" menu action — removes the long-pressed draft from the
    /// in-memory exercise list and rewrites `orderIndex` on the
    /// remainder. Persistence happens at Save time via the three-way
    /// merge in `RoutineDraft.save(into:context:)`.
    private func removeExercise(_ exDraft: RoutineExerciseDraft) {
        draft.exercises.removeAll { $0 === exDraft }
        for (i, ex) in draft.exercises.enumerated() {
            ex.orderIndex = i
        }
    }
}
