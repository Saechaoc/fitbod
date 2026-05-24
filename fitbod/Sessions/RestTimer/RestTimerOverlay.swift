// RestTimerOverlay.swift
// fitbod
//
// BRU brutalist rest-timer overlay — rewritten for Phase 2.1 (UI-REVIEW
// Wave E items 49-54). The legacy `.regularMaterial` capsule pill is
// replaced with the full-bleed ink-slab pattern mandated by UI-SPEC v2
// lines 366-411.
//
// Two visual states:
//
//   1. COLLAPSED slab (64pt, full-bleed) — anchored above the BRUTabBar.
//      Background: Color.bruBg2. Bottom border: 2pt Color.bruInk.
//      Contents: 32pt RestTimerProgressArc + "REST" labelSmall + countdown
//      displayMedium + "▸" chevron.
//      NO Capsule, NO RoundedRectangle, NO .regularMaterial, NO padding
//      around the slab itself.
//
//   2. EXPANDED sheet (.medium detent) — BRUHeaderBar "REST TIMER" top,
//      exercise name displayLarge, 200×200 RestTimerProgressArc + displayHero
//      countdown, ±15s ink-outlined rectangle buttons, BRUButton(.ghost) SKIP,
//      "PRESCRIBED · {N}S" labelSmall muted footer.
//
// Behavior layer (RestTimerEngine + RestTimerActivityController +
// RestTimerNotificationScheduler) is PRESERVED VERBATIM per UI-SPEC line 736.
//
// Accessibility:
//   - Collapsed slab: one .combine element with .accessibilityAdjustableAction
//     for VoiceOver ±15s swipe (UI-SPEC accessibility § overlay collapsed).
//   - Expanded ±15s buttons carry verbatim VoiceOver labels.
//   - RestTimerProgressArc respects @Environment(\.accessibilityReduceMotion)
//     internally (arc snaps to 25% bins when on — UI-SPEC line 696).
//
// UI-REVIEW Wave E item 49 (overlay slab) + item 50 (progress arc).

import SwiftUI

/// BRU brutalist rest-timer overlay.
///
/// Collapsed state: a 64pt full-bleed `bruBg2` slab with a 2pt `bruInk`
/// bottom border. Tap to expand to a `.medium`-detent sheet with full
/// BRU controls. Reads from a `RestTimerEngine` `@Bindable` injection;
/// the engine is the single source of truth.
public struct RestTimerOverlay: View {
    @Bindable public var engine: RestTimerEngine
    @State private var presentingExpanded = false

    public init(engine: RestTimerEngine) {
        self.engine = engine
    }

    public var body: some View {
        if engine.isRunning {
            collapsedSlab
                .onTapGesture {
                    presentingExpanded = true
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Rest timer: \(remainingAccessibility)")
                .accessibilityHint("Tap to expand controls")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: engine.adjust(deltaSeconds: 15)
                    case .decrement: engine.adjust(deltaSeconds: -15)
                    @unknown default: break
                    }
                }
                .sheet(isPresented: $presentingExpanded) {
                    expandedSheet
                        .presentationDetents([.medium])
                }
        } else {
            EmptyView()
        }
    }

    // MARK: - Collapsed slab

    /// Full-bleed 64pt `bruBg2` slab with 2pt `bruInk` bottom border.
    /// UI-SPEC v2 lines 366-369 + 401.
    private var collapsedSlab: some View {
        TimelineView(.periodic(from: engine.startedAt ?? .now, by: 1)) { _ in
            HStack(spacing: 12) {
                // Progress arc + "REST" label
                ZStack {
                    RestTimerProgressArc(
                        remaining: engine.remaining,
                        target: Double(engine.targetSeconds),
                        lineWidth: 3
                    )
                    .frame(width: 32, height: 32)

                    Text("REST")
                        .font(BRUFont.labelMicro)
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruInk)
                }

                Spacer()

                // Countdown digits
                Text(formatRemaining(engine.remaining))
                    .font(BRUFont.displayMedium)
                    .monospacedDigit()
                    .foregroundStyle(Color.bruInk)

                // Expand chevron
                Text("▸")
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        // FULL BLEED — 64pt tall, max width, no horizontal clipping
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .background(Color.bruBg2)
        // 2pt bruInk bottom border per UI-SPEC line 82 + 401
        .overlay(
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2),
            alignment: .bottom
        )
        // NO .clipShape, NO .padding(.horizontal) around the slab
        .contentShape(Rectangle())
    }

    // MARK: - Expanded sheet

    /// `.medium`-detent sheet with BRU header, exercise name, 200pt arc,
    /// ±15s outlined-rectangle buttons, ghost SKIP, and muted footer.
    /// UI-SPEC v2 lines 402-408.
    private var expandedSheet: some View {
        VStack(spacing: 0) {
            BRUHeaderBar(
                left: nil,
                center: "REST TIMER",
                right: HeaderAction("DONE", isSignal: false) {
                    presentingExpanded = false
                }
            )

            ScrollView {
                VStack(spacing: 24) {
                    // Exercise name — displayLarge
                    Text(engine.currentExerciseName)
                        .font(BRUFont.displayLarge)
                        .tracking(-0.3)
                        .foregroundStyle(Color.bruInk)
                        .multilineTextAlignment(.center)

                    // Progress arc + countdown hero
                    TimelineView(.periodic(from: engine.startedAt ?? .now, by: 1)) { _ in
                        ZStack {
                            RestTimerProgressArc(
                                remaining: engine.remaining,
                                target: Double(engine.targetSeconds),
                                lineWidth: 6
                            )
                            .frame(width: 200, height: 200)

                            Text(formatRemaining(engine.remaining))
                                .font(BRUFont.displayHero)
                                .monospacedDigit()
                                .foregroundStyle(Color.bruInk)
                        }
                    }

                    // ±15s buttons — ink-outlined rectangles (NOT rounded)
                    HStack(spacing: 12) {
                        Button {
                            engine.adjust(deltaSeconds: -15)
                        } label: {
                            Text("−15s")
                                .font(BRUFont.labelSmall)
                                .tracking(1.2)
                                .textCase(.uppercase)
                                .foregroundStyle(Color.bruInk)
                                .frame(minWidth: 80, minHeight: 44)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.bruInk, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Subtract 15 seconds")

                        Button {
                            engine.adjust(deltaSeconds: 15)
                        } label: {
                            Text("+15s")
                                .font(BRUFont.labelSmall)
                                .tracking(1.2)
                                .textCase(.uppercase)
                                .foregroundStyle(Color.bruInk)
                                .frame(minWidth: 80, minHeight: 44)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.bruInk, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add 15 seconds")
                    }

                    // SKIP ghost button
                    BRUButton("SKIP", kind: .ghost, size: .md) {
                        engine.stop()
                        presentingExpanded = false
                    }
                    .accessibilityLabel("Skip remaining rest")

                    // Prescribed footer
                    if engine.targetSeconds > 0 {
                        Text("PRESCRIBED · \(engine.targetSeconds)S")
                            .font(BRUFont.labelSmall)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.bruMuted)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())
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
