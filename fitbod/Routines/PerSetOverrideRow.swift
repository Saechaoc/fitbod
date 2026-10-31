//
//  PerSetOverrideRow.swift
//  fitbod
//
//  Phase 2.1 Plan 05 REWRITE — BRU 4-column grid replacing the old HStack.
//  Preserves the existing @Bindable PerSetOverrideDraft binding.
//
//  4-column HStack:
//    "S{N}" labelSmall (24pt wide)                    — SetRowLabels
//    set-kind labelSmall UPPERCASE (60pt wide)        — TOP → bruSignal
//    TextField reps displayMedium 18pt right-aligned  — TOP → bruSignal
//    TextField RPE  displayMedium 18pt right-aligned  — TOP → bruSignal
//  Row background: TOP → bruSignal 6% tint, others → clear.
//  The fields' 44pt width grows with the text. At accessibility sizes the
//  fields move under the labels, which would otherwise break mid-word.
//
//  Swipe-to-delete is wired by the parent PrescriptionEditorRow (.swipeActions).
//
//  Reference: bru-screens/routine-builder.jsx lines 73-89
//  BRU contract: NO accentColor / NO Image(systemName:) / NO Capsule / NO RoundedRectangle
//  NO Apple HIG semantic fonts
//

import SwiftUI

public struct PerSetOverrideRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title3) private var fieldWidth: CGFloat = 44
    @Bindable public var draft: PerSetOverrideDraft
    public let isTop: Bool

    public init(draft: PerSetOverrideDraft, isTop: Bool = false) {
        self.draft = draft
        self.isTop = isTop
    }

    // MARK: Body

    public var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Beside the labels, the fields would break them mid-word.
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) { labels }
                    HStack(spacing: 6) {
                        Spacer(minLength: 0)
                        repsField
                        rpeField
                    }
                }
            } else {
                HStack(spacing: 6) {
                    labels
                    Spacer()
                    repsField
                    rpeField
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        // TOP row: 6% signal tint background per UI-SPEC + JSX reference
        .background(isTop ? Color.bruSignal.opacity(0.06) : Color.clear)
    }

    // MARK: Columns

    /// Columns 1 and 2: S{N} and the set kind; TOP gets bruSignal, others bruInk.
    private var labels: some View {
        SetRowLabels(
            setNumber: draft.setIndex + 1,
            kind: isTop ? "TOP" : "WORK",
            kindColor: isTop ? Color.bruSignalText : Color.bruInk
        )
    }

    /// Column 3: reps TextField displayMedium 18pt right-aligned.
    private var repsField: some View {
        TextField(
            "reps",
            value: Binding(
                get: { draft.targetRepsLow ?? 0 },
                set: { draft.targetRepsLow = $0 == 0 ? nil : $0 }
            ),
            format: .number
        )
        .font(BRUFont.displayMedium)
        .foregroundStyle(isTop ? Color.bruSignalText : Color.bruInk)
        .keyboardType(.numberPad)
        .multilineTextAlignment(.trailing)
        .frame(width: fieldWidth)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("Reps override, set \(draft.setIndex + 1)")
    }

    /// Column 4: RPE TextField displayMedium 18pt right-aligned.
    private var rpeField: some View {
        TextField(
            "RPE",
            value: Binding(
                get: { draft.targetRPE ?? 0 },
                set: { draft.targetRPE = $0 == 0 ? nil : $0 }
            ),
            format: .number.precision(.fractionLength(0...1))
        )
        .font(BRUFont.displayMedium)
        .foregroundStyle(isTop ? Color.bruSignalText : Color.bruInk)
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
        .frame(width: fieldWidth)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("RPE override, set \(draft.setIndex + 1)")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("PerSetOverrideRow — normal WORK set") {
    let draft = PerSetOverrideDraft()
    draft.setIndex = 0
    draft.targetRepsLow = 8
    draft.targetRepsHigh = 12
    draft.targetRPE = 7.0
    return PerSetOverrideRow(draft: draft, isTop: false)
        .padding(8)
        .background(Color.bruPaper)
}

#Preview("PerSetOverrideRow — TOP set") {
    let draft = PerSetOverrideDraft()
    draft.setIndex = 3
    draft.targetRepsLow = 8
    draft.targetRPE = 9.0
    return PerSetOverrideRow(draft: draft, isTop: true)
        .padding(8)
        .background(Color.bruPaper)
}
#endif
