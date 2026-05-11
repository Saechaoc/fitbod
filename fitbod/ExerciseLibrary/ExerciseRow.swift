//
//  ExerciseRow.swift
//  fitbod
//
//  One row of the library list. Per UI-SPEC § Copywriting Contract
//  / § Typography:
//
//    - Name in `.body` (.primary)
//    - Equipment + mechanic metadata in `.caption` (.secondary), separated
//      by a verbatim mid-dot " · "
//    - "Custom" tag for user-authored entries — `.caption.weight(.semibold)`
//      on a `Color.accentColor.opacity(0.15)` capsule (UI-SPEC § Library
//      screen / Custom-exercise row inline tag)
//
//  The row reads only from the passed-in `Exercise` model — no `@Query`,
//  no environment context. SwiftData propagates property-level
//  invalidations through the `@Model` macro so a custom exercise being
//  edited from elsewhere re-renders this row without any extra plumbing.
//
//  Touch-target / hit-area: the parent `List` row already supplies a
//  full-width tappable area via `NavigationLink`, so this view only
//  styles the cell content. No `.contentShape` override here.
//

import SwiftUI

/// A single row in the exercise library list — name, metadata, and
/// the optional "Custom" tag.
public struct ExerciseRow: View {
    let exercise: Exercise

    public init(exercise: Exercise) {
        self.exercise = exercise
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(displayName(forEquipmentRaw: exercise.equipmentRaw))
                    Text("·")
                    Text(exercise.mechanicRaw.capitalized)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if exercise.isCustom {
                customTag
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Custom tag

    /// The "Custom" capsule per UI-SPEC § Library screen / Custom-exercise
    /// row inline tag. Caption weight semibold + accent foreground + a
    /// 15%-opacity accent fill (the accent never appears at full opacity
    /// in this position — that's reserved for active filter chips).
    private var customTag: some View {
        Text("Custom")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background {
                Capsule().fill(Color.accentColor.opacity(0.15))
            }
            .accessibilityLabel("Custom exercise")
    }

    // MARK: - Helpers

    /// Equipment display name. `weighted_bodyweight` is split on
    /// underscore and capitalised so the UI reads "Weighted Bodyweight"
    /// rather than "Weighted_bodyweight".
    private func displayName(forEquipmentRaw raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

#Preview("Built-in exercise") {
    ExerciseRow(
        exercise: Exercise.previewSample(
            name: "Barbell Bench Press",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["chest"]
        )
    )
    .padding()
}

#Preview("Custom exercise") {
    ExerciseRow(
        exercise: Exercise.previewSample(
            name: "Cambered Bar Bench",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["chest"],
            isCustom: true
        )
    )
    .padding()
}
