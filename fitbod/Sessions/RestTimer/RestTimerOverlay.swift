//
//  RestTimerOverlay.swift
//  fitbod
//
//  Chalkline rest-timer UI (milestone 1 redesign of the plan 04-01 pill):
//
//    1. `RestTimerDock` — an iron panel docked above the home indicator
//       (`.safeAreaInset(edge: .bottom)` on the workout list), always within
//       thumb reach: big countdown, accent progress bar, −15 / +15 / Skip.
//       Past zero it flips to "REST DONE +0:18" (accent-on-panel) and a
//       success haptic fires once.
//    2. `RestTimerSheet` — tap the countdown for a larger readout, the
//       absolute end time, and presets (1:00 … 5:00).
//
//  Both read a `RestTimerEngine` and never do Date math of their own:
//  `TimelineView(.periodic(from:by: 1))` just re-renders once per second
//  and the engine computes `remaining` from its absolute deadline, so
//  backgrounding or relaunching cannot reset the countdown.
//
//  Accessibility: the countdown is one adjustable element (swipe up/down
//  = ±15 s) whose value reads as words ("1 minute 42 seconds left");
//  buttons have explicit labels; the progress bar is decorative; Reduce
//  Motion removes the bar animation.
//

import SwiftUI

public struct RestTimerDock: View {
    @Bindable public var engine: RestTimerEngine
    @State private var presentingSheet = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var countdownSize: CGFloat = 40

    public init(engine: RestTimerEngine) {
        self.engine = engine
    }

    public var body: some View {
        if engine.isRunning {
            TimelineView(.periodic(from: engine.startedAt ?? .now, by: 1)) { _ in
                dockContent(done: engine.isOvertime)
            }
            .padding(.horizontal, Chalk.Space.md)
            .padding(.bottom, Chalk.Space.xs)
            .transition(reduceMotion ? AnyTransition.opacity : AnyTransition.move(edge: .bottom).combined(with: .opacity))
            .sheet(isPresented: $presentingSheet) {
                RestTimerSheet(engine: engine)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Color.chalkPanel)
            }
        }
    }

    @ViewBuilder
    private func dockContent(done: Bool) -> some View {
        ChalkPanel(padding: Chalk.Space.md, radius: Chalk.Radius.xl) {
            VStack(alignment: .leading, spacing: Chalk.Space.sm) {
                if dynamicTypeSize.isAccessibilitySize {
                    countdown(done: done)
                    controls(done: done)
                } else {
                    HStack(alignment: .center, spacing: Chalk.Space.md) {
                        countdown(done: done)
                        Spacer(minLength: 0)
                        controls(done: done)
                    }
                }
                ChalkProgressBar(progress: engine.progress)
                    .animation(reduceMotion ? nil : .linear(duration: 1), value: engine.progress)
            }
        }
        .sensoryFeedback(.success, trigger: done) { old, new in new && !old }
        .accessibilityIdentifier("rest.dock")
    }

    private func countdown(done: Bool) -> some View {
        let title: String = done ? "Rest done" : "Rest timer"
        let overline: String = done ? "Rest done" : headline
        return Button {
            presentingSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(overline)
                    .chalkLabelStyle(color: done ? .chalkAccentOnPanel : .chalkOnPanel2)
                    .lineLimit(1)
                Text(RestTimerText.clock(engine.remaining))
                    .font(.system(size: countdownSize, weight: .heavy).width(.condensed).monospacedDigit())
                    .foregroundStyle(done ? Color.chalkAccentOnPanel : Color.chalkOnPanel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(minHeight: Chalk.Size.minTouch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("rest.remaining")
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(RestTimerText.spoken(engine.remaining)))
        .accessibilityHint(Text("Double-tap for presets. Swipe up or down to change by 15 seconds."))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: engine.adjust(deltaSeconds: 15)
            case .decrement: engine.adjust(deltaSeconds: -15)
            @unknown default: break
            }
        }
    }

    private func controls(done: Bool) -> some View {
        let finishTitle: String = done ? "Done" : "Skip"
        let finishLabel: String = done ? "Dismiss rest timer" : "Skip remaining rest"
        return HStack(spacing: Chalk.Space.sm) {
            Button("−15") { engine.adjust(deltaSeconds: -15) }
                .buttonStyle(.chalk(.onPanel, size: .compact))
                .accessibilityLabel("Subtract 15 seconds")
                .accessibilityIdentifier("rest.minus15")
            Button("+15") { engine.adjust(deltaSeconds: 15) }
                .buttonStyle(.chalk(.onPanel, size: .compact))
                .accessibilityLabel("Add 15 seconds")
                .accessibilityIdentifier("rest.plus15")
            Button(finishTitle) { engine.stop() }
                .buttonStyle(.chalk(.primary, size: .compact))
                .accessibilityLabel(Text(finishLabel))
                .accessibilityIdentifier("rest.skip")
        }
        .fixedSize()
    }

    private var headline: String {
        engine.currentExerciseName.isEmpty ? "Rest" : "Rest · \(engine.currentExerciseName)"
    }
}

/// Expanded rest controls: large countdown, end time, presets.
public struct RestTimerSheet: View {
    @Bindable public var engine: RestTimerEngine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var bigSize: CGFloat = 88

    private let presets = [60, 90, 120, 150, 180, 300]

    private var sheetFinishTitle: String { engine.isOvertime ? "Done" : "Skip" }
    private var sheetFinishLabel: String { engine.isOvertime ? "Dismiss rest timer" : "Skip remaining rest" }

    public init(engine: RestTimerEngine) {
        self.engine = engine
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                TimelineView(.periodic(from: engine.startedAt ?? .now, by: 1)) { _ in
                    VStack(alignment: .leading, spacing: Chalk.Space.xl) {
                        VStack(alignment: .leading, spacing: Chalk.Space.xs) {
                            if !engine.currentExerciseName.isEmpty {
                                Text(engine.currentExerciseName)
                                    .font(.chalkCallout)
                                    .foregroundStyle(.chalkOnPanel2)
                            }
                            Text(engine.isRunning ? RestTimerText.clock(engine.remaining) : "0:00")
                                .font(.system(size: bigSize, weight: .heavy).width(.condensed).monospacedDigit())
                                .foregroundStyle(engine.isOvertime ? Color.chalkAccentOnPanel : Color.chalkOnPanel)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .accessibilityLabel(Text("Rest remaining"))
                                .accessibilityValue(Text(RestTimerText.spoken(engine.remaining)))
                            ChalkProgressBar(progress: engine.progress)
                                .animation(reduceMotion ? nil : .linear(duration: 1), value: engine.progress)
                            if let deadline = engine.deadline {
                                Text("Total \(ChalkFormat.duration(seconds: engine.targetSeconds)) · ends \(deadline.formatted(date: .omitted, time: .shortened))")
                                    .font(.chalkFootnote)
                                    .foregroundStyle(.chalkOnPanel2)
                            }
                        }

                        VStack(alignment: .leading, spacing: Chalk.Space.sm) {
                            Text("Total rest").chalkLabelStyle(color: .chalkOnPanel2)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: Chalk.Space.sm)], spacing: Chalk.Space.sm) {
                                ForEach(presets, id: \.self) { seconds in
                                    Button(ChalkFormat.duration(seconds: seconds)) {
                                        engine.setTarget(seconds: seconds)
                                    }
                                    .buttonStyle(.chalk(.onPanel, size: .compact, fullWidth: true))
                                    .overlay {
                                        if engine.targetSeconds == seconds {
                                            RoundedRectangle(cornerRadius: Chalk.Radius.md, style: .continuous)
                                                .strokeBorder(Color.chalkOnPanel, lineWidth: Chalk.Line.strong)
                                        }
                                    }
                                    .accessibilityLabel(Text("Set total rest to \(RestTimerText.spoken(TimeInterval(seconds)))"))
                                    .accessibilityAddTraits(engine.targetSeconds == seconds ? .isSelected : [])
                                }
                            }
                        }

                        HStack(spacing: Chalk.Space.sm) {
                            Button("−15 s") { engine.adjust(deltaSeconds: -15) }
                                .buttonStyle(.chalk(.onPanel, size: .large, fullWidth: true))
                                .accessibilityLabel("Subtract 15 seconds")
                            Button("+15 s") { engine.adjust(deltaSeconds: 15) }
                                .buttonStyle(.chalk(.onPanel, size: .large, fullWidth: true))
                                .accessibilityLabel("Add 15 seconds")
                            Button(sheetFinishTitle) {
                                engine.stop()
                                dismiss()
                            }
                            .buttonStyle(.chalk(.primary, size: .large, fullWidth: true))
                            .accessibilityLabel(Text(sheetFinishLabel))
                        }
                    }
                    .padding(Chalk.Space.xl)
                }
            }
            .background(Color.chalkPanel)
            .navigationTitle("REST TIMER")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onChange(of: engine.isRunning) { _, running in
            if !running { dismiss() }
        }
    }
}

/// Countdown text helpers shared by the dock, the sheet, and Today.
public enum RestTimerText {
    /// "1:42" while counting down, "+0:18" in overtime.
    public static func clock(_ remaining: TimeInterval) -> String {
        if remaining >= 0 {
            return ChalkFormat.duration(seconds: Int(remaining.rounded(.up)))
        }
        return "+" + ChalkFormat.duration(seconds: Int((-remaining).rounded(.down)))
    }

    /// "1 minute 42 seconds left" / "18 seconds over".
    public static func spoken(_ remaining: TimeInterval) -> String {
        let over = remaining < 0
        let total = over ? Int((-remaining).rounded(.down)) : Int(remaining.rounded(.up))
        let minutes = total / 60
        let seconds = total % 60
        var parts: [String] = []
        if minutes > 0 { parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")") }
        if seconds > 0 || minutes == 0 { parts.append("\(seconds) second\(seconds == 1 ? "" : "s")") }
        return parts.joined(separator: " ") + (over ? " over" : " left")
    }
}

#Preview("Rest dock") {
    let engine = RestTimerEngine(scheduler: NoopNotificationScheduler())
    engine.start(seconds: 180, exerciseName: "Barbell Bench Press - Medium Grip")
    return VStack {
        Spacer()
        RestTimerDock(engine: engine)
    }
    .background(Color.chalkCanvas)
}
