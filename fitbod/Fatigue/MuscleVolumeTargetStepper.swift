//
//  MuscleVolumeTargetStepper.swift
//  fitbod
//
//  Phase 5 SET-05 inline editor — 4-Stepper MV/MEV/MAV/MRV editor for
//  one muscle's MuscleVolumeTarget. Shared by PerMuscleDetailView's
//  inline "Adjust Targets" section and (plan 06) Settings's
//  MuscleVolumeTargetEditor surface.
//
//  Validation: monotonic invariant MV ≤ MEV < MAV < MRV (T-05-02
//  mitigation). Violation surfaces an inline error in `.caption .systemRed`
//  below the steppers per UI-SPEC §Copywriting Contract.
//
//  Reset: "Reset to RP defaults" calls `RPVolumeLandmarks.landmark(for:)`
//  and writes the seed values back onto the @Bindable target + clears
//  the `userEdited` flag so plan 06's MuscleVolumeTargetSeeder can
//  re-seed if the user opts out of overrides.
//
//  Idempotency: any Stepper edit sets `target.userEdited = true` so
//  the seeder in plan 06 skips this row on subsequent launches per
//  VOL-03 / SET-05.
//

import SwiftUI

public struct MuscleVolumeTargetStepper: View {
    @Bindable public var target: MuscleVolumeTarget

    public init(target: MuscleVolumeTarget) {
        self.target = target
    }

    public var body: some View {
        VStack(spacing: 12) {
            stepperRow(
                label: "MV",
                suffix: "sets — maintenance",
                value: target.mv,
                onChange: { newValue in
                    target.mv = newValue
                    target.userEdited = true
                },
                a11y: "Maintenance volume for \(target.muscle?.displayName ?? "muscle")"
            )
            stepperRow(
                label: "MEV",
                suffix: "sets — min for growth",
                value: target.mev,
                onChange: { newValue in
                    target.mev = newValue
                    target.userEdited = true
                },
                a11y: "Minimum effective volume for \(target.muscle?.displayName ?? "muscle")"
            )
            stepperRow(
                label: "MAV",
                suffix: "sets — peak adaptive",
                value: target.mav,
                onChange: { newValue in
                    target.mav = newValue
                    target.userEdited = true
                },
                a11y: "Maximum adaptive volume for \(target.muscle?.displayName ?? "muscle")"
            )
            stepperRow(
                label: "MRV",
                suffix: "sets — max recoverable",
                value: target.mrv,
                onChange: { newValue in
                    target.mrv = newValue
                    target.userEdited = true
                },
                a11y: "Maximum recoverable volume for \(target.muscle?.displayName ?? "muscle")"
            )

            if !isMonotonic {
                Text("Targets must be in order: MV ≤ MEV < MAV < MRV.")
                    .font(.caption)
                    .foregroundStyle(Color(.systemRed))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button("Reset to RP defaults") {
                resetToRPDefaults()
            }
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func stepperRow(
        label: String,
        suffix: String,
        value: Int,
        onChange: @escaping (Int) -> Void,
        a11y: String
    ) -> some View {
        Stepper(
            value: Binding(
                get: { value },
                set: { onChange($0) }
            ),
            in: 1...30,
            step: 1
        ) {
            LabeledContent(label) {
                Text("\(value) \(suffix)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel(a11y)
        .accessibilityValue("\(value) sets")
    }

    private var isMonotonic: Bool {
        target.mv <= target.mev && target.mev < target.mav && target.mav < target.mrv
    }

    @MainActor
    private func resetToRPDefaults() {
        guard let slug = target.muscle?.slug else { return }
        let landmark = RPVolumeLandmarks.landmark(for: slug)
        target.mv = landmark.mv
        target.mev = landmark.mev
        target.mav = landmark.mav
        target.mrv = landmark.mrv
        target.userEdited = false
    }
}
