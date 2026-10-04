//
//  ExerciseRow.swift
//  fitbod
//
//  One library row: the full exercise name (wraps — catalog names run to
//  58 characters), then "Equipment · Primary muscles", plus a CUSTOM tag
//  for user-authored entries. In multi-select pickers a leading check
//  circle shows selection.
//

import SwiftUI

public struct ExerciseRow: View {
    let exercise: Exercise
    let isSelected: Bool?

    public init(exercise: Exercise, isSelected: Bool? = nil) {
        self.exercise = exercise
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Chalk.Space.md) {
            if let isSelected {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.chalkInk : Color.chalkSurface)
                    Circle()
                        .strokeBorder(Color.chalkInk, lineWidth: Chalk.Line.strong)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.footnote.weight(.heavy))
                            .foregroundStyle(.chalkCanvas)
                    }
                }
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: Chalk.Space.xxs) {
                Text(exercise.name)
                    .font(.chalkHeadline)
                    .foregroundStyle(.chalkInk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Chalk.Space.sm) {
                    Text(meta)
                        .font(.chalkFootnote)
                        .foregroundStyle(.chalkInk2)
                    if exercise.isCustom {
                        ChalkTag("Custom", style: .subtle)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Chalk.Space.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityText))
    }

    /// "Barbell · Chest · Triceps"
    private var meta: String {
        ([Self.equipmentName(exercise.equipmentRaw)] + primaryMuscles).joined(separator: " · ")
    }

    private var primaryMuscles: [String] {
        exercise.primaryMuscleSlugsJoined
            .split(separator: "|")
            .map { MuscleRegionMap.displayName(for: String($0)) }
    }

    private var accessibilityText: String {
        var text = "\(exercise.name), \(meta)"
        if exercise.isCustom { text += ", custom" }
        if let isSelected { text += isSelected ? ", selected" : "" }
        return text
    }

    /// "weighted_bodyweight" → "Weighted Bodyweight".
    public static func equipmentName(_ raw: String) -> String {
        raw.split(separator: "_").map { $0.capitalized }.joined(separator: " ")
    }
}

#Preview("Rows") {
    List {
        ExerciseRow(exercise: .previewSample(name: "Barbell Bench Press - Medium Grip", equipment: .barbell, mechanic: .compound, primaryMuscleSlugs: ["chest"]))
        ExerciseRow(exercise: .previewSample(name: "Lying Close-Grip Barbell Triceps Extension Behind The Head", equipment: .barbell, mechanic: .isolation, primaryMuscleSlugs: ["triceps"]), isSelected: true)
        ExerciseRow(exercise: .previewSample(name: "Cambered Bar Paused Bench Press", equipment: .barbell, mechanic: .compound, primaryMuscleSlugs: ["chest"], isCustom: true))
    }
}
