// RestTimerProgressArc.swift
// fitbod
//
// BRU brutalist progress arc — replaces the legacy RestTimerProgressRing.swift.
// Drawn with Canvas + addArc (Path) per UI-SPEC v2 line 525 + 601.
//
// Contract:
//   - Track:    full circle in Color.bruFaint, lineWidth wide.
//   - Progress: partial arc from -90° (12-o'clock) sweeping clockwise
//               in Color.bruSignal, lineWidth wide, rounded caps.
//   - Progress value: `remaining / target` — decreasing from 1 → 0.
//
// Accessibility (UI-SPEC v2 line 696):
//   When @Environment(\.accessibilityReduceMotion) is true, the displayed
//   progress snaps to discrete 25% bins (1.0 / 0.75 / 0.5 / 0.25 / 0.0)
//   instead of sweeping continuously. Never bins to 0 unless remaining is
//   truly 0, so the track never appears empty mid-countdown.
//
// UI-REVIEW Wave E item 50.

import SwiftUI

/// Canvas-drawn circular progress arc using the BRU signal + faint palette.
///
/// Replaces `RestTimerProgressRing` (deleted). Call sites must be updated
/// from `RestTimerProgressRing(remaining:target:reduceMotion:)` to
/// `RestTimerProgressArc(remaining:target:)` — this view reads
/// `accessibilityReduceMotion` from the environment directly.
///
/// - Parameters:
///   - remaining: Seconds left in the rest period (decreasing toward 0).
///   - target:    Total seconds the rest was originally set to.
///   - lineWidth: Arc stroke width in points. Default: 4.
public struct RestTimerProgressArc: View {
    public let remaining: TimeInterval
    public let target: TimeInterval
    public let lineWidth: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(remaining: TimeInterval, target: TimeInterval, lineWidth: CGFloat = 4) {
        self.remaining = remaining
        self.target = target
        self.lineWidth = lineWidth
    }

    // MARK: - Body

    public var body: some View {
        Canvas { ctx, size in
            let total = max(1, target)
            let rawProgress = min(1, max(0, remaining / total))

            // Accessibility: snap to 25% bins when reduce-motion is on.
            // Formula: round(progress * 4) / 4 — produces 0.0 / 0.25 / 0.5 / 0.75 / 1.0.
            let displayedProgress: Double = reduceMotion
                ? (round(rawProgress * 4) / 4)
                : rawProgress

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - lineWidth / 2

            // ── Track (full circle, bruFaint) ────────────────────────────
            var trackPath = Path()
            trackPath.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(0),
                endAngle: .degrees(360),
                clockwise: false
            )
            ctx.stroke(trackPath, with: .color(Color.bruFaint), lineWidth: lineWidth)

            // ── Progress arc (partial, bruSignal, starts at -90°/top) ────
            guard displayedProgress > 0 else { return }

            let endDegrees = -90 + 360 * displayedProgress
            var progressPath = Path()
            progressPath.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(-90),
                endAngle: .degrees(endDegrees),
                clockwise: false
            )
            ctx.stroke(
                progressPath,
                with: .color(Color.bruSignal),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("RestTimerProgressArc — 3 stages") {
    HStack(spacing: 24) {
        VStack(spacing: 8) {
            RestTimerProgressArc(remaining: 180, target: 180, lineWidth: 4)
                .frame(width: 64, height: 64)
            Text("100%")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
        }
        VStack(spacing: 8) {
            RestTimerProgressArc(remaining: 90, target: 180, lineWidth: 4)
                .frame(width: 64, height: 64)
            Text("50%")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
        }
        VStack(spacing: 8) {
            RestTimerProgressArc(remaining: 18, target: 180, lineWidth: 4)
                .frame(width: 64, height: 64)
            Text("10%")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
        }
    }
    .padding(24)
    .background(Color.bruPaper)
}

#Preview("RestTimerProgressArc — large (expanded sheet)") {
    ZStack {
        RestTimerProgressArc(remaining: 120, target: 180, lineWidth: 6)
            .frame(width: 200, height: 200)
        Text("2:00")
            .font(BRUFont.displayHero)
            .monospacedDigit()
            .foregroundStyle(Color.bruInk)
    }
    .padding(24)
    .background(Color.bruPaper)
}
#endif
