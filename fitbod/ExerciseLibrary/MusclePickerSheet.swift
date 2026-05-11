//
//  MusclePickerSheet.swift
//  fitbod
//
//  Wave-3 plan 03-04 — modal `@Query<MuscleGroup>`-driven list used
//  by the custom-exercise editor when the user taps "Add Primary
//  Muscle" / "Add Another Muscle". Tapping a row calls the supplied
//  `onSelect` closure and dismisses; "Cancel" toolbar button dismisses
//  without selection.
//
//  ## Why a sheet, not a Picker
//
//  The 17-muscle taxonomy (chest / triceps / lats / biceps / quads /
//  hamstrings / glutes / calves / shoulders / abs / lower_back /
//  forearms / traps / abductors / adductors / middle_back / neck) is
//  larger than a typical Picker is comfortable surfacing, and we want
//  the region label as secondary metadata. UI-SPEC § Custom exercise
//  editor names the surface "Select Muscle" and locks the sheet
//  affordance.
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
    @Query(sort: \MuscleGroup.slug) private var muscles: [MuscleGroup]

    var body: some View {
        NavigationStack {
            List {
                ForEach(muscles) { mg in
                    Button {
                        onSelect(mg)
                        dismiss()
                    } label: {
                        HStack {
                            Text(mg.displayName)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(mg.region.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Select Muscle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview("Muscle picker") {
    MusclePickerSheet(onSelect: { _ in })
        .modelContainer(PreviewModelContainer.make())
}
