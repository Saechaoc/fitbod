//
//  MuscleVolumeTargetStepper.swift
//  fitbod
//
//  Phase 5.1-01 Task 3 — BRU reskin of the inline MV/MEV/MAV/MRV editor.
//
//  Public init unchanged: `(target: MuscleVolumeTarget, showsResetButton: Bool = true)`
//  Consumed by PerMuscleDetailView (plan 05.1-06) and MuscleVolumeTargetEditor (plan 05.1-06).
//
//  BRU changes:
//    - Validation error: Color(.systemRed) → .bruSignal, font → BRUFont.labelMicro
//    - Reset button: Button+accentColor → BRUButton("Reset to RP defaults", kind: .primary)
//    - Suffix line: BRUFont.labelMicro bruMuted set count + suffix
//    - Row label Text uses .foregroundStyle(.bruInk) / .bruMuted (no system colors)
//    - T109: each target is a BRUStepper titled MV, MEV, MAV or MRV, with
//      44pt − and + cells, over its suffix line, replacing the stock iOS
//      Stepper and the labelSmall uppercase title
//
//  Preserved verbatim:
//    - 4-stepper MV/MEV/MAV/MRV with range 1...30, step 1
//    - Per-stepper accessibilityLabel + accessibilityValue, now on one
//      adjustable element per target (the stock rows repeated them on
//      both lines of text and on the stepper)
//    - Monotonic invariant check: mv ≤ mev < mav < mrv
//    - resetToRPDefaults() calls RPVolumeLandmarks.landmark(for:)
//    - userEdited = true on any Stepper edit
//    - showsResetButton conditional
//
//  BRU contract — ZERO banned tokens:
//    No Color.accentColor, Color(.system*), .font(.body|.caption|.footnote|
//    .headline|.subheadline)
//
//  Verbatim copy (locked, tested in MuscleVolumeTargetStepperBRUTests),
//  after the set count, which BRUCountLabel writes ("1 set", "6 sets"):
//    mvSuffix:           "— maintenance"
//    mevSuffix:          "— min for growth"
//    mavSuffix:          "— peak adaptive"
//    mrvSuffix:          "— max recoverable"
//    monotonicErrorCopy: "Targets must be in order: MV ≤ MEV < MAV < MRV."
//

import SwiftUI

public struct MuscleVolumeTargetStepper: View {

    @Bindable public var target: MuscleVolumeTarget
    public var showsResetButton: Bool

    // MARK: - Verbatim copy constants (internal for testability)

    /// Verbatim stepper suffix, per the UI-SPEC §MuscleVolumeTargetStepper
    /// table, after the set count.
    static let mvSuffix: String  = "— maintenance"
    static let mevSuffix: String = "— min for growth"
    static let mavSuffix: String = "— peak adaptive"
    static let mrvSuffix: String = "— max recoverable"

    /// Verbatim monotonic validation error — UI-SPEC §Copywriting Contract.
    static let monotonicErrorCopy: String = "Targets must be in order: MV ≤ MEV < MAV < MRV."

    // MARK: - Init

    public init(target: MuscleVolumeTarget, showsResetButton: Bool = true) {
        self.target = target
        self.showsResetButton = showsResetButton
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 12) {
            stepperRow(
                label: "MV",
                suffix: Self.mvSuffix,
                value: target.mv,
                onChange: { newValue in
                    target.mv = newValue
                    target.userEdited = true
                },
                a11yLabel: "Maintenance volume for \(target.muscle?.displayName ?? "muscle")"
            )
            stepperRow(
                label: "MEV",
                suffix: Self.mevSuffix,
                value: target.mev,
                onChange: { newValue in
                    target.mev = newValue
                    target.userEdited = true
                },
                a11yLabel: "Minimum effective volume for \(target.muscle?.displayName ?? "muscle")"
            )
            stepperRow(
                label: "MAV",
                suffix: Self.mavSuffix,
                value: target.mav,
                onChange: { newValue in
                    target.mav = newValue
                    target.userEdited = true
                },
                a11yLabel: "Maximum adaptive volume for \(target.muscle?.displayName ?? "muscle")"
            )
            stepperRow(
                label: "MRV",
                suffix: Self.mrvSuffix,
                value: target.mrv,
                onChange: { newValue in
                    target.mrv = newValue
                    target.userEdited = true
                },
                a11yLabel: "Maximum recoverable volume for \(target.muscle?.displayName ?? "muscle")"
            )

            if !isMonotonic {
                Text(Self.monotonicErrorCopy)
                    .font(BRUFont.labelMicro)
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruSignal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if showsResetButton {
                BRUButton("Reset to RP defaults", kind: .primary) {
                    resetToRPDefaults()
                }
            }
        }
    }

    // MARK: - Stepper row

    /// Every target runs from 1 to 30 sets, a set at a time.
    private static let range = 1...30

    /// One target: a BRUStepper titled MV, MEV, MAV or MRV, with its set
    /// count and suffix under it. VoiceOver reads the two as one adjustable
    /// element, by the target's full name and its set count.
    @ViewBuilder
    private func stepperRow(
        label: String,
        suffix: String,
        value: Int,
        onChange: @escaping (Int) -> Void,
        a11yLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            BRUStepper(
                label,
                value: Binding(get: { value }, set: { onChange($0) }),
                in: Self.range,
                step: 1
            ) { "\($0)" }
            Text("\(BRUCountLabel.text(value, "set")) \(suffix)")
                .font(BRUFont.labelMicro)
                .tracking(1.0)
                .foregroundStyle(Color.bruMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        // The stepper's own element would read "MV" and a bare number, so
        // the row takes its place and steps the same way.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11yLabel)
        .accessibilityValue(BRUCountLabel.text(value, "set"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment where value < Self.range.upperBound: onChange(value + 1)
            case .decrement where value > Self.range.lowerBound: onChange(value - 1)
            default: break
            }
        }
    }

    // MARK: - Monotonic check

    private var isMonotonic: Bool {
        target.mv <= target.mev && target.mev < target.mav && target.mav < target.mrv
    }

    // MARK: - Reset helper (internal static for testability)

    /// Writes RP landmark values onto `target` and clears the userEdited flag.
    /// Exposed as `static` + `internal` so `MuscleVolumeTargetStepperBRUTests`
    /// can call it without a live SwiftUI view.
    @MainActor
    static func applyRPDefaults(to target: MuscleVolumeTarget) {
        guard let slug = target.muscle?.slug else { return }
        let landmark = RPVolumeLandmarks.landmark(for: slug)
        target.mv = landmark.mv
        target.mev = landmark.mev
        target.mav = landmark.mav
        target.mrv = landmark.mrv
        target.userEdited = false
    }

    @MainActor
    private func resetToRPDefaults() {
        Self.applyRPDefaults(to: target)
    }
}
