// RestTimerDynamicIslandExpandedView.swift
// FitbodWidgets
//
// BRU brutalist Dynamic Island expanded presentation view.
// Per UI-SPEC v2 lines 413-417 + 570.
//
// Layout (top to bottom):
//   - Exercise name in labelSmall 10pt bruPaper (UPPERCASE via .textCase)
//   - Countdown digits in displayHero 56pt bruPaper
//   - 4pt-tall progress bar: bruFaint track + bruSignal fill scaled by `progress`
//
// Background: the Dynamic Island expanded presentation uses the system
// background (bruInk activityBackgroundTint set on the Live Activity container).
// Text colors are bruPaper (paper-on-ink contract, UI-SPEC line 384).
//
// UI-REVIEW Wave E item 53 (expanded Dynamic Island).

import SwiftUI

/// Dynamic Island expanded center view: exercise name + countdown + signal progress bar.
///
/// Mounted in `DynamicIslandExpandedRegion(.center)` inside
/// `RestTimerLiveActivity`. The `progress` parameter is 0.0 (complete)
/// to 1.0 (full rest remaining) — caller computes `remaining / target`.
public struct RestTimerDynamicIslandExpandedView: View {
    public let exerciseName: String
    public let countdownText: String
    /// Progress value: 0.0 (complete) → 1.0 (full rest remaining).
    public let progress: Double

    public init(exerciseName: String, countdownText: String, progress: Double) {
        self.exerciseName = exerciseName
        self.countdownText = countdownText
        self.progress = progress
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Exercise name — labelSmall bruPaper
            Text(exerciseName)
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruPaper)
                .lineLimit(1)
                .truncationMode(.tail)

            // Countdown hero — displayHero 56pt bruPaper
            Text(countdownText)
                .font(BRUFont.displayHero)
                .monospacedDigit()
                .foregroundStyle(Color.bruPaper)

            // Signal progress bar — 4pt tall
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Rectangle()
                        .fill(Color.bruFaint)
                        .frame(height: 4)
                    // Fill (scaled by progress)
                    Rectangle()
                        .fill(Color.bruSignal)
                        .frame(width: geo.size.width * min(1, max(0, progress)), height: 4)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Expanded Dynamic Island — 2:30 remaining (83%)") {
    RestTimerDynamicIslandExpandedView(
        exerciseName: "Bench Press",
        countdownText: "2:30",
        progress: 0.83
    )
    .padding(16)
    .background(Color.bruInk)  // paper-on-ink hero
}

#Preview("Expanded Dynamic Island — 0:15 remaining (8%)") {
    RestTimerDynamicIslandExpandedView(
        exerciseName: "Romanian Deadlift",
        countdownText: "0:15",
        progress: 0.08
    )
    .padding(16)
    .background(Color.bruInk)
}
#endif
