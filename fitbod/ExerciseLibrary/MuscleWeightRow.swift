//
//  MuscleWeightRow.swift
//  fitbod
//
//  Wave-3 plan 03-04 — one row in the custom-exercise editor's Muscles
//  section. Bound to a `Binding<CustomExerciseDraft.MuscleAssignment>`
//  so the user's edits flow back to the parent draft.
//
//  Visual layout (per UI-SPEC § Custom exercise editor):
//
//    +------------------------------------------------------------+
//    | {Muscle Name}         [ Primary | Secondary ]   [trash]    |
//    | [---------------- slider 0.0–1.0 -------------------] 100% |
//    +------------------------------------------------------------+
//
//  - Top row: muscle display name (resolved from slug → MuscleGroup
//    by the editor), segmented role picker, destructive trash button.
//  - Bottom row: 0.0–1.0 slider with step=0.05, and a percent display
//    on the trailing edge (e.g. "100%", "50%").
//
//  ## Accessibility contract (UI-SPEC § Accessibility)
//
//  - `accessibilityLabel = "Stimulus weight for {muscle}"` on the
//    slider.
//  - `accessibilityValue = "{percent} percent"` on the slider (the
//    voice-over readout becomes "Stimulus weight for Chest, 100
//    percent").
//
//  The role picker is `.segmented` style for fast role-flipping. The
//  trash button is `.destructive` per HIG; the editor's `onDelete`
//  closure pops the row from the draft's `muscles` array.
//

import SwiftUI

/// Single muscle-assignment row inside the custom-exercise editor's
/// Muscles section. Bound to one `MuscleAssignment` from the parent
/// draft; the user's edits to role + weight propagate via the binding.
struct MuscleWeightRow: View {
    @Binding var assignment: CustomExerciseDraft.MuscleAssignment
    /// Display name resolved by the editor (looking up the slug in
    /// its `@Query<MuscleGroup>` result). Passed in rather than
    /// re-querying here so this row doesn't need its own `@Query`.
    let displayName: String
    /// Closure the editor supplies to remove this row from the
    /// parent's `muscles` array.
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(displayName)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                Picker("Role", selection: $assignment.role) {
                    ForEach(
                        CustomExerciseDraft.MuscleAssignment.Role.allCases,
                        id: \.self
                    ) { role in
                        Text(role.rawValue.capitalized).tag(role)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                .labelsHidden()

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Remove \(displayName)")
            }

            HStack {
                Slider(value: $assignment.weight, in: 0.0...1.0, step: 0.05)
                    .accessibilityLabel("Stimulus weight for \(displayName)")
                    .accessibilityValue("\(percent) percent")

                Text("\(percent)%")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }

    /// Integer percent rendering of the weight slider — matches
    /// UI-SPEC § Custom exercise editor "{integer percent}%" display.
    private var percent: Int {
        Int((assignment.weight * 100).rounded())
    }
}

#Preview("Muscle weight row") {
    @Previewable @State var assignment = CustomExerciseDraft.MuscleAssignment(
        slug: "chest",
        role: .primary,
        weight: 1.0
    )
    Form {
        MuscleWeightRow(
            assignment: $assignment,
            displayName: "Chest",
            onDelete: {}
        )
    }
}
