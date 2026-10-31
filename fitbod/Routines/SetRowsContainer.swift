// SetRowsContainer.swift
// fitbod — Phase 2.1 Plan 05
//
// Container drawing the outer 1.5pt bruInk rectangle around per-set rows,
// one per working set at the exercise's own prescription (T110).
// Each row uses the 4-column grid:
//   "S{N}" labelSmall (24pt wide) | set-kind labelSmall UPPERCASE (60pt wide) |
//   ×{N} displayMedium 18pt right-aligned | @{N} displayMedium 18pt right-aligned
// The first two columns are SetRowLabels: both labels grow with the text,
// and at accessibility sizes they drop their column widths, which would
// clip them (Milestone 1 review item 13).
// 1pt bruHair separators between rows via BRUDivider(.hair).
//
// Reference: bru-screens/routine-builder.jsx lines 65-90
// UI-SPEC: SetRowsContainer binds to RoutineExerciseDraft for derived sets.
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)

import SwiftUI

// MARK: - SetRowsContainer

/// Outer 1.5pt bruInk rectangle wrapping one row per working set of a
/// `RoutineExerciseDraft`, each showing the exercise's own prescription.
///
/// Stored per-set overrides are not shown: the logger builds every working
/// set from the exercise's prescription and never applies them (T110).
/// Rows are separated by a 1pt `bruHair` divider; the outer border is a
/// 1.5pt `bruInk` `Rectangle` stroke via `.overlay`.
public struct SetRowsContainer: View {

    // MARK: Properties

    @Bindable public var exercise: RoutineExerciseDraft

    // MARK: Init

    public init(exercise: RoutineExerciseDraft) {
        self.exercise = exercise
    }

    // MARK: Body

    public var body: some View {
        let rows = Self.rows(for: exercise)
        VStack(spacing: 0) {
            ForEach(rows, id: \.setNumber) { row in
                setRow(row)
                if row.setNumber < rows.count {
                    BRUDivider(.hair)
                }
            }
        }
        // 1.5pt bruInk outer border — the defining visual signature of this container
        .overlay(
            Rectangle()
                .stroke(Color.bruInk, lineWidth: 1.5)
        )
    }

    // MARK: Rows

    /// One set row: its number, reps and RPE.
    struct Row: Equatable {
        let setNumber: Int
        let reps: Int
        let rpe: Double?
    }

    /// The rows the set list shows for `exercise`: every working set at the
    /// exercise's own prescription, as the logger will log it, whatever
    /// overrides it stores.
    static func rows(for exercise: RoutineExerciseDraft) -> [Row] {
        (0..<exercise.targetSets).map {
            Row(setNumber: $0 + 1, reps: exercise.targetRepsLow, rpe: exercise.targetRPE)
        }
    }

    // MARK: Helpers

    /// A read-only display row matching the S{N} WORK ×{reps} @{rpe} format.
    @ViewBuilder
    private func setRow(_ row: Row) -> some View {
        HStack(spacing: 6) {
            // S{N} and the set kind — WORK for default working sets
            SetRowLabels(setNumber: row.setNumber, kind: "WORK", kindColor: .bruInk)

            Spacer()

            // Reps — displayMedium 18pt right-aligned
            Text("×\(row.reps)")
                .font(BRUFont.displayMedium)
                .foregroundStyle(Color.bruInk)
                .multilineTextAlignment(.trailing)

            // RPE — displayMedium 18pt right-aligned
            Text("@\(rpeString(row.rpe))")
                .font(BRUFont.displayMedium)
                .foregroundStyle(Color.bruInk)
                .multilineTextAlignment(.trailing)
                // VoiceOver reads a bare dash as "em dash".
                .accessibilityLabel(row.rpe == nil
                                    ? "No target RPE"
                                    : "RPE \(rpeString(row.rpe))")
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

// MARK: - SetRowLabels

/// A set row's first two columns: "S{N}" and the set's kind, such as WORK,
/// both in labelSmall so they grow with the text. Below accessibility sizes
/// the columns keep the rows lined up; at accessibility sizes those widths
/// would clip the labels, so each label takes its own width.
struct SetRowLabels: View {
    let setNumber: Int
    let kind: String
    let kindColor: Color

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption2) private var setColumnWidth: CGFloat = 24
    @ScaledMetric(relativeTo: .caption2) private var kindColumnWidth: CGFloat = 60

    var body: some View {
        Text("S\(setNumber)")
            .font(BRUFont.labelSmall)
            .foregroundStyle(Color.bruInk)
            .frame(width: column(setColumnWidth), alignment: .leading)
            // Without its column, the set label keeps a gap from the kind.
            .padding(.trailing, dynamicTypeSize.isAccessibilitySize ? 8 : 0)

        Text(kind)
            .font(BRUFont.labelSmall)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(kindColor)
            .frame(width: column(kindColumnWidth), alignment: .leading)
    }

    private func column(_ width: CGFloat) -> CGFloat? {
        dynamicTypeSize.isAccessibilitySize ? nil : width
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SetRowsContainer") {
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
