// ExerciseRow.swift
// fitbod
//
// One exercise in the library list (browse and picker modes).
//
// Layout:
//   Name (Space Grotesk 18, wraps)                    [accessory]
//   [PRIMARY MUSCLE] [EQUIPMENT] [MECHANIC] [CUSTOM]
//
// The accessory is the logged count ("12× / LOGGED") in browse mode and a
// signal "+ ADD" in picker mode, so the row tells you what a tap does.

import SwiftUI

public struct ExerciseRow: View {

    public enum Accessory: Equatable {
        /// Browse mode: how many workouts included this exercise.
        case loggedCount(Int)
        /// Picker mode: tapping adds the exercise.
        case add
    }

    let exercise: Exercise
    let accessory: Accessory

    public init(exercise: Exercise, accessory: Accessory = .loggedCount(0)) {
        self.exercise = exercise
        self.accessory = accessory
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(exercise.name)
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruInk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                tagRow
            }
            Spacer(minLength: 8)
            accessoryView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Tags

    private var tagRow: some View {
        // Wrapping layout so long muscle names never clip at 390pt or at
        // large Dynamic Type sizes.
        BRUFlowLayout(spacing: 6) {
            if let muscle = Self.primaryMuscleLabel(exercise) {
                BRUChip(muscle)
            }
            BRUChip(Self.displayName(forEquipmentRaw: exercise.equipmentRaw))
            BRUChip(exercise.mechanicRaw.capitalized)
            if exercise.isCustom {
                BRUChip("Custom", color: .bruSignal)
                    .accessibilityLabel("Custom exercise")
            }
        }
    }

    // MARK: - Accessory

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .loggedCount(let count):
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(count)×")
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(count > 0 ? Color.bruInk : Color.bruMuted)
                Text("Logged")
                    .font(BRUFont.labelMicro)
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(count == 1 ? "Logged once" : "Logged \(count) times")
        case .add:
            Text("+ Add")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruSignalText)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Helpers

    /// First primary muscle, title-cased ("lower_back" → "Lower Back").
    static func primaryMuscleLabel(_ exercise: Exercise) -> String? {
        let first = exercise.primaryMuscleSlugsJoined
            .split(whereSeparator: { $0 == "|" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        return first.map { $0.replacingOccurrences(of: "_", with: " ").capitalized }
    }

    /// Equipment display name. `weighted_bodyweight` is split on
    /// underscore and capitalised so the UI reads "Weighted Bodyweight"
    /// rather than "Weighted_bodyweight".
    static func displayName(forEquipmentRaw raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
