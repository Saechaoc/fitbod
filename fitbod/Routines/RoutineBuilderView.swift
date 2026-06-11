//
//  RoutineBuilderView.swift
//  fitbod
//
//  Phase 2.1 Plan 05 REWRITE — replaces Form/Section/.editMode with the
//  BRU brutalist composition matching bru-screens/routine-builder.jsx.
//
//  ## Composition (top to bottom)
//
//  NavigationStack {
//    ZStack(alignment: .bottom) {
//      VStack(spacing: 0) {
//        // 1. Routine name + header chip row + BRUDivider(.ink)
//        // 2. RoutineBuilderDayTabs + BRUDivider(.ink)
//        // 3. ScrollView with exercise cards + BRUDashedSlot
//        // 4. 24pt bruBg safe-area filler
//      }
//      BottomActionBar (floats at bottom)
//    }
//  }
//  .safeAreaInset(edge: .top) { BRUHeaderBar }
//  .navigationBarHidden(true)
//  .background(Color.bruPaper.ignoresSafeArea())
//
//  ## State shape (unchanged)
//  Single @Bindable RoutineDraft. Dirty-check via draft.snapshotHash().
//  Save via draft.save(into:context:). Discard via dismiss().
//
//  ## Phase 3.1 header pickers preserved
//  Intent chip → Menu of Intent cases. Progression chip → Menu of available
//  ProgressionKind cases (block-aware filtering). Both write to draft directly.
//
//  ## Threat mitigations (T-02.1-05-01/02/03)
//  .swipeActions on each RoutineExerciseCard (delete affordance).
//  .onMove on ForEach inside LazyVStack (drag-reorder without .editMode).
//  Intent/Progression chips wire to existing RoutineDraft bindings.
//
//  Verbatim copy: "New routine" / "Edit routine" / "Routine name" /
//    "•••" / "Discard" / "Save routine ▸" / "Discard changes?" /
//    "Your edits will not be saved." / "Keep editing"
//    — anchored in RoutineBuilderBRUCopyTests.
//
//  BRU contract: NO nav-bar title / NO editMode / NO accentColor /
//  NO Apple HIG semantic fonts / NO Form / NO Section
//

import SwiftUI
import SwiftData

// MARK: - Reachability helper (testable seam)

/// Returns true iff `template` is slotted into at least one `Split` whose
/// `blocks` contains a block with `derivedStatus == .active`.
///
/// Reachability is computed entirely in Swift — the multi-level optional chain
/// `SplitSessionSlot.split?.blocks` is NOT expressible in a `#Predicate`.
///
/// Steps:
///   1. Fetch all `SplitSessionSlot`s whose `sessionTemplate == template` (single-level
///      predicate — safe for `#Predicate`).
///   2. From those slots, collect their `split` references.
///   3. Return true iff any `split.blocks` contains a block with `.derivedStatus == .active`.
///
/// Exposed at `internal` so `RoutineBuilderLiveEditTests` can call it directly.
internal func isTemplateOnActiveBlock(
    _ template: SessionTemplate,
    context: ModelContext
) -> Bool {
    let templateID = template.id
    let descriptor = FetchDescriptor<SplitSessionSlot>(
        predicate: #Predicate<SplitSessionSlot> { $0.sessionTemplate?.id == templateID }
    )
    guard let slots = try? context.fetch(descriptor) else { return false }
    return slots.contains { slot in
        guard let split = slot.split else { return false }
        return (split.blocks ?? []).contains { $0.derivedStatus == .active }
    }
}

public struct RoutineBuilderView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Bindable public var draft: RoutineDraft

    /// nil = create mode; non-nil = edit mode (existing SessionTemplate).
    public let editing: SessionTemplate?

    @State private var expandedExerciseIDs: Set<UUID> = []
    @State private var presentingDiscardConfirm = false
    @State private var initialSnapshot: String = ""
    @State private var pendingSupersetAssignment: RoutineExerciseDraft? = nil
    @State private var presentingSaveFirstAlert: Bool = false
    @State private var pendingWarmupSheet: RoutineExerciseDraft? = nil
    @State private var presentingLibraryPicker: Bool = false
    @State private var showingMoreMenu: Bool = false
    @State private var showingValidationError: Bool = false

    // Day tabs — single-day routine builder for v1.
    // The tab strip is visual scaffolding; the ForEach always iterates draft.exercises.
    // Multi-day routing will wire in a future plan.
    @State private var dayTabID: UUID = UUID()

    public init(draft: RoutineDraft, editing: SessionTemplate? = nil) {
        self.draft = draft
        self.editing = editing
    }

    // MARK: - Reachability

    /// True iff this view is in edit mode AND the template being edited is
    /// reachable via slots → split → an active block.
    ///
    /// Create mode (editing == nil) always returns false.
    /// Uses the module-level `isTemplateOnActiveBlock(_:context:)` helper so
    /// the reachability logic can be unit-tested without instantiating the view.
    private var isOnActiveBlock: Bool {
        guard let template = editing else { return false }
        return isTemplateOnActiveBlock(template, context: ctx)
    }

    // MARK: Body

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // 1. Routine name + chip row
                    nameAndChipBlock

                    // 2. Day tabs strip
                    let singleDay = RoutineDay(id: dayTabID, label: "Day 1")
                    RoutineBuilderDayTabs(
                        days: [singleDay],
                        selectedDayID: Binding(
                            get: { dayTabID },
                            set: { dayTabID = $0 ?? dayTabID }
                        ),
                        onAddDay: { /* multi-day: future plan */ }
                    )

                    // 3. Exercise list + add slot
                    exerciseScrollView

                    // 4. 24pt bruBg filler above bottom bar
                    Rectangle()
                        .fill(Color.bruBg)
                        .frame(height: 24)
                }

                // Bottom action bar floats above the scroll content
                BottomActionBar(
                    onDiscard: handleDiscard,
                    onSave: handleSave,
                    isValid: draft.isValid
                )
            }
            .background(Color.bruPaper.ignoresSafeArea())
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                VStack(spacing: 0) {
                    BRUHeaderBar(
                        left: HeaderAction("‹ Back") {
                            handleDiscard()
                        },
                        center: editing == nil ? "New routine" : "Edit routine",
                        right: HeaderAction("•••") {
                            showingMoreMenu = true
                        }
                    )
                    // Live-edit banner — shown when editing a template on an active block.
                    // Non-blocking: no dismiss. Reactive: drops when block ends between edits.
                    if isOnActiveBlock {
                        LiveEditBanner()
                    }
                }
            }
        }
        // Discard confirmation dialog — verbatim copy per UI-SPEC
        .confirmationDialog(
            "Discard changes?",
            isPresented: $presentingDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Keep editing", role: .cancel) {
                presentingDiscardConfirm = false
            }
        } message: {
            Text("Your edits will not be saved.")
        }
        // Superset assignment sheet
        .sheet(
            isPresented: Binding(
                get: { pendingSupersetAssignment != nil },
                set: { if !$0 { pendingSupersetAssignment = nil } }
            )
        ) {
            if let editing, let exDraft = pendingSupersetAssignment {
                SupersetAssignmentSheet(routine: editing, exerciseDraft: exDraft)
            }
        }
        // Warmup config sheet
        .sheet(
            isPresented: Binding(
                get: { pendingWarmupSheet != nil },
                set: { if !$0 { pendingWarmupSheet = nil } }
            )
        ) {
            if let exDraft = pendingWarmupSheet {
                @Bindable var bd = exDraft
                WarmupConfigSheet(config: $bd.warmupOverride)
                    .presentationDetents([.medium])
            }
        }
        // Exercise library picker
        .sheet(isPresented: $presentingLibraryPicker) {
            NavigationStack {
                ExerciseLibraryView(onSelect: { exercise in
                    draft.append(exercise: exercise)
                    presentingLibraryPicker = false
                })
            }
        }
        // Save-routine-first gate for superset in create mode
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
        // More menu — Duplicate / Move… / Delete
        .confirmationDialog(
            "Routine",
            isPresented: $showingMoreMenu,
            titleVisibility: .hidden
        ) {
            Button("Duplicate") { /* future: duplicate routine */ }
            Button("Move…") { /* future: move to folder */ }
            Button("Delete", role: .destructive) { /* future: delete with confirm */ }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: draft.blockID) { _, newBlockID in
            draft.enforceBlockProgressionEligibility(hasBlock: newBlockID != nil)
        }
        .onAppear {
            draft.enforceBlockProgressionEligibility()
            initialSnapshot = draft.snapshotHash()
        }
    }

    // MARK: - Name + Chip Block

    private var nameAndChipBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Routine name — displayLarge editable TextField
            TextField("Routine name", text: $draft.name)
                .font(BRUFont.displayLarge)
                .foregroundStyle(Color.bruInk)
                .submitLabel(.done)

            // Validation error — shown when Save was tapped with invalid draft
            if showingValidationError && !draft.isValid {
                Text("Add a routine name and at least one exercise to save.")
                    .font(BRUFont.labelSmall)
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruSignal)
            }

            // Header chip row: intent · days/wk · ~min · linked block
            chipRow
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) {
            BRUDivider(.ink)
        }
    }

    private var chipRow: some View {
        HStack(spacing: 6) {
            // Intent chip — signal-fill when .strength
            Menu {
                intentMenuItems
            } label: {
                BRUChip(
                    intentLabel,
                    color: .bruSignal,
                    fill: draft.intent == .strength
                )
            }

            // Days per week chip (placeholder — draft doesn't model this yet)
            BRUChip("4 days / wk")

            // Estimated duration chip (placeholder)
            BRUChip("~52 min")

            // Linked block chip — signal outline when block is set
            if draft.blockID != nil {
                Menu {
                    progressionMenuItems
                } label: {
                    BRUChip("Linked → Block", color: .bruSignal, fill: false)
                }
            } else {
                // Progression chip when no block linked
                Menu {
                    progressionMenuItems
                } label: {
                    BRUChip(progressionLabel(draft.progressionKind))
                }
            }
        }
    }

    // MARK: - Intent menu

    private var intentLabel: String {
        switch draft.intent {
        case .strength:    return "Strength"
        case .hypertrophy: return "Hypertrophy"
        case .power:       return "Power"
        case .endurance:   return "Endurance"
        case .technique:   return "Technique"
        }
    }

    @ViewBuilder
    private var intentMenuItems: some View {
        Button("Strength")    { draft.intent = .strength }
        Button("Hypertrophy") { draft.intent = .hypertrophy }
        Button("Power")       { draft.intent = .power }
        Button("Endurance")   { draft.intent = .endurance }
        Button("Technique")   { draft.intent = .technique }
    }

    // MARK: - Progression menu

    private func progressionLabel(_ kind: ProgressionKind) -> String {
        switch kind {
        case .rpe:    return "RPE Autoregulation"
        case .double: return "Double Progression"
        case .block:  return "Block Periodized"
        case .hybrid: return "Hybrid"
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

    @ViewBuilder
    private var progressionMenuItems: some View {
        ForEach(availableProgressionKinds, id: \.rawValue) { kind in
            Button(progressionLabel(kind)) {
                guardedProgressionSelection.wrappedValue = kind
            }
        }
    }

    private var availableProgressionKinds: [ProgressionKind] {
        RoutineDraft.availableProgressionKinds(hasBlock: draft.blockID != nil)
    }

    // MARK: - Exercise Scroll View

    private var exerciseScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(draft.exercises.enumerated()), id: \.element.id) { i, exDraft in
                    RoutineExerciseCard(
                        draft: exDraft,
                        hasBlock: draft.blockID != nil,
                        index: i,
                        isExpanded: Binding(
                            get: { expandedExerciseIDs.contains(stableKey(for: exDraft)) },
                            set: { isOpen in
                                let key = stableKey(for: exDraft)
                                if isOpen { expandedExerciseIDs.insert(key) }
                                else { expandedExerciseIDs.remove(key) }
                            }
                        ),
                        onAssignSuperset: { ed in handleAssignSuperset(ed) },
                        onRemoveFromSuperset: { ed in ed.supersetGroupID = nil },
                        onDuplicate: { ed in duplicateExercise(ed) },
                        onRemove: { ed in removeExercise(ed) },
                        onEditWarmup: { ed in pendingWarmupSheet = ed }
                    )
                    // Swipe-to-delete (T-02.1-05-01 mitigation)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            removeExercise(exDraft)
                        } label: {
                            Text("Remove")
                        }
                    }

                    BRUDivider(.hair)
                }

                // BRUDashedSlot — "+ Add exercise ↘ FROM LIBRARY"
                BRUDashedSlot(
                    label: "Add exercise",
                    hint: "↘ FROM LIBRARY",
                    leadingGlyph: "+",
                    action: { presentingLibraryPicker = true }
                )
                .padding(12)
            }
            // Extra bottom padding so content isn't hidden under BottomActionBar
            .padding(.bottom, 68)
        }
    }

    // MARK: - Stable Key

    private func stableKey(for exDraft: RoutineExerciseDraft) -> UUID {
        if let id = exDraft.id { return id }
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

    // MARK: - Dirty check

    private var hasUnsavedChanges: Bool {
        draft.snapshotHash() != initialSnapshot
    }

    // MARK: - Actions

    private func handleDiscard() {
        if hasUnsavedChanges {
            presentingDiscardConfirm = true
        } else {
            dismiss()
        }
    }

    private func handleSave() {
        guard draft.isValid else {
            showingValidationError = true
            return
        }
        save()
    }

    private func save() {
        let routine: SessionTemplate
        if let editing {
            routine = editing
        } else {
            routine = SessionTemplate()
            ctx.insert(routine)
        }
        draft.save(into: routine, context: ctx)
        try? ctx.save()
        dismiss()
    }

    // MARK: - Long-press menu handlers

    private func handleAssignSuperset(_ exDraft: RoutineExerciseDraft) {
        if editing == nil {
            presentingSaveFirstAlert = true
            return
        }
        pendingSupersetAssignment = exDraft
    }

    private func duplicateExercise(_ exDraft: RoutineExerciseDraft) {
        guard let index = draft.exercises.firstIndex(where: { $0 === exDraft }) else { return }
        let clone = RoutineExerciseDraft()
        clone.exercise = exDraft.exercise
        clone.targetSets = exDraft.targetSets
        clone.targetRepsLow = exDraft.targetRepsLow
        clone.targetRepsHigh = exDraft.targetRepsHigh
        clone.targetRPE = exDraft.targetRPE
        clone.prescribedRestSeconds = exDraft.prescribedRestSeconds
        clone.tempo = exDraft.tempo
        clone.tracksTempo = exDraft.tracksTempo
        clone.tracksPartialReps = exDraft.tracksPartialReps
        clone.supersetGroupID = nil
        draft.exercises.insert(clone, at: index + 1)
        for (i, ex) in draft.exercises.enumerated() { ex.orderIndex = i }
    }

    private func removeExercise(_ exDraft: RoutineExerciseDraft) {
        draft.exercises.removeAll { $0 === exDraft }
        for (i, ex) in draft.exercises.enumerated() { ex.orderIndex = i }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("RoutineBuilderView — New routine") {
    let schema = Schema(SchemaV5.models)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    if let container = try? ModelContainer(
        for: schema,
        migrationPlan: FitbodSchemaMigrationPlan.self,
        configurations: config
    ) {
        let draft = RoutineDraft()
        return AnyView(
            RoutineBuilderView(draft: draft, editing: nil)
                .modelContainer(container)
        )
    } else {
        return AnyView(Text("Preview unavailable"))
    }
}
#endif
