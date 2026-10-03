//
//  SplitDetailView.swift
//  fitbod
//
//  Phase 09-01 — SplitDetailView: ordered session slots, drag-reorder,
//  slot add/remove via picker, usage section, archive via deny seam,
//  live-edit banner when on active block.
//
//  Composition (top to bottom):
//    BRUHeaderBar (left: .back, center: "Routine", right: Edit / Done)
//    [conditional] LiveEditBanner — when any block referencing this split is active
//    ScrollView { LazyVStack:
//      Name section (editable "Routine name" field)
//      Sessions section (BRUSectionHead + SplitSlotRow rows; Edit mode moves / removes)
//      Used-in section (BRUSectionHead + block usage rows)
//      Archive section ("Archive routine")
//    }
//
//  Drag-reorder: hysteresis-gated row-local @GestureState pattern (copy-adapted
//  from NewBlockPhaseListSection / NewBlockPhaseEditorRow in BlockBuilderView.swift).
//  NOT List .onMove — List chrome violates BRU contract.
//
//  Reindex-on-write: positions become 0..<n contiguous after every add/remove/reorder.
//  Single ctx.save() per mutation (no multi-write windows).
//
//  Archive: routes through BlockLifecycleService.assertSplitDeletable → SplitDeletionGuard.
//  Deny alert title/body verbatim from UI-SPEC Copywriting Contract.
//
//  BRU contract: NO Capsule / NO RoundedRectangle / NO Image(systemName:) /
//    NO .font(.body/.headline/.title*)
//
//  Navigation: pushed via SplitDetailRoute; uses the parent tab's NavigationStack.
//  No child NavigationStack — one stack per tab rule.
//

import SwiftUI
import SwiftData

// MARK: - Reindex Helper

/// Renumbers `slots` so positions become exactly 0..<n contiguous in the given order.
/// Call after any add / remove / reorder before `ctx.save()`.
///
/// Accessible at `internal` so `SplitDetailViewTests` can call it directly.
internal func reindexSlots(_ slots: [SplitSessionSlot]) {
    for (index, slot) in slots.enumerated() {
        slot.position = index
    }
}

// MARK: - SplitDetailView

public struct SplitDetailView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Stored

    public let split: Split

    // MARK: - UI State

    @State private var showArchiveDenied: Bool = false
    @State private var showSaveError: Bool = false
    @State private var presentingSlotPicker: Bool = false

    // Drag-reorder state (parent-side, copy-adapted from NewBlockPhaseListSection)
    @State private var draggingSlotID: UUID? = nil
    @State private var dragTargetIndex: Int? = nil

    // Remove-slot confirmation
    @State private var slotPendingRemoval: SplitSessionSlot? = nil

    // Session detail push (tap a slot row)
    @State private var openedTemplate: SessionTemplate? = nil

    // Edit mode: shows move / remove controls on each session row
    @State private var isEditing = false

    // Editable routine name; committed on submit, empty input reverts
    @State private var nameText: String = ""
    @FocusState private var nameFocused: Bool

    // MARK: - Init

    public init(split: Split) {
        self.split = split
    }

    // MARK: - Computed

    private var orderedSlots: [SplitSessionSlot] {
        (split.slots ?? []).sorted { $0.position < $1.position }
    }

    /// The active block referencing this split, if any.
    /// Post-filter in Swift — multi-level optional chain is NOT expressible in #Predicate.
    private var liveActiveBlock: Block? {
        (split.blocks ?? []).first { $0.derivedStatus == .active }
    }

    /// Non-completed blocks referencing this split (for the "Used in" section).
    private var liveNonCompletedBlocks: [Block] {
        (split.blocks ?? []).filter { $0.derivedStatus != .completed }
    }

    /// Row pitch for drag-reorder gap calculation (row min-height + 0pt inter-row gap).
    private var slotPitch: CGFloat { 64 }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header — "Routine" title + Edit / Done right action
            BRUHeaderBar.slots(
                left: .back,
                center: "Routine",
                right: .action(isEditing ? "Done" : "Edit") { isEditing.toggle() }
            )

            // Live-edit banner — shown when split is on an active block
            if liveActiveBlock != nil {
                LiveEditBanner()
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    nameSection
                    sessionsSection
                    usedInSection
                    archiveSection
                }
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())   // fix-6: bruPaper per 60/30/10 doctrine
        .navigationBarHidden(true)
        // Archive denied alert
        .alert("Cannot Archive Routine", isPresented: $showArchiveDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This routine is linked to an active or upcoming block. End or complete that block first.")
        }
        // Save failure alert (reorder / remove / archive persistence errors)
        .alert("Couldn't Save", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Couldn't save. Try again.")
        }
        // Remove slot confirmation
        .confirmationDialog(
            "Remove Session?",
            isPresented: Binding(
                get: { slotPendingRemoval != nil },
                set: { if !$0 { slotPendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove Session", role: .destructive) {
                if let slot = slotPendingRemoval {
                    removeSlot(slot)
                }
                slotPendingRemoval = nil
            }
            Button("Cancel", role: .cancel) {
                slotPendingRemoval = nil
            }
        }
        // Slot picker sheet
        .sheet(isPresented: $presentingSlotPicker) {
            SlotPickerSheet(split: split, onDismiss: {
                presentingSlotPicker = false
            })
            .presentationDetents([.medium, .large])
        }
        .navigationDestination(item: $openedTemplate) { template in
            SessionTemplateDetailView(template: template)
        }
        .onAppear { nameText = split.name }
        // Sensory feedback when drag starts/ends
        .sensoryFeedback(trigger: draggingSlotID) { _, newValue in
            newValue != nil ? .impact(weight: .medium) : nil
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Routine name")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
            TextField("Name this routine", text: $nameText, axis: .vertical)
                .font(BRUFont.condensedTitle)
                .foregroundStyle(Color.bruInk)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit(commitName)
                .onChange(of: nameFocused) { _, focused in
                    if !focused { commitName() }
                }
                .accessibilityLabel("Routine name")
            Text("\(orderedSlots.count) \(orderedSlots.count == 1 ? "session" : "sessions") · rotates in order")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) { BRUDivider(.ink) }
    }

    /// Writes the trimmed name. An empty name is rejected and the field
    /// reverts, so a routine can never become unnamed.
    private func commitName() {
        // A vertical-axis TextField inserts "\n" on Return instead of submitting.
        let trimmed = nameText
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            nameText = split.name
            return
        }
        nameText = trimmed
        nameFocused = false
        guard trimmed != split.name else { return }
        split.name = trimmed
        do {
            try ctx.save()
        } catch {
            showSaveError = true
        }
    }

    // MARK: - Sessions Section

    @ViewBuilder
    private var sessionsSection: some View {
        BRUSectionHead(
            "Sessions",
            right: "+ ADD SESSION",
            rightAction: { presentingSlotPicker = true }
        )

        let slots = orderedSlots
        if slots.isEmpty {
            VStack(spacing: 12) {
                Text("No sessions yet")
                    .font(BRUFont.condensedHeading)
                    .foregroundStyle(Color.bruInk)
                Text("A routine is an ordered list of sessions, like Push, Pull, Legs. Add the first one.")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                BRUButton("+ Add session", kind: .signal) { presentingSlotPicker = true }
                    .frame(maxWidth: 260)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .padding(.horizontal, 16)
        }
        ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
            SplitSlotRow(
                slot: slot,
                rowIndex: index,
                rowCount: slots.count,
                isDragging: draggingSlotID == slot.id,
                reorderPitch: slotPitch,
                isEditing: isEditing,
                onOpen: { openedTemplate = slot.sessionTemplate },
                onReorderBegan: { beginReorder(slotID: slot.id) },
                onReorderTarget: { target in retargetReorder(to: target) },
                onReorderEnded: { commitReorder() },
                onRemove: { slotPendingRemoval = slot },
                onMoveUp: { moveSlot(slot, by: -1) },
                onMoveDown: { moveSlot(slot, by: 1) }
            )
            .offset(y: gapOffset(rowIndex: index, slotID: slot.id, slots: slots))
            .scaleEffect(draggingSlotID == slot.id ? 0.97 : 1)
            .zIndex(draggingSlotID == slot.id ? 1 : 0)
            .background(draggingSlotID == slot.id ? Color.bruBg2 : Color.clear)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86), value: dragTargetIndex)

            if index < slots.count - 1 {
                BRUDivider(.hair)
            }
        }

        BRUDivider(.ink)
    }

    // MARK: - Archive Section

    private var archiveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            BRUButton("Archive routine", kind: .ghost) { attemptArchive() }
            Text("Archived routines leave Program but keep their logged history.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
        }
        .padding(16)
    }

    // MARK: - Used In Section

    @ViewBuilder
    private var usedInSection: some View {
        BRUSectionHead("Used in")

        let liveBlocks = liveNonCompletedBlocks
        if liveBlocks.isEmpty {
            Text("Not linked to any active block.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ForEach(liveBlocks, id: \.id) { block in
                HStack {
                    Text(block.name)
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruInk)
                    Spacer()
                    // Status badge colors mirror ProgramView.statusChip:
                    //   ACTIVE  = bruSignal fill  (highest urgency)
                    //   READY   = bruSignal outline
                    //   others  = default ink chip
                    switch block.derivedStatus {
                    case .active:
                        BRUChip("ACTIVE", color: .bruSignal, fill: true)
                    case .ready:
                        BRUChip("READY", color: .bruSignal)
                    default:
                        BRUChip(block.derivedStatus.rawValue.uppercased())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 44)

                if block.id != liveBlocks.last?.id {
                    BRUDivider(.hair)
                }
            }
        }

        BRUDivider(.ink)
    }

    // MARK: - Archive

    private func attemptArchive() {
        // First gate: deny-rule (linked to active/upcoming block) — surfaces its own alert.
        do {
            try BlockLifecycleService.assertSplitDeletable(split)
        } catch {
            showArchiveDenied = true
            return
        }

        // Persist the archive flag. On save failure, revert the in-memory flag and do
        // NOT dismiss — otherwise the split would vanish from the list while the store
        // still holds it (reappears on next launch).
        split.isArchived = true
        do {
            try ctx.save()
            dismiss()
        } catch {
            split.isArchived = false
            showSaveError = true
        }
    }

    // MARK: - Drag Reorder

    private func beginReorder(slotID: UUID) {
        draggingSlotID = slotID
    }

    private func retargetReorder(to target: Int) {
        guard dragTargetIndex != target else { return }
        dragTargetIndex = target
    }

    private func commitReorder() {
        guard let draggingID = draggingSlotID,
              let target = dragTargetIndex else {
            draggingSlotID = nil
            dragTargetIndex = nil
            return
        }

        var slots = orderedSlots
        guard let fromIndex = slots.firstIndex(where: { $0.id == draggingID }) else {
            draggingSlotID = nil
            dragTargetIndex = nil
            return
        }

        let clampedTarget = min(max(target, 0), slots.count - 1)
        if fromIndex != clampedTarget {
            let slot = slots.remove(at: fromIndex)
            slots.insert(slot, at: clampedTarget)
            reindexSlots(slots)
            do {
                try ctx.save()
            } catch {
                showSaveError = true
            }
        }

        draggingSlotID = nil
        dragTargetIndex = nil
    }

    /// Gap-offset animation: rows below the dragging row shift to show the drop target.
    private func gapOffset(rowIndex: Int, slotID: UUID, slots: [SplitSessionSlot]) -> CGFloat {
        guard let draggingID = draggingSlotID,
              let draggingIndex = slots.firstIndex(where: { $0.id == draggingID }),
              let targetIndex = dragTargetIndex,
              slotID != draggingID else { return 0 }

        // Shift siblings to create gap at drop target
        if draggingIndex < targetIndex {
            // Dragging down: shift rows in [draggingIndex+1...targetIndex] up
            if rowIndex > draggingIndex && rowIndex <= targetIndex {
                return -slotPitch
            }
        } else if draggingIndex > targetIndex {
            // Dragging up: shift rows in [targetIndex...draggingIndex-1] down
            if rowIndex >= targetIndex && rowIndex < draggingIndex {
                return slotPitch
            }
        }
        return 0
    }

    // MARK: - Slot Remove

    private func removeSlot(_ slot: SplitSessionSlot) {
        // Remove the SplitSessionSlot only — NEVER the SessionTemplate (.deny rule)
        ctx.delete(slot)
        // Reindex remaining slots
        let remaining = (split.slots ?? [])
            .filter { $0.id != slot.id }
            .sorted { $0.position < $1.position }
        reindexSlots(remaining)
        do {
            try ctx.save()
        } catch {
            showSaveError = true
        }
    }

    // MARK: - VoiceOver Move Actions

    private func moveSlot(_ slot: SplitSessionSlot, by delta: Int) {
        var slots = orderedSlots
        guard let index = slots.firstIndex(where: { $0.id == slot.id }) else { return }
        let newIndex = min(max(index + delta, 0), slots.count - 1)
        guard newIndex != index else { return }
        let moved = slots.remove(at: index)
        slots.insert(moved, at: newIndex)
        reindexSlots(slots)
        do {
            try ctx.save()
        } catch {
            showSaveError = true
        }
    }
}

// MARK: - SplitSlotRow

fileprivate struct SplitSlotRow: View {

    let slot: SplitSessionSlot
    let rowIndex: Int
    let rowCount: Int
    let isDragging: Bool
    let reorderPitch: CGFloat
    let isEditing: Bool
    var onOpen: () -> Void
    var onReorderBegan: () -> Void
    var onReorderTarget: (Int) -> Void
    var onReorderEnded: () -> Void
    var onRemove: () -> Void
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Row-local drag translation — reset with spring on gesture end
    @GestureState(
        resetTransaction: Transaction(
            animation: .spring(response: 0.28, dampingFraction: 0.86)
        )
    )
    private var dragTranslation: CGFloat = 0

    @State private var liveTarget: Int? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Position number (1-based)
            Text(String(format: "%02d", slot.position + 1))
                .font(BRUFont.condensedLabel)
                .foregroundStyle(Color.bruMuted)
                .frame(width: 32, alignment: .leading)

            // Session template name + summary line
            VStack(alignment: .leading, spacing: 3) {
                Text(slot.sessionTemplate?.name ?? "—")
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruInk)
                    .fixedSize(horizontal: false, vertical: true)
                if let template = slot.sessionTemplate {
                    Text(SessionTemplateSummary(template: template).line)
                        .font(BRUFont.labelSmall)
                        .tracking(1.0)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruMuted)
                }
            }

            Spacer(minLength: 8)

            if isEditing {
                editControls
            } else {
                Text("›")
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruMuted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
        .offset(y: isDragging ? dragTranslation : 0)
        .onTapGesture { if !isEditing { onOpen() } }
        .gesture(reduceMotion || isEditing ? nil : reorderGesture)
        // VoiceOver: activate opens the session; reorder and remove are actions
        .accessibilityElement(children: isEditing ? .contain : .ignore)
        .accessibilityLabel("Session \(slot.position + 1): \(slot.sessionTemplate?.name ?? "—")")
        .accessibilityAddTraits(isEditing ? [] : .isButton)
        .accessibilityHint(isEditing ? "" : "Opens the session. Touch and hold, then drag to reorder.")
        .accessibilityAction { if !isEditing { onOpen() } }
        .accessibilityAction(named: "Move up") { onMoveUp() }
        .accessibilityAction(named: "Move down") { onMoveDown() }
        .accessibilityAction(named: "Remove") { onRemove() }
    }

    /// Edit-mode controls: move up, move down, remove. Visible alternative
    /// to the long-press drag (which Reduce Motion disables).
    private var editControls: some View {
        HStack(spacing: 4) {
            rowControl("▲", label: "Move up", enabled: rowIndex > 0, action: onMoveUp)
            rowControl("▼", label: "Move down", enabled: rowIndex < rowCount - 1, action: onMoveDown)
            Button(action: onRemove) {
                Text("Remove")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruSignal)
                    .frame(minWidth: 64, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(slot.sessionTemplate?.name ?? "session")")
        }
    }

    private func rowControl(_ glyph: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(BRUFont.labelLarge)
                .foregroundStyle(enabled ? Color.bruInk : Color.bruHair)
                .frame(width: 44, height: 44)
                .overlay(Rectangle().strokeBorder(enabled ? Color.bruInk : Color.bruHair, lineWidth: 1.5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    // MARK: - Hysteresis Reorder Gesture

    // Long-press gate + drag — copy-adapted from NewBlockPhaseEditorRow (BlockBuilderView.swift
    // lines 1511-1543). Hysteresis threshold 0.55 pitch so hovering at a boundary doesn't
    // flicker the sibling gap open/closed.
    private var reorderGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($dragTranslation) { value, state, _ in
                if case .second(true, let drag?) = value {
                    state = drag.translation.height
                }
            }
            .onChanged { value in
                switch value {
                case .first(true):
                    liveTarget = rowIndex
                    onReorderBegan()
                case .second(true, let drag?):
                    let raw = Double(rowIndex) + Double(drag.translation.height / reorderPitch)
                    let current = liveTarget ?? rowIndex
                    // Hysteresis: re-target only when >0.55 pitch beyond current slot center
                    if abs(raw - Double(current)) > 0.55 {
                        let next = min(max(Int(raw.rounded()), 0), rowCount - 1)
                        if next != current {
                            liveTarget = next
                            onReorderTarget(next)
                        }
                    }
                default:
                    break
                }
            }
            .onEnded { _ in
                liveTarget = nil
                onReorderEnded()
            }
    }
}

// MARK: - SlotPickerSheet

/// Picker sheet presented when user taps "+ ADD SESSION".
/// Lists all non-archived SessionTemplates + a "New session" option.
fileprivate struct SlotPickerSheet: View {

    let split: Split
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<SessionTemplate> { !$0.isArchived })
    private var availableTemplates: [SessionTemplate]

    @State private var presentingNewSession: Bool = false
    /// Set by the builder's onSaved; attached when the builder sheet closes.
    @State private var pendingNewTemplate: SessionTemplate? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BRUHeaderBar.slots(left: .cancel, center: "Add session", right: nil)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        // "New session" row
                        Button {
                            presentingNewSession = true
                        } label: {
                            HStack {
                                Text("+ New session")
                                    .font(BRUFont.displayMedium)
                                    .foregroundStyle(Color.bruSignal)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 56)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        BRUDivider(.ink)

                        if !availableTemplates.isEmpty {
                            BRUSectionHead("Existing sessions")
                        }

                        ForEach(availableTemplates, id: \.id) { template in
                            Button {
                                addSlot(for: template)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(template.name)
                                            .font(BRUFont.displayMedium)
                                            .foregroundStyle(Color.bruInk)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(SessionTemplateSummary(template: template).line)
                                            .font(BRUFont.labelSmall)
                                            .tracking(1.0)
                                            .textCase(.uppercase)
                                            .foregroundStyle(Color.bruMuted)
                                    }
                                    Spacer()
                                    Text("+ Add")
                                        .font(BRUFont.labelSmall)
                                        .tracking(1.2)
                                        .textCase(.uppercase)
                                        .foregroundStyle(Color.bruSignal)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(minHeight: 56)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            BRUDivider(.hair)
                        }
                    }
                }
            }
            .background(Color.bruPaper.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        // A session built here is attached as soon as its builder closes.
        .sheet(isPresented: $presentingNewSession, onDismiss: {
            if let template = pendingNewTemplate {
                pendingNewTemplate = nil
                addSlot(for: template)
            }
        }) {
            RoutineBuilderView(
                draft: RoutineDraft(),
                editing: nil,
                onSaved: { pendingNewTemplate = $0 }
            )
        }
    }

    private func addSlot(for template: SessionTemplate) {
        // Insert slot into context first — then assign relationships (project convention)
        let slot = SplitSessionSlot()
        ctx.insert(slot)
        slot.split = split
        slot.sessionTemplate = template
        // Sentinel position only — reindexSlots assigns the real, contiguous value below.
        // Reading split.slots?.count here is unreliable: SwiftData may already include the
        // just-inserted slot in the live relationship count (off-by-one) and the new slot's
        // position can collide with an existing slot's, making the sort order ambiguous.
        slot.position = 0

        // Reindex all slots (including the new one) for contiguity. Sort by existing
        // position, but pin the new slot to the end so it appends rather than landing
        // at an arbitrary index among equal positions.
        let newSlotID = slot.id
        let allSlots = (split.slots ?? []).sorted { a, b in
            if a.id == newSlotID { return false }   // new slot sorts last (append)
            if b.id == newSlotID { return true }
            return a.position < b.position
        }
        reindexSlots(allSlots)
        try? ctx.save()
        onDismiss()
        dismiss()
    }
}
