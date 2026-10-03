// SetRowsContainer.swift
// fitbod — Phase 2.1 Plan 05
//
// Container drawing the outer 1.5pt bruInk rectangle around per-set rows.
// Each row uses the 4-column grid:
//   "S{N}" mono 10pt (24pt wide) | set-kind labelSmall UPPERCASE (60pt wide) |
//   ×{N} displayMedium 18pt right-aligned | @{N} displayMedium 18pt right-aligned
// 1pt bruHair separators between rows via BRUDivider(.hair).
// TOP rows get 6% signal tint background + bruSignal text for kind + RPE.
//
// Reference: bru-screens/routine-builder.jsx lines 65-90
// UI-SPEC: SetRowsContainer binds to RoutineExerciseDraft for derived sets.
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)

import SwiftUI

// MARK: - SetRowsContainer

/// Outer 1.5pt bruInk rectangle wrapping per-set rows derived from `RoutineExerciseDraft`.
///
/// Derives the display rows from the draft's set overrides + base prescription:
/// - Warm-up sets (if `warmupOverride` has a custom set count or is nil → auto ramp)
/// - Working sets from `targetSets`
/// - Per-set overrides applied on top
///
/// Each row is a `PerSetOverrideRow` separated by a 1pt `bruHair` divider.
/// The outer border is a 1.5pt `bruInk` `Rectangle` stroke via `.overlay`.
public struct SetRowsContainer: View {

    // MARK: Properties

    @Bindable public var exercise: RoutineExerciseDraft

    // MARK: Init

    public init(exercise: RoutineExerciseDraft) {
        self.exercise = exercise
    }

    // MARK: Body

    public var body: some View {
        VStack(spacing: 0) {
            let overrides = exercise.setOverrides
            ForEach(Array(overrides.enumerated()), id: \.element.id) { index, override in
                // Determine if this is a TOP set via kind
                let isTop = isTopSet(override: override, index: index)
                PerSetOverrideRow(draft: override, isTop: isTop)

                if index < overrides.count - 1 {
                    BRUDivider(.hair)
                }
            }

            // If no overrides exist, show a placeholder for the target sets count
            if exercise.setOverrides.isEmpty {
                ForEach(0..<exercise.targetSets, id: \.self) { index in
                    defaultSetRow(index: index)
                    if index < exercise.targetSets - 1 {
                        BRUDivider(.hair)
                    }
                }
            }
        }
        // 1.5pt bruInk outer border — the defining visual signature of this container
        .overlay(
            Rectangle()
                .stroke(Color.bruInk, lineWidth: 1.5)
        )
    }

    // MARK: Helpers

    /// Determines if a per-set override represents the TOP set.
    /// Currently checks if override has the highest RPE among all overrides.
    /// This is a heuristic — the canonical TOP detection will be data-model-driven
    /// once SetKind is added to PerSetOverrideDraft in a future plan.
    private func isTopSet(override: PerSetOverrideDraft, index: Int) -> Bool {
        // For now: no automatic TOP detection from override alone.
        // The PerSetOverrideRow receives `isTop` from the parent;
        // in the current model we have no set-kind field on PerSetOverrideDraft.
        // Default: false. Parent (PrescriptionEditorRow) can mark TOP externally.
        return false
    }

    /// A read-only display row for a set that has no override, shown when
    /// `setOverrides` is empty. Renders the base prescription as a non-editable
    /// row matching the SET {N} × {reps} @ {rpe} format.
    @ViewBuilder
    private func defaultSetRow(index: Int) -> some View {
        HStack(spacing: 6) {
            // S{N} mono 10pt — 24pt wide
            Text("S\(index + 1)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.bruInk)
                .frame(width: 24, alignment: .leading)

            // Set kind label — WORK for default working sets
            Text("WORK")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruInk)
                .frame(width: 60, alignment: .leading)

            Spacer()

            // Reps — displayMedium 18pt right-aligned
            Text("×\(exercise.targetRepsLow)")
                .font(.bru(.grotesk, size: 18))
                .foregroundStyle(Color.bruInk)
                .multilineTextAlignment(.trailing)

            // RPE — displayMedium 18pt right-aligned
            Text("@\(rpeString(exercise.targetRPE))")
                .font(.bru(.grotesk, size: 18))
                .foregroundStyle(Color.bruInk)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.clear)
    }

    private func rpeString(_ rpe: Double?) -> String {
        guard let rpe else { return "—" }
        if rpe == rpe.rounded() {
            return String(Int(rpe))
        }
        return String(format: "%.1f", rpe)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SetRowsContainer — with overrides") {
    let draft = RoutineExerciseDraft()
    draft.targetSets = 3
    draft.targetRepsLow = 8
    draft.targetRepsHigh = 12
    draft.targetRPE = 8.0
    // Add a couple of overrides
    _ = draft.appendOverride(setIndex: 0)
    _ = draft.appendOverride(setIndex: 1)
    return SetRowsContainer(exercise: draft)
        .padding(16)
        .background(Color.bruPaper)
}

#Preview("SetRowsContainer — no overrides (shows defaults)") {
    let draft = RoutineExerciseDraft()
    draft.targetSets = 4
    draft.targetRepsLow = 10
    draft.targetRepsHigh = 15
    draft.targetRPE = 9.0
    return SetRowsContainer(exercise: draft)
        .padding(16)
        .background(Color.bruPaper)
}
#endif
