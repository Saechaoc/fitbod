//
//  RoutineExerciseCard.swift
//  fitbod
//
//  Phase 2.1 Plan 05 REWRITE — replaces SF Symbol chevron/flame glyphs,
//  Apple HIG fonts, accentColor rail with the BRU brutalist card layout.
//
//  Layout (collapsed):
//    HStack:
//      leading: index zero-padded "01" SpaceGrotesk-Bold 26pt, at its own
//        width (a 28pt column cut it to "•••")
//      middle VStack:
//        name: JetBrainsMono-Bold 14pt (BRUFont.bodyEmphasis)
//        sub-line: "{equipment} · {sets}×{reps} · {m:ss}" labelSmall UPPERCASE bruMuted
//      trailing: MOVE chip opening the Move up / Move down menu (NOT an SF
//        Symbol, and not the ⋮⋮ glyph, which looked like a drag handle)
//    At accessibility sizes the three stack, so the name keeps the width.
//
//  The row does not merge its children for accessibility: the number, the
//  name, the sub-line and MOVE each keep their own unique identifier. The
//  name stays a static text, and its hint says a double tap, which reaches
//  the row's tap gesture, opens or closes the editor.
//
//  When expanded: PrescriptionEditorRow mounted inline.
//  When supersetGroupID != nil: wrapped in BRUSupersetBracket.
//  Leading index shows "SS" in bruSignal when in a superset.
//
//  Long-press contextMenu preserved from Phase 3, on the title row only.
//  All @Bindable bindings, the reorder menu and the warmup-config-sheet
//  trigger are preserved from Phase 3.1.
//
//  BRU contract: NO accentColor / NO Image(systemName:) / NO Capsule /
//  NO RoundedRectangle / NO Apple HIG semantic fonts
//

import SwiftUI

public struct RoutineExerciseCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable public var draft: RoutineExerciseDraft
    public let hasBlock: Bool
    public let index: Int
    @Binding public var isExpanded: Bool

    public let onAssignSuperset: (RoutineExerciseDraft) -> Void
    public let onRemoveFromSuperset: (RoutineExerciseDraft) -> Void
    public let onDuplicate: (RoutineExerciseDraft) -> Void
    public let onRemove: (RoutineExerciseDraft) -> Void
    public let onEditWarmup: (RoutineExerciseDraft) -> Void
    public let onMoveUp: (() -> Void)?
    public let onMoveDown: (() -> Void)?

    public init(
        draft: RoutineExerciseDraft,
        hasBlock: Bool = false,
        index: Int = 0,
        isExpanded: Binding<Bool>,
        onAssignSuperset: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onRemoveFromSuperset: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onDuplicate: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onRemove: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onEditWarmup: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onMoveUp: (() -> Void)? = nil,
        onMoveDown: (() -> Void)? = nil
    ) {
        self.draft = draft
        self.hasBlock = hasBlock
        self.index = index
        self._isExpanded = isExpanded
        self.onAssignSuperset = onAssignSuperset
        self.onRemoveFromSuperset = onRemoveFromSuperset
        self.onDuplicate = onDuplicate
        self.onRemove = onRemove
        self.onEditWarmup = onEditWarmup
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
    }

    // MARK: Body

    public var body: some View {
        if draft.supersetGroupID != nil {
            BRUSupersetBracket {
                cardBody
            }
        } else {
            cardBody
        }
    }

    // MARK: - Card Body

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header row: index + name + drag handle ──
            headerRow

            // ── Expanded prescription editor ──
            if isExpanded {
                PrescriptionEditorRow(draft: draft, hasBlock: hasBlock)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Header Row

    private var headerRow: some View {
        headerLayout {
            indexLabel
            titleBlock
            moveControl
        }
        .onTapGesture { toggleExpanded() }
        // On the title row only: a menu on the whole card would also take
        // long presses inside the open editor, where holding an RPE chip
        // opens the decimal picker.
        .contentShape(Rectangle())
        .contextMenu {
            Button("Edit prescription") { toggleExpanded() }
            Button("Edit warm-up…") {
                onEditWarmup(draft)
            }
            if draft.supersetGroupID == nil {
                Button("Move to superset…") { onAssignSuperset(draft) }
            } else {
                Button("Remove from superset") { onRemoveFromSuperset(draft) }
            }
            Button("Make superset") { onAssignSuperset(draft) }
            Button("Duplicate exercise") { onDuplicate(draft) }
            if let onMoveUp { Button("Move up", action: onMoveUp) }
            if let onMoveDown { Button("Move down", action: onMoveDown) }
            Divider()
            Button("Remove", role: .destructive) { onRemove(draft) }
        }
    }

    /// Side by side normally; stacked at accessibility text sizes, where the
    /// number and MOVE would squeeze the name into a narrow column.
    private var headerLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 10))
    }

    /// Zero-padded "01", "02", … in SpaceGrotesk-Bold 26pt, or "SS" in
    /// bruSignal when in a superset. It takes its own width, so the number
    /// is never cut.
    private var indexLabel: some View {
        let inSuperset = draft.supersetGroupID != nil
        let number = String(format: "%02d", index + 1)
        return Text(inSuperset ? "SS" : number)
            .font(.bru(.grotesk, size: 26))
            .monospacedDigit()
            .foregroundStyle(inSuperset ? Color.bruSignalText : Color.bruInk)
            .lineLimit(1)
            .fixedSize()
            .accessibilityLabel(inSuperset ? "Superset" : number)
            .accessibilityIdentifier("routine.exercise.number.\(index + 1)")
    }

    /// Name + sub-line. A tap on the row, the name included, opens and
    /// closes the prescription editor.
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(draft.exercise?.name ?? "Exercise")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
                .multilineTextAlignment(.leading)
                .accessibilityIdentifier("routine.exercise.name.\(index + 1)")
                .accessibilityHint(isExpanded ? "Collapses prescription editor" : "Expands prescription editor")

            Text(subLine)
                .font(BRUFont.labelSmall)
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("routine.exercise.summary.\(index + 1)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Explicit moves work with touch and VoiceOver, including in a ScrollView.
    private var moveControl: some View {
        Menu {
            Button("Move up") { onMoveUp?() }.disabled(onMoveUp == nil)
            Button("Move down") { onMoveDown?() }.disabled(onMoveDown == nil)
        } label: {
            BRUChip("Move")
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Move exercise \(index + 1)")
        .accessibilityIdentifier("routine.exercise.reorder.\(index + 1)")
    }

    private func toggleExpanded() {
        withAnimation(.easeInOut(duration: 0.18)) {
            isExpanded.toggle()
        }
    }

    // MARK: - Sub-line

    /// "{equipment} · {prescription summary}"
    /// Equipment from exercise.equipment; summary is sets × reps · rest.
    private var subLine: String {
        let equipment = draft.exercise?.equipmentRaw ?? ""
        let summary = prescriptionSummary
        if equipment.isEmpty {
            return summary
        }
        return "\(equipment) · \(summary)"
    }

    /// "3×8–12 · 3:00" — sets × reps · rest.
    private var prescriptionSummary: String {
        let reps = draft.targetRepsLow == draft.targetRepsHigh
            ? "\(draft.targetRepsLow)"
            : "\(draft.targetRepsLow)–\(draft.targetRepsHigh)"
        return "\(draft.targetSets)×\(reps) · \(restClock(draft.prescribedRestSeconds))"
    }
}

// MARK: - Preview

#if DEBUG
#Preview("RoutineExerciseCard — collapsed") {
    @Previewable @State var isExpanded = false
    let draft = RoutineExerciseDraft()
    return RoutineExerciseCard(
        draft: draft,
        hasBlock: false,
        index: 0,
        isExpanded: $isExpanded
    )
    .background(Color.bruPaper)
}

#Preview("RoutineExerciseCard — expanded") {
    @Previewable @State var isExpanded = true
    let draft = RoutineExerciseDraft()
    draft.targetSets = 4
    draft.targetRepsLow = 6
    draft.targetRepsHigh = 8
    draft.targetRPE = 8.5
    return ScrollView {
        RoutineExerciseCard(
            draft: draft,
            hasBlock: false,
            index: 0,
            isExpanded: $isExpanded
        )
    }
    .background(Color.bruPaper)
}
#endif
