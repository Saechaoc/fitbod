//
//  PerSetOverrideRow.swift
//  fitbod
//
//  Phase 2.1 Plan 05 REWRITE — BRU 4-column grid replacing the old HStack.
//  Preserves the existing @Bindable PerSetOverrideDraft binding.
//
//  4-column HStack:
//    "S{N}" mono 10pt (24pt wide)
//    set-kind labelSmall UPPERCASE 10pt (60pt wide) — TOP → bruSignal
//    TextField reps displayMedium 18pt right-aligned  — TOP → bruSignal
//    TextField RPE  displayMedium 18pt right-aligned  — TOP → bruSignal
//  Row background: TOP → bruSignal 6% tint, others → clear.
//
//  Swipe-to-delete is wired by the parent PrescriptionEditorRow (.swipeActions).
//
//  Reference: bru-screens/routine-builder.jsx lines 73-89
//  BRU contract: NO accentColor / NO Image(systemName:) / NO Capsule / NO RoundedRectangle
//  NO Apple HIG semantic fonts
//

import SwiftUI

public struct PerSetOverrideRow: View {
    @Bindable public var draft: PerSetOverrideDraft
    public let isTop: Bool

    public init(draft: PerSetOverrideDraft, isTop: Bool = false) {
        self.draft = draft
        self.isTop = isTop
    }

    // MARK: Body

    public var body: some View {
        HStack(spacing: 6) {
            // Column 1: S{N} mono 10pt — 24pt wide
            Text("S\(draft.setIndex + 1)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.bruInk)
                .frame(width: 24, alignment: .leading)

            // Column 2: set-kind labelSmall 10pt UPPERCASE — 60pt wide
            // TOP gets bruSignal; others bruInk
            Text(isTop ? "TOP" : "WORK")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(isTop ? Color.bruSignal : Color.bruInk)
                .frame(width: 60, alignment: .leading)

            Spacer()

            // Column 3: reps TextField displayMedium 18pt right-aligned
            TextField(
                "reps",
                value: Binding(
                    get: { draft.targetRepsLow ?? 0 },
                    set: { draft.targetRepsLow = $0 == 0 ? nil : $0 }
                ),
                format: .number
            )
            .font(.bru(.grotesk, size: 18))
            .foregroundStyle(isTop ? Color.bruSignal : Color.bruInk)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 44)

            // Column 4: RPE TextField displayMedium 18pt right-aligned
            TextField(
                "RPE",
                value: Binding(
                    get: { draft.targetRPE ?? 0 },
                    set: { draft.targetRPE = $0 == 0 ? nil : $0 }
                ),
                format: .number.precision(.fractionLength(0...1))
            )
            .font(.bru(.grotesk, size: 18))
            .foregroundStyle(isTop ? Color.bruSignal : Color.bruInk)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 44)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        // TOP row: 6% signal tint background per UI-SPEC + JSX reference
        .background(isTop ? Color.bruSignal.opacity(0.06) : Color.clear)
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
