//
//  MuscleWeightRow.swift
//  fitbod
//
//  One muscle in the custom exercise editor's stimulus sections, drawn the
//  way bru-screens/custom-exercise.jsx draws it (review item 20):
//
//    [PRIMARY]  CHEST                                   REMOVE
//    [0.25][0.5][0.75][ 1 ]                               100%
//
//  - The role chip is a button. A tap flips primary and secondary, and the
//    editor moves the row to the other section.
//  - The design's four weight ticks are 25%, 50%, 75% and 100%; the one
//    that holds the weight is filled. A stored weight between ticks, such
//    as 80% from the old slider, keeps its value and fills no tick until
//    the user taps one. The percent on the right always shows the weight.
//  - REMOVE takes the muscle out of the draft.
//
//  Every control is at least 44pt square. At accessibility text sizes the
//  row stacks: chip and REMOVE, the name, the ticks, then the percent.
//
//  ## Accessibility
//
//  The row is a container identified by the muscle's slug. The chip reads
//  "Primary" or "Secondary" with a hint that says what a tap does, each
//  tick reads its percent and is marked selected when it holds the weight,
//  and REMOVE reads "Remove {muscle}".
//

import SwiftUI

/// Single muscle-assignment row inside the custom exercise editor's
/// stimulus sections. Bound to one `MuscleAssignment` from the parent
/// draft; the role chip and weight ticks write back through the binding.
struct MuscleWeightRow: View {
    @Binding var assignment: CustomExerciseDraft.MuscleAssignment
    /// Display name resolved by the editor (looking up the slug in
    /// its `@Query<MuscleGroup>` result). Passed in rather than
    /// re-querying here so this row doesn't need its own `@Query`.
    let displayName: String
    /// Closure the editor supplies to remove this row from the
    /// parent's `muscles` array.
    let onDelete: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The design's four weight ticks.
    static let tickWeights: [Double] = [0.25, 0.5, 0.75, 1.0]

    var body: some View {
        VStack(alignment: .leading, spacing: BRUMetrics.Spacing.related) {
            if dynamicTypeSize.isAccessibilitySize {
                // The chip and REMOVE share a line until, at the very
                // largest sizes, they no longer fit beside each other.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: BRUMetrics.Spacing.related) {
                        roleChip
                        Spacer(minLength: BRUMetrics.Spacing.related)
                        removeButton
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        roleChip
                        removeButton
                    }
                }
                name
                ticks
                percentText
            } else {
                HStack(spacing: 10) {
                    roleChip
                    name
                    Spacer(minLength: BRUMetrics.Spacing.related)
                    removeButton
                }
                HStack(spacing: BRUMetrics.Spacing.related) {
                    ticks
                    Spacer(minLength: BRUMetrics.Spacing.related)
                    percentText
                }
            }
        }
        .padding(.vertical, BRUMetrics.Spacing.related)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("customExercise.muscle.\(assignment.slug)")
    }

    // MARK: - Parts

    private var isPrimary: Bool { assignment.role == .primary }

    private var roleChip: some View {
        Button {
            assignment.role = isPrimary ? .secondary : .primary
        } label: {
            BRUChip(isPrimary ? "Primary" : "Secondary", color: isPrimary ? .bruSignal : nil, fill: isPrimary)
                .frame(minHeight: BRUMetrics.touchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPrimary ? "Primary" : "Secondary")
        .accessibilityHint(isPrimary ? "Makes \(displayName) secondary" : "Makes \(displayName) primary")
        .accessibilityIdentifier("customExercise.role.\(assignment.slug)")
    }

    private var name: some View {
        Text(displayName)
            .font(BRUFont.bodyEmphasis)
            .textCase(.uppercase)
            .foregroundStyle(Color.bruInk)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(displayName)
    }

    private var removeButton: some View {
        Button(action: onDelete) {
            Text("Remove")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruSignalText)
                .frame(minWidth: BRUMetrics.touchTarget, minHeight: BRUMetrics.touchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(displayName)")
        .accessibilityIdentifier("customExercise.remove.\(assignment.slug)")
    }

    private var ticks: some View {
        HStack(spacing: BRUMetrics.Spacing.tight) {
            ForEach(Self.tickWeights, id: \.self) { tick in
                tickButton(tick)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Stimulus weight for \(displayName)")
    }

    private func tickButton(_ tick: Double) -> some View {
        let isSelected = abs(assignment.weight - tick) < 0.001
        let tickPercent = Self.percent(of: tick)
        return Button {
            assignment.weight = tick
        } label: {
            Text(String(format: "%g", tick))
                .font(BRUFont.labelSmall)
                .foregroundStyle(isSelected ? Color.bruPaper : Color.bruInk)
                .padding(.horizontal, BRUMetrics.Spacing.tight)
                .frame(minWidth: BRUMetrics.touchTarget, minHeight: BRUMetrics.touchTarget)
                .background(isSelected ? Color.bruInk : Color.clear)
                .overlay(Rectangle().strokeBorder(Color.bruInk, lineWidth: BRUMetrics.Border.outline))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tickPercent) percent")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("customExercise.weight.\(assignment.slug).\(tickPercent)")
    }

    /// The stored weight as a whole percent, such as "100%" or "80%".
    private var percentText: some View {
        Text("\(Self.percent(of: assignment.weight))%")
            .font(BRUFont.bodyEmphasis)
            .foregroundStyle(Color.bruMuted)
            .accessibilityIdentifier("customExercise.percent.\(assignment.slug)")
    }

    private static func percent(of weight: Double) -> Int {
        Int((weight * 100).rounded())
    }
}

#Preview("Muscle weight rows") {
    @Previewable @State var chest = CustomExerciseDraft.MuscleAssignment(
        slug: "chest",
        role: .primary,
        weight: 1.0
    )
    @Previewable @State var triceps = CustomExerciseDraft.MuscleAssignment(
        slug: "triceps",
        role: .secondary,
        weight: 0.8
    )
    VStack(spacing: 0) {
        MuscleWeightRow(assignment: $chest, displayName: "Chest", onDelete: {})
        BRUDivider(.hair)
        MuscleWeightRow(assignment: $triceps, displayName: "Triceps", onDelete: {})
    }
    .padding(.horizontal, 16)
    .background(Color.bruPaper)
}
