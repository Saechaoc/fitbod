//
//  RoutineExerciseCard.swift
//  fitbod
//
//  Wave-3 plan 03-02 — one row in the routine builder's exercise list.
//  Renders a `DisclosureGroup` whose label is the exercise's name +
//  intent chip + collapsed prescription summary ("3×8–12 · 180s") and
//  whose body is the inline `PrescriptionEditorRow`.
//
//  The intent chip uses the UI-SPEC § Color § Accent surface #15
//  treatment — `Color.accentColor.opacity(0.15)` capsule fill with
//  accent-colored caption label.
//

import SwiftUI

public struct RoutineExerciseCard: View {
    @Bindable public var draft: RoutineExerciseDraft
    @Binding public var isExpanded: Bool

    public init(draft: RoutineExerciseDraft, isExpanded: Binding<Bool>) {
        self.draft = draft
        self._isExpanded = isExpanded
    }

    public var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            PrescriptionEditorRow(draft: draft)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.exercise?.name ?? "Exercise")
                    .font(.body)
                HStack(spacing: 8) {
                    intentChip
                    Text(prescriptionSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(Color.accentColor)
    }

    /// UI-SPEC § Color § Accent surface #15 — intent chip on the
    /// builder exercise card. Capsule fill in 15%-opacity accent +
    /// accent-colored caption label.
    private var intentChip: some View {
        Text(draft.intent.rawValue.capitalized)
            .font(.caption)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule().fill(Color.accentColor.opacity(0.15))
            }
            .accessibilityLabel("Intent: \(draft.intent.rawValue.capitalized)")
    }

    /// "3×8–12 · 180s" — sets × reps · rest. When `targetRepsLow ==
    /// targetRepsHigh` the en-dash collapses to a single value.
    private var prescriptionSummary: String {
        let reps = draft.targetRepsLow == draft.targetRepsHigh
            ? "\(draft.targetRepsLow)"
            : "\(draft.targetRepsLow)–\(draft.targetRepsHigh)"
        return "\(draft.targetSets)×\(reps) · \(draft.prescribedRestSeconds)s"
    }
}
