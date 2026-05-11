//
//  RestTimerProgressRing.swift
//  fitbod
//
//  Circular accent-color progress ring used inside the expanded
//  `RestTimerOverlay` sheet. Sweeps from 0 → full revolution as `remaining`
//  decreases toward zero. UI-SPEC accent surface #11 ("Rest timer progress
//  arc in the overlay and in the Dynamic Island expanded presentation").
//
//  Reduced-motion contract (UI-SPEC accessibility § Reduced motion):
//    When `accessibilityReduceMotion` is on, the arc snaps to discrete
//    states (the .animation modifier is nil) instead of sweeping. The
//    caller passes the environment value in; this view is otherwise pure.
//
//  Stroke style matches UI-SPEC § Asset Contract / Dynamic Island bottom
//  progress mark — 8pt lineWidth, round caps, rotated -90° so the arc
//  starts at the top (12 o'clock position).
//

import SwiftUI

/// Circular accent-color progress ring used in the expanded overlay
/// sheet. Respects `accessibilityReduceMotion` (UI-SPEC accessibility
/// contract: when on, the arc snaps to discrete states instead of
/// sweeping).
public struct RestTimerProgressRing: View {
    public let remaining: TimeInterval
    public let target: Double
    public let reduceMotion: Bool

    public init(remaining: TimeInterval, target: Double, reduceMotion: Bool) {
        self.remaining = remaining
        self.target = target
        self.reduceMotion = reduceMotion
    }

    public var body: some View {
        let total = max(1, target)
        let elapsed = max(0, total - remaining)
        let progress = min(1, elapsed / total)

        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)
        }
    }
}
