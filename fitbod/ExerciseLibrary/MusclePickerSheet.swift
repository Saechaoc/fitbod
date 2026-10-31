//
//  MusclePickerSheet.swift
//  fitbod
//
//  The sheet the custom exercise editor opens from "+ ADD MUSCLE". A BRU
//  sheet (review item 20): a `BRUHeaderBar` with CANCEL and "Add muscle",
//  no system navigation bar, and one row per muscle. Tapping a row calls
//  the supplied `onSelect` closure and dismisses; CANCEL dismisses
//  without selection.
//
//  ## Rows show the name alone
//
//  Each row shows only the muscle's display name, and the rows sort by
//  display name. The coarse region ("Upper", "Lower", "Core") used to sit
//  beside it, and "Lower Back · Upper" read as an error. The stored region
//  is unchanged, because the Library filters read it.
//
//  ## Closure-driven selection (not a binding)
//
//  The sheet doesn't hold its own selection state — it forwards the
//  tapped `MuscleGroup` to the caller via the `onSelect` closure. The
//  editor then decides what role/weight to assign (first-added →
//  primary @ 1.0, subsequent → secondary @ 0.5) and appends the
//  resulting `CustomExerciseDraft.MuscleAssignment`. This keeps the
//  sheet stateless and the role/weight logic centralized in
//  `CustomExerciseEditor`.
//

import SwiftUI
import SwiftData

/// Modal picker presenting every `MuscleGroup` for inclusion in a
/// custom exercise. Closure-driven — `onSelect` fires with the tapped
/// `MuscleGroup` and the sheet dismisses.
struct MusclePickerSheet: View {
    let onSelect: (MuscleGroup) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var muscles: [MuscleGroup]

    var body: some View {
        VStack(spacing: 0) {
            BRUHeaderBar(
                left: HeaderAction("Cancel") { dismiss() },
                center: "Add muscle"
            )
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(sortedMuscles) { mg in
                        row(mg)
                    }
                }
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())
    }

    /// Display-name order, the way a reader scans the list.
    private var sortedMuscles: [MuscleGroup] {
        muscles.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private func row(_ mg: MuscleGroup) -> some View {
        Button {
            onSelect(mg)
            dismiss()
        } label: {
            Text(mg.displayName)
                .font(BRUFont.displayMedium)
                .foregroundStyle(Color.bruInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, BRUMetrics.Spacing.gutter)
                .padding(.vertical, BRUMetrics.Spacing.related)
                .frame(minHeight: BRUMetrics.primaryActionHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { BRUDivider(.hair) }
        .accessibilityLabel(mg.displayName)
        .accessibilityIdentifier("musclePicker.\(mg.slug)")
    }
}

#Preview("Muscle picker") {
    MusclePickerSheet(onSelect: { _ in })
        .modelContainer(PreviewModelContainer.make())
}
