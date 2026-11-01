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
//   1. BOTTOM DOCK (full-bleed) — mounted by SessionLoggerView with
//      .safeAreaInset(edge: .bottom), so it sits above the home indicator
//      and within thumb reach for one-handed use.
//      Background: Color.bruBg2. Top border: 2pt Color.bruInk.
//      Row 1: 40pt RestTimerProgressArc with "REST" inside it (dropped at
//             accessibility sizes) + status + exercise name +
//             countdown displayMedium + "▸" (tap row to expand).
//      Row 2: −15s / +15s / SKIP, each a 44pt-tall outlined rectangle.
//      When the countdown reaches zero the dock flips to "REST COMPLETE"
//      with the overrun in bruSignal and SKIP becomes DONE.
//      NO Capsule, NO RoundedRectangle, NO .regularMaterial.
//
//   2. EXPANDED sheet (opens at its content's height, drags to full
//      height) — BRUHeaderBar "REST TIMER" top, exercise name displayLarge,
//      200×200 RestTimerProgressArc + displayHero countdown, ±15s
//      ink-outlined rectangle buttons, BRUButton(.ghost) SKIP,
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
/// Bottom dock: a full-bleed `bruBg2` panel with a 2pt `bruInk` top
/// border carrying the countdown and the −15s / +15s / SKIP controls.
/// Tap the countdown row to expand to a sheet that opens at its content's
/// height. Reads from a `RestTimerEngine` `@Bindable` injection; the
/// engine is the single source of truth.
public struct RestTimerOverlay: View {
    @Bindable public var engine: RestTimerEngine
    @State private var presentingExpanded = false
    /// The expanded sheet's header and scroll content heights, measured as
    /// the sheet lays out. The content's is nil until it has been measured.
    @State private var sheetHeaderHeight: CGFloat = 0
    @State private var sheetContentHeight: CGFloat?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(engine: RestTimerEngine) {
        self.engine = engine
    }

    public var body: some View {
        if engine.isRunning {
            bottomDock
                .sheet(isPresented: $presentingExpanded) {
                    expandedSheet
                        .presentationDetents(expandedDetents)
                }
                .transition(.move(edge: .bottom))
        } else {
            EmptyView()
        }
    }

    /// The sheet first opens at the height of its content, so every
    /// control, SKIP included, shows without a drag, and still drags up to
    /// full height. Until the content is measured it opens at half height.
    /// At accessibility sizes the content outgrows the screen, so the sheet
    /// opens at full height.
    private var expandedDetents: Set<PresentationDetent> {
        guard !dynamicTypeSize.isAccessibilitySize else { return [.large] }
        guard let sheetContentHeight else { return [.medium, .large] }
        return [.height((sheetHeaderHeight + sheetContentHeight).rounded(.up)), .large]
    }

    // MARK: - Bottom dock

    /// Full-bleed `bruBg2` dock with a 2pt `bruInk` top border.
    private var bottomDock: some View {
        TimelineView(.periodic(from: engine.startedAt ?? .now, by: 1)) { _ in
            let finished = engine.isFinished
            VStack(spacing: 10) {
                // Row 1 — status + countdown. Tap to expand.
                HStack(spacing: 12) {
                    ZStack {
                        RestTimerProgressArc(
                            remaining: engine.remaining,
                            target: Double(engine.targetSeconds),
                            lineWidth: 3
                        )
                        .frame(width: 40, height: 40)

                        // At accessibility sizes REST outgrows the ring, and
                        // RESTING beside it says the same, so the ring drops it.
                        if !dynamicTypeSize.isAccessibilitySize {
                            Text("REST")
                                .font(BRUFont.labelMicro)
                                .tracking(1.5)
                                .textCase(.uppercase)
                                .foregroundStyle(Color.bruInk)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .frame(maxWidth: Self.ringLabelWidth)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(finished ? "REST COMPLETE" : "RESTING")
                            .font(BRUFont.labelSmall)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(finished ? Color.bruSignalText : Color.bruMuted)
                        Text(engine.currentExerciseName)
                            .font(BRUFont.bodyEmphasis)
                            .foregroundStyle(Color.bruInk)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer(minLength: 8)

                    Text(finished ? formatOverrun(engine.remaining) : formatRemaining(engine.remaining))
                        .font(BRUFont.displayMedium)
                        .monospacedDigit()
                        .foregroundStyle(finished ? Color.bruSignalText : Color.bruInk)

                    Text("▸")
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruMuted)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .onTapGesture {
                    presentingExpanded = true
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("rest.status")
                .accessibilityLabel("Rest timer: \(remainingAccessibility)")
                .accessibilityHint("Tap to expand controls")
                .accessibilityAddTraits(.isButton)
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: engine.adjust(deltaSeconds: 15)
                    case .decrement: engine.adjust(deltaSeconds: -15)
                    @unknown default: break
                    }
                }

                // Row 2 — one-handed controls, each 44pt tall.
                HStack(spacing: 8) {
                    dockButton("−15s", accessibility: "Subtract 15 seconds", identifier: "rest.minus15") {
                        engine.adjust(deltaSeconds: -15)
                    }
                    dockButton("+15s", accessibility: "Add 15 seconds", identifier: "rest.plus15") {
                        engine.adjust(deltaSeconds: 15)
                    }
                    dockButton(
                        finished ? "DONE" : "SKIP",
                        accessibility: finished ? "Dismiss rest timer" : "Skip remaining rest",
                        identifier: "rest.skip",
                        isSignal: true
                    ) {
                        withAnimation(.easeOut(duration: 0.2)) { engine.stop() }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .background(Color.bruBg2.ignoresSafeArea(edges: .bottom))
        // 2pt bruInk top border — the dock sits under the list content.
        .overlay(
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2),
            alignment: .top
        )
    }

    /// The widest the dock's REST label gets: the 40pt ring's inside, less
    /// its 3pt stroke and a 2pt margin on each side. Larger text shrinks to
    /// fit.
    private static let ringLabelWidth: CGFloat = 30

    /// Equal-width outlined rectangle control for the dock.
    private func dockButton(
        _ title: String,
        accessibility: String,
        identifier: String,
        isSignal: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                // No textCase: "−15s" must not render as "−15S".
                .foregroundStyle(isSignal ? Color.bruPaper : Color.bruInk)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isSignal ? Color.bruInk : Color.bruPaper)
                .overlay(
                    Rectangle()
                        .stroke(Color.bruInk, lineWidth: 1.5)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Expanded sheet

    /// iOS 26 draws a sheet below full height scaled down to its inset
    /// width (386 of 402pt on an iPhone 17 Pro), so a 44pt control renders
    /// at about 42pt. The controls a lifter hits mid-rest get 52pt, which
    /// stays above 44pt at either detent.
    private static let sheetControlHeight: CGFloat = 52

    /// Content-height sheet with BRU header, exercise name, 200pt arc,
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
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sheetHeaderHeight = $0 }

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

                            Text(engine.isFinished ? formatOverrun(engine.remaining) : formatRemaining(engine.remaining))
                                .font(BRUFont.displayHero)
                                .monospacedDigit()
                                .foregroundStyle(Color.bruInk)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .frame(width: 180)
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
                                .foregroundStyle(Color.bruInk)
                                .frame(minWidth: 80, minHeight: Self.sheetControlHeight)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.bruInk, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Subtract 15 seconds")
                        .accessibilityIdentifier("rest.expanded.minus15")

                        Button {
                            engine.adjust(deltaSeconds: 15)
                        } label: {
                            Text("+15s")
                                .font(BRUFont.labelSmall)
                                .tracking(1.2)
                                .foregroundStyle(Color.bruInk)
                                .frame(minWidth: 80, minHeight: Self.sheetControlHeight)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.bruInk, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add 15 seconds")
                        .accessibilityIdentifier("rest.expanded.plus15")
                    }

                    // SKIP ghost button
                    BRUButton(engine.isFinished ? "DONE" : "SKIP", kind: .ghost, size: .lg) {
                        presentingExpanded = false
                        engine.stop()
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
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sheetContentHeight = $0 }
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())
    }

    // MARK: - Helpers

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Overrun after the countdown hits zero: "+0:12". Past an hour (a
    /// rest restored long after it ended) the counter is meaningless, so
    /// it reads "0:00".
    private func formatOverrun(_ remaining: TimeInterval) -> String {
        let over = Int(-remaining)
        guard over > 0, over < 3600 else { return "0:00" }
        return String(format: "+%d:%02d", over / 60, over % 60)
    }

    private var remainingAccessibility: String {
        if engine.isFinished { return "rest complete" }
        let s = max(0, Int(engine.remaining))
        if s >= 60 { return "\(s / 60) minutes \(s % 60) seconds" }
        return "\(s) seconds"
    }
}
