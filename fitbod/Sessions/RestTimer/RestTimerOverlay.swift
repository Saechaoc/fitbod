//
//  RestTimerOverlay.swift
//  fitbod
//
//  The in-app overlay rendered above the SessionLoggerView's exercise list
//  (plan 04-01). Composed of two visual states:
//
//    1. Collapsed pill — 64pt-high `.regularMaterial` capsule hovering above
//       the tab bar (UI-SPEC § Spacing exception "Rest-timer overlay height
//       when collapsed is 64pt"). Apple Music's now-playing pill is the
//       visual reference. Tap → expanded sheet.
//
//    2. Expanded `.medium`-detent sheet — exercise name subtitle, large
//       circular accent progress arc with countdown digits centered, ±15s
//       bordered buttons, "Skip" secondary text button (UI-SPEC: Skip is
//       NEVER accent — it's a `.secondaryLabel` text button). Prescribed
//       seconds footer in `.caption .secondaryLabel`.
//
//  Both render paths wrap their countdown computation in
//  `TimelineView(.periodic(from: startedAt, by: 1))` so the Date.now-derived
//  remaining value re-renders once per second (RESEARCH §6 Pattern 2 — the
//  SwiftUI-native primitive for Date-derived UI; auto-pauses when off-screen).
//
//  The view is purely READ-ONLY against the engine state — it never starts
//  the timer (`SetRow.completeAction` in plan 04-01 does that). It DOES call
//  `engine.adjust(...)` and `engine.stop()` on the ±15s / Skip controls,
//  matching SESS-04's "adjust ±15s" and "skip rest" semantics.
//
//  Accessibility:
//    - Collapsed pill is one `.combine`d element with an
//      `accessibilityAdjustableAction` so VoiceOver users can swipe up/down
//      to adjust ±15s without expanding the sheet (UI-SPEC accessibility
//      § Rest timer overlay collapsed).
//    - Expanded ±15s buttons have verbatim VoiceOver labels per UI-SPEC.
//    - The progress ring respects `accessibilityReduceMotion` — when on,
//      the arc snaps to discrete states instead of sweeping (UI-SPEC
//      accessibility § Reduced motion).
//

import SwiftUI

/// The in-app overlay rendered above the SessionLoggerView's exercise list.
/// Collapsed = 64pt pill. Tap to expand to a .medium-detent sheet with
/// ±15s / Skip controls. Pure SwiftUI; reads from a `RestTimerEngine`
/// `@Bindable` injection. The engine is the single source of truth; the
/// overlay does no Date math itself (TimelineView ticks the recompute).
public struct RestTimerOverlay: View {
    @Bindable public var engine: RestTimerEngine
    @State private var presentingExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(engine: RestTimerEngine) {
        self.engine = engine
    }

    public var body: some View {
        if engine.isRunning {
            collapsedPill
                .frame(height: 64)                                           // UI-SPEC Spacing exception
                .background(.regularMaterial)                                // glass effect
                .clipShape(.capsule)
                .padding(.horizontal, 16)                                    // UI-SPEC lg inset
                .padding(.bottom, 8)
                .onTapGesture {
                    presentingExpanded = true
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Rest timer: \(remainingAccessibility)")
                .accessibilityHint("Tap to expand controls")
                .accessibilityAdjustableAction { direction in                // UI-SPEC accessibility § overlay collapsed
                    switch direction {
                    case .increment: engine.adjust(deltaSeconds: 15)
                    case .decrement: engine.adjust(deltaSeconds: -15)
                    @unknown default: break
                    }
                }
                .sheet(isPresented: $presentingExpanded) {
                    expandedSheet
                        .presentationDetents([.medium])                      // UI-SPEC exception
                }
        } else {
            EmptyView()
        }
    }

    // MARK: - Collapsed pill

    private var collapsedPill: some View {
        TimelineView(.periodic(from: engine.startedAt ?? .now, by: 1)) { _ in
            HStack(spacing: 8) {                                             // UI-SPEC sm
                Text(formatRemaining(engine.remaining))                       // UI-SPEC verbatim: "2:14 · Rest"
                    .font(.title2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text("· Rest")                                               // UI-SPEC verbatim
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Expanded sheet

    private var expandedSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {                                            // UI-SPEC xl section spacing
                Text("Rest Timer")                                           // UI-SPEC verbatim header
                    .font(.headline)
                Text(engine.currentExerciseName)                             // UI-SPEC verbatim subtitle (snapshotted exercise name)
                    .font(.body)
                    .foregroundStyle(.secondary)

                TimelineView(.periodic(from: engine.startedAt ?? .now, by: 1)) { _ in
                    ZStack {
                        RestTimerProgressRing(
                            remaining: engine.remaining,
                            target: Double(engine.targetSeconds),
                            reduceMotion: reduceMotion
                        )
                        Text(formatRemaining(engine.remaining))               // UI-SPEC verbatim countdown
                            .font(.title2)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .frame(width: 160, height: 160)
                }

                HStack(spacing: 16) {                                        // UI-SPEC lg
                    Button {
                        engine.adjust(deltaSeconds: -15)
                    } label: {
                        Text("−15s")                                         // UI-SPEC verbatim
                            .frame(minWidth: 60, minHeight: 44)              // UI-SPEC HIG 44pt
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Subtract 15 seconds")               // UI-SPEC accessibility

                    Button {
                        engine.adjust(deltaSeconds: 15)
                    } label: {
                        Text("+15s")                                         // UI-SPEC verbatim
                            .frame(minWidth: 60, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Add 15 seconds")
                }

                Button("Skip") {                                             // UI-SPEC verbatim "Skip" text button
                    engine.stop()
                    presentingExpanded = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)                                 // UI-SPEC: Skip is secondary
                .accessibilityLabel("Skip remaining rest")

                if engine.targetSeconds > 0 {
                    Text("Prescribed: \(engine.targetSeconds)s")             // UI-SPEC verbatim footer
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
    }

    // MARK: - Helpers

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private var remainingAccessibility: String {
        let s = max(0, Int(engine.remaining))
        if s >= 60 { return "\(s / 60) minutes \(s % 60) seconds" }
        return "\(s) seconds"
    }
}
