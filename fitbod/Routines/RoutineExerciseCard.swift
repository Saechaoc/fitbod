//
//  RoutineExerciseCard.swift
//  fitbod
//
//  Phase 2.1 Plan 05 REWRITE — replaces SF Symbol chevron/flame glyphs,
//  Apple HIG fonts, accentColor rail with the BRU brutalist card layout.
//
//  Layout (collapsed):
//    HStack:
//      leading: index zero-padded "01" SpaceGrotesk-Bold 26pt (28pt wide)
//      middle VStack:
//        name: JetBrainsMono-Bold 14pt (BRUFont.bodyEmphasis)
//        sub-line: "{equipment} · {spec}" labelSmall 10pt UPPERCASE bruMuted
//      trailing: "⋮⋮" drag handle in bruMuted (NOT an SF Symbol)
//
//  When expanded: PrescriptionEditorRow mounted inline.
//  When supersetGroupID != nil: wrapped in BRUSupersetBracket.
//  Leading index shows "SS" in bruSignal when in a superset.
//
//  Long-press contextMenu preserved from Phase 3.
//  All @Bindable bindings, drag-handle .onMove, warmup-config-sheet trigger
//  are preserved from Phase 3.1.
//
//  BRU contract: NO accentColor / NO Image(systemName:) / NO Capsule /
//  NO RoundedRectangle / NO Apple HIG semantic fonts
//

import SwiftUI

public struct RoutineExerciseCard: View {
    @Bindable public var draft: RoutineExerciseDraft
    public let hasBlock: Bool
    public let index: Int
    @Binding public var isExpanded: Bool

    public let onAssignSuperset: (RoutineExerciseDraft) -> Void
    public let onRemoveFromSuperset: (RoutineExerciseDraft) -> Void
    public let onDuplicate: (RoutineExerciseDraft) -> Void
    public let onRemove: (RoutineExerciseDraft) -> Void
    public let onEditWarmup: (RoutineExerciseDraft) -> Void

    public init(
        draft: RoutineExerciseDraft,
        hasBlock: Bool = false,
        index: Int = 0,
        isExpanded: Binding<Bool>,
        onAssignSuperset: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onRemoveFromSuperset: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onDuplicate: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onRemove: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onEditWarmup: @escaping (RoutineExerciseDraft) -> Void = { _ in }
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
        .contentShape(Rectangle())
        .contextMenu {
            Button("Edit prescription") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            }
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
            Divider()
            Button("Remove", role: .destructive) { onRemove(draft) }
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 10) {
            // Leading index — zero-padded "01", "02", … in SpaceGrotesk-Bold 26pt
            // When in a superset: show "SS" in bruSignal instead of numeric index
            if draft.supersetGroupID != nil {
                Text("SS")
                    .font(.bru(.grotesk, size: 26))
                    .foregroundStyle(Color.bruSignal)
                    .frame(width: 28, alignment: .leading)
                    .lineLimit(1)
            } else {
                Text(String(format: "%02d", index + 1))
                    .font(.bru(.grotesk, size: 26))
                    .foregroundStyle(Color.bruInk)
                    .frame(width: 28, alignment: .leading)
                    .lineLimit(1)
            }

            // Middle: name + sub-line
            VStack(alignment: .leading, spacing: 2) {
                Text(draft.exercise?.name ?? "Exercise")
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                    .multilineTextAlignment(.leading)

                Text(subLine)
                    .font(BRUFont.labelSmall)
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Trailing: typographic drag handle "⋮⋮" (NOT an SF Symbol)
            Text("⋮⋮")
                .font(.system(size: 14))
                .foregroundStyle(Color.bruMuted)
                .accessibilityHidden(true)
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.18)) {
                isExpanded.toggle()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isExpanded ? "Collapses prescription editor" : "Expands prescription editor")
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

    /// "3×8–12 · 180s" — sets × reps · rest.
    private var prescriptionSummary: String {
        let reps = draft.targetRepsLow == draft.targetRepsHigh
            ? "\(draft.targetRepsLow)"
            : "\(draft.targetRepsLow)–\(draft.targetRepsHigh)"
        return "\(draft.targetSets)×\(reps) · \(draft.prescribedRestSeconds)s"
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
