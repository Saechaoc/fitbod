//
//  SplitDetailView.swift
//  fitbod
//
//  Phase 09-01 — SplitDetailView: ordered session slots, drag-reorder,
//  slot add/remove via picker, usage section, archive via deny seam,
//  live-edit banner when on active block.
//
//  Composition (top to bottom):
//    BRUHeaderBar (left: .back, center: "Routine · {name}", right: .action("ARCHIVE"))
//    [conditional] LiveEditBanner — when any block referencing this split is active
//    ScrollView { LazyVStack:
//      Sessions section (BRUSectionHead + SplitSlotRow rows + drag-reorder)
//      Used-in section (BRUSectionHead + block usage rows)
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
    private var slotPitch: CGFloat { 44 }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header — "Routine · {name}" + ARCHIVE right action
            BRUHeaderBar.slots(
                left: .back,
                center: "Routine · \(split.name)",
                right: .action("ARCHIVE") { attemptArchive() }
            )

            // Live-edit banner — shown when split is on an active block
            if liveActiveBlock != nil {
                LiveEditBanner()
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    sessionsSection
                    usedInSection
                }
            }
        }
        .background(Color.bruBg.ignoresSafeArea())
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
        // Sensory feedback when drag starts/ends
        .sensoryFeedback(trigger: draggingSlotID) { _, newValue in
            newValue != nil ? .impact(weight: .medium) : nil
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
        ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
            SplitSlotRow(
                slot: slot,
                rowIndex: index,
                rowCount: slots.count,
                isDragging: draggingSlotID == slot.id,
                reorderPitch: slotPitch,
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
            // Position number (1-based, labelSmall UPPERCASE)
            Text("\(slot.position + 1)")
                .font(BRUFont.labelSmall)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Color.bruMuted)
                .frame(width: 32, alignment: .leading)

            // Session template name
            Text(slot.sessionTemplate?.name ?? "—")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)

            Spacer()

            // Drag handle — braille dots glyph (not SF Symbol per BRU contract)
            Text("⠿")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruMuted)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .offset(y: isDragging ? dragTranslation : 0)
        .gesture(reduceMotion ? nil : reorderGesture)
        // VoiceOver accessibility actions for reorder
        .accessibilityLabel("Session \(slot.position + 1): \(slot.sessionTemplate?.name ?? "—")")
        .accessibilityHint("Double-tap to remove. Use actions to reorder.")
        .accessibilityAction(named: "Move up") { onMoveUp() }
        .accessibilityAction(named: "Move down") { onMoveDown() }
        // Swipe-to-remove
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onRemove()
            } label: {
                Text("Remove")
            }
        }
        // Informational text when reduce motion is active
        .overlay(alignment: .bottom) {
            if reduceMotion && isDragging {
                Text("Reorder unavailable with Reduce Motion enabled")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BRUSectionHead("Add Session")

                ScrollView {
                    LazyVStack(spacing: 0) {
                        // "New session" row
                        Button {
                            presentingNewSession = true
                        } label: {
                            HStack {
                                Text("+ New session")
                                    .font(BRUFont.bodyEmphasis)
                                    .foregroundStyle(Color.bruSignal)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        BRUDivider(.hair)

                        ForEach(availableTemplates, id: \.id) { template in
                            Button {
                                addSlot(for: template)
                            } label: {
                                HStack {
                                    Text(template.name)
                                        .font(BRUFont.bodyEmphasis)
                                        .foregroundStyle(Color.bruInk)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .frame(minHeight: 44)
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
        // v1 UX debt: after RoutineBuilderView dismiss, re-open picker so user explicitly
        // selects the new session — 2-tap create+attach flow accepted for v1.
        .sheet(isPresented: $presentingNewSession) {
            RoutineBuilderView(draft: RoutineDraft(), editing: nil)
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
