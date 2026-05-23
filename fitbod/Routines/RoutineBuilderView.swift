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
//  Phase 3.1 update — `snapshotHash()` MOVED from this view onto
//  `RoutineDraft` (where it lives as `internal func snapshotHash() ->
//  String`). The relocation makes the dirty-check helper reachable
//  from the unit-test target via `@testable import fitbod`. The Phase
//  3.1 expansion of the hash inputs ALSO includes `intent.rawValue` +
//  `progressionKind.rawValue` so a header-picker change arms the
//  Cancel-discard prompt. The view's `hasUnsavedChanges` is now a
//  one-liner that compares `draft.snapshotHash()` against the captured
//  `initialSnapshot`.
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
//  ## Phase 3.1 plan 04 — header pickers (PIVOT-04 user surface)
//
//  The top `Form` Section gains TWO new `LabeledContent` picker rows
//  rendered BETWEEN the existing `TextField("Routine name", ...)` and
//  the existing `BlockPickerMenu`. Final first-Section row order:
//
//      TextField("Routine name") → Intent picker → Progression picker →
//      BlockPickerMenu
//
//  The two new rows are bound to `RoutineDraft.intent` and
//  `RoutineDraft.progressionKind` — both session-level fields the
//  Phase 3.1 PIVOT-04 promoted off `RoutineExerciseDraft`. The Intent
//  picker exposes the 5 `Intent` cases verbatim per UI-SPEC § Header
//  pickers; the Progression picker exposes all 4 `ProgressionKind`
//  cases per D-08 (CONTEXT.md). `RoutineDraft.save(into:context:)`
//  writes both fields onto the persisted `Routine` row.
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
            // MARK: Name + Intent + Progression + folder
            // Phase 3.1 PIVOT-04 — two NEW rows (intentHeaderRow +
            // progressionHeaderRow) insert BETWEEN the TextField and
            // BlockPickerMenu per UI-SPEC § Header pickers § Final
            // first-Section order. The BlockPickerMenu row stays in
            // this Section, unchanged.
            Section {
                TextField("Routine name", text: $draft.name)
                intentHeaderRow
                progressionHeaderRow
                BlockPickerMenu(blockID: $draft.blockID)
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
                            hasBlock: draft.blockID != nil,
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
        .onChange(of: draft.blockID) { _, newBlockID in
            draft.enforceBlockProgressionEligibility(hasBlock: newBlockID != nil)
        }
        .onAppear {
            draft.enforceBlockProgressionEligibility()
            // Phase 3.1 — `snapshotHash()` lives on `RoutineDraft` now
            // (relocated from this view so the helper is testable).
            initialSnapshot = draft.snapshotHash()
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
    //
    // The fingerprint helper itself lives on `RoutineDraft` as
    // `internal func snapshotHash() -> String` (relocated in Phase 3.1
    // plan 04 so the unit-test target can exercise it directly via
    // `@testable import fitbod`). The Phase 3.1 expansion of the hash
    // ALSO includes `intent.rawValue` + `progressionKind.rawValue`, so
    // changing an Intent or Progression header picker now flips the
    // hash and arms the Cancel-discard prompt — the intended Phase 3.1
    // dirty-check behavior change per the plan.

    private var hasUnsavedChanges: Bool {
        draft.snapshotHash() != initialSnapshot
    }

    // MARK: - Header pickers (Phase 3.1 PIVOT-04)
    //
    // Two `LabeledContent` rows rendered inside the top Form Section
    // BETWEEN the Routine Name TextField and BlockPickerMenu per
    // UI-SPEC § Header pickers § Final first-Section row order.
    // Picker copy is verbatim per UI-SPEC § Copywriting Contract:
    //
    //   Intent options:      Strength / Hypertrophy / Power / Endurance / Technique
    //   Progression options: RPE Autoregulation / Double Progression /
    //                        Block Periodized / Hybrid
    //
    // Both Progression options remain selectable per D-08 (CONTEXT.md);
    // ProgressionStrategyFactory.make(for:) routes .block →
    // BlockPeriodizedStrategy() and .hybrid → HybridStrategy() since
    // Phase 3. The picker selects which strategy SessionFactory invokes
    // once per session (D-14).

    private var intentHeaderRow: some View {
        LabeledContent {
            Picker("Intent", selection: $draft.intent) {
                Text("Strength").tag(Intent.strength)
                Text("Hypertrophy").tag(Intent.hypertrophy)
                Text("Power").tag(Intent.power)
                Text("Endurance").tag(Intent.endurance)
                Text("Technique").tag(Intent.technique)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .lineLimit(1)
            .truncationMode(.tail)
            .accessibilityLabel("Intent")
            .accessibilityHint("Sets the training goal for the whole session.")
        } label: {
            Text("Intent")
                .font(.body)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    /// Phase 4 (D-19 relocated): filter `.block` and `.hybrid` out of
    /// the picker when the routine has no block. The session-level
    /// strategies for those two cases need a real block to be
    /// meaningful (multipliers / phase context), so we hide them rather
    /// than letting the user pick a degenerate state.
    private var availableProgressionKinds: [ProgressionKind] {
        RoutineDraft.availableProgressionKinds(hasBlock: draft.blockID != nil)
    }

    private var progressionLabel: (ProgressionKind) -> String {
        { kind in
            switch kind {
            case .rpe: return "RPE Autoregulation"
            case .double: return "Double Progression"
            case .block: return "Block Periodized"
            case .hybrid: return "Hybrid"
            }
        }
    }

    private var guardedProgressionSelection: Binding<ProgressionKind> {
        Binding(
            get: { draft.progressionKind },
            set: { newValue in
                if draft.blockID != nil || !RoutineDraft.requiresBlock(newValue) {
                    draft.progressionKind = newValue
                }
            }
        )
    }

    private var progressionHeaderRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent {
                Picker("Progression", selection: guardedProgressionSelection) {
                    ForEach(availableProgressionKinds, id: \.rawValue) { kind in
                        Text(progressionLabel(kind)).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityLabel("Progression")
                .accessibilityHint("Sets the weight-progression strategy used for every exercise in this routine.")
            } label: {
                Text("Progression")
                    .font(.body)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            if draft.blockID == nil {
                Text("Add routine to a block to use these.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
        // Phase 3.1 PIVOT-04 — Intent + ProgressionKind are no longer
        // per-exercise fields on RoutineExerciseDraft (Plan 04 promoted
        // them to the parent RoutineDraft). The cloned draft implicitly
        // inherits the session-level Intent + Progression because both
        // the source and clone live under the same parent RoutineDraft.
        clone.targetSets = exDraft.targetSets
        clone.targetRepsLow = exDraft.targetRepsLow
        clone.targetRepsHigh = exDraft.targetRepsHigh
        clone.targetRPE = exDraft.targetRPE
        clone.prescribedRestSeconds = exDraft.prescribedRestSeconds
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
