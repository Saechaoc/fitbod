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

    /// Called with the saved template right before the builder dismisses.
    /// Lets a host attach a newly created session (e.g. into a routine).
    public let onSaved: ((SessionTemplate) -> Void)?

    @State private var expandedExerciseIDs: Set<UUID> = []
    @State private var presentingDiscardConfirm = false
    @State private var initialSnapshot: String = ""
    @State private var pendingSupersetAssignment: RoutineExerciseDraft? = nil
    @State private var presentingSaveFirstAlert: Bool = false
    @State private var pendingWarmupSheet: RoutineExerciseDraft? = nil
    @State private var presentingLibraryPicker: Bool = false
    @State private var showingMoreMenu: Bool = false
    @State private var showingValidationError: Bool = false
    @State private var presentingArchiveConfirm: Bool = false
    @State private var archiveBlockedRoutines: [String] = []
    @State private var saveErrorMessage: String? = nil
    @FocusState private var nameFocused: Bool

    public init(
        draft: RoutineDraft,
        editing: SessionTemplate? = nil,
        onSaved: ((SessionTemplate) -> Void)? = nil
    ) {
        self.draft = draft
        self.editing = editing
        self.onSaved = onSaved
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
            VStack(spacing: 0) {
                // 1. Session name + chip row
                nameAndChipBlock

                // 2. Exercise list + add slot
                exerciseScrollView
            }
            .background(Color.bruPaper.ignoresSafeArea())
            .navigationBarHidden(true)
            // Bottom action bar pinned above the home indicator
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomActionBar(
                    onDiscard: handleDiscard,
                    onSave: handleSave,
                    isValid: draft.isValid,
                    saveLabel: "Save session ▸"
                )
            }
            .safeAreaInset(edge: .top) {
                VStack(spacing: 0) {
                    BRUHeaderBar(
                        left: HeaderAction("‹ Back") {
                            handleDiscard()
                        },
                        center: editing == nil ? "New session" : "Edit session",
                        // ••• only has actions for a saved session.
                        right: editing == nil ? nil : HeaderAction("•••") {
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
        // More menu (edit mode only) — Duplicate / Archive
        .confirmationDialog(
            "Session",
            isPresented: $showingMoreMenu,
            titleVisibility: .hidden
        ) {
            Button("Duplicate session") { duplicateSession() }
            Button("Archive session", role: .destructive) { requestArchive() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Archive this session?",
            isPresented: $presentingArchiveConfirm,
            titleVisibility: .visible
        ) {
            Button("Archive session", role: .destructive) { archiveSession() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It disappears from pickers. Workouts you already logged keep their history.")
        }
        .alert(
            "Session is in use",
            isPresented: Binding(
                get: { !archiveBlockedRoutines.isEmpty },
                set: { if !$0 { archiveBlockedRoutines = [] } }
            )
        ) {
            Button("OK", role: .cancel) { archiveBlockedRoutines = [] }
        } message: {
            Text("Remove it from \(archiveBlockedRoutines.joined(separator: ", ")) before archiving.")
        }
        .alert(
            "Couldn't save",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "")
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
            Text("Session name")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)

            // Session name — wraps instead of truncating long names
            TextField("Name this session", text: $draft.name, axis: .vertical)
                .font(BRUFont.condensedTitle)
                .foregroundStyle(Color.bruInk)
                .lineLimit(1...3)
                .submitLabel(.done)
                .focused($nameFocused)
                .onChange(of: draft.name) { _, newValue in
                    // A vertical TextField turns Return into "\n"; treat it as done.
                    if newValue.contains("\n") {
                        draft.name = newValue.replacingOccurrences(of: "\n", with: "")
                        nameFocused = false
                    }
                }
                .accessibilityLabel("Session name")

            // Validation errors — shown when Save was tapped with an invalid draft
            if showingValidationError {
                ForEach(validationMessages, id: \.self) { message in
                    Text("! \(message)")
                        .font(BRUFont.labelSmall)
                        .tracking(1.0)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruSignal)
                        .accessibilityLabel("Error: \(message)")
                }
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

            // Estimated duration — derived from sets and rest (SessionTemplateSummary)
            if !draft.exercises.isEmpty {
                BRUChip("~\(SessionTemplateSummary(draft: draft).estimatedMinutes) min")
            }

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

    /// What blocks saving, in display order. Empty when the draft is valid.
    private var validationMessages: [String] {
        var messages: [String] = []
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append("Name this session")
        }
        if draft.exercises.isEmpty {
            messages.append("Add at least one exercise")
        }
        return messages
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
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.save(into: routine, context: ctx)
        do {
            try ctx.save()
        } catch {
            saveErrorMessage = error.localizedDescription
            return
        }
        onSaved?(routine)
        dismiss()
    }

    // MARK: - More-menu actions (edit mode)

    private func duplicateSession() {
        guard let editing else { return }
        _ = RoutineDuplicator.duplicate(routine: editing, context: ctx)
        do {
            try ctx.save()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    /// Archiving a session that a routine still schedules would leave a hole
    /// in the rotation, so it is blocked until the session is removed there.
    private func requestArchive() {
        guard let editing else { return }
        let templateID = editing.id
        let slots = (try? ctx.fetch(FetchDescriptor<SplitSessionSlot>(
            predicate: #Predicate<SplitSessionSlot> { $0.sessionTemplate?.id == templateID }
        ))) ?? []
        let routineNames = Set(slots.compactMap { slot -> String? in
            guard let split = slot.split, !split.isArchived else { return nil }
            return split.name
        })
        if routineNames.isEmpty {
            presentingArchiveConfirm = true
        } else {
            archiveBlockedRoutines = routineNames.sorted()
        }
    }

    private func archiveSession() {
        guard let editing else { return }
        editing.isArchived = true
        do {
            try ctx.save()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
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
#Preview("RoutineBuilderView — New session") {
    RoutineBuilderView(draft: RoutineDraft(), editing: nil)
        .modelContainer(PreviewModelContainer.make())
}
#endif
