// SessionDetailView.swift
// fitbod
//
// Workout summary for one logged Session. Two entry points share it:
//
//   1. Post-Finish: SessionLoggerView presents it full-screen with an
//      `onDone` closure. The header shows "DONE" and a full-width DONE
//      button sits at the bottom; tapping either returns to Today.
//   2. History: push `SessionDetailView(session:)` onto a NavigationStack.
//      With no `onDone`, the header shows the "‹" back glyph instead.
//
// Content (all read from logged rows via SessionSummary, never from the
// template): name + date, a DURATION / SETS / VOLUME stat strip, a PR band
// when any PR landed, then one row per exercise with its working-set
// count, volume, best set and PR kinds.
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor
//               NO Image(systemName:) / NO .font(.body/.headline/.title/.caption)
//               NO .buttonStyle(.bordered) / NO Color(.system*)

import SwiftUI
import SwiftData

public struct SessionDetailView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [UserSettings]

    public let session: Session
    private let onDone: (() -> Void)?

    @State private var summary: SessionSummary?

    /// History entry point: push onto a NavigationStack.
    public init(session: Session) {
        self.session = session
        self.onDone = nil
    }

    /// Post-Finish entry point: `onDone` runs for the DONE actions.
    public init(session: Session, onDone: @escaping () -> Void) {
        self.session = session
        self.onDone = onDone
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                titleBlock
                BRUDivider(.ink)
                if let summary {
                    statStrip(summary)
                    BRUDivider(.ink)
                    if summary.prExerciseCount > 0 {
                        prBand(summary)
                    }
                    BRUSectionHead("Exercises", right: "\(summary.exercises.count)")
                    ForEach(summary.exercises) { line in
                        exerciseRow(line)
                        BRUDivider(.hair)
                    }
                    if let notes = session.notes, !notes.isEmpty {
                        notesBlock(notes)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top, spacing: 0) {
            BRUHeaderBar(
                left: onDone == nil ? HeaderAction("‹") { dismiss() } : nil,
                center: "Summary",
                right: onDone.map { done in HeaderAction("DONE", isSignal: true) { done() } }
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let onDone {
                BRUButton("Done", kind: .primary, size: .lg) { onDone() }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.bruPaper)
                    .overlay(Rectangle().fill(Color.bruInk).frame(height: 2), alignment: .top)
            }
        }
        .task(id: session.id) {
            summary = SessionSummary.make(session: session, context: ctx)
        }
    }

    // MARK: - Sections

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.completedAt == nil ? "IN PROGRESS" : "WORKOUT COMPLETE")
                .font(BRUFont.labelSmall)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(session.completedAt == nil ? Color.bruMuted : Color.bruSignal)
            Text(displayName)
                .font(BRUFont.displayLarge)
                .tracking(-0.3)
                .foregroundStyle(Color.bruInk)
                .fixedSize(horizontal: false, vertical: true)
            Text(dateLine)
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }

    private func statStrip(_ summary: SessionSummary) -> some View {
        HStack(spacing: 0) {
            BRUReadout(label: "Duration", value: durationLabel(summary.durationSeconds))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            Rectangle().fill(Color.bruInk).frame(width: 1)
            BRUReadout(label: "Sets", value: "\(summary.workingSetCount)")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            Rectangle().fill(Color.bruInk).frame(width: 1)
            BRUReadout(label: "Volume · \(unitLabel)", value: volumeLabel(summary.totalVolume))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func prBand(_ summary: SessionSummary) -> some View {
        let count = summary.prExerciseCount
        return HStack(spacing: 8) {
            Text("PR")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .foregroundStyle(Color.bruPaper)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.bruSignal)
            Text(count == 1 ? "New record on 1 exercise" : "New records on \(count) exercises")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruPaper)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bruInk)
    }

    private func exerciseRow(_ line: SessionSummary.ExerciseLine) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(line.name)
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(setsLine(line))
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                if !line.prKinds.isEmpty {
                    Text("PR · " + line.prKinds.map(prLabel).joined(separator: " · "))
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruSignal)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text("BEST")
                    .font(BRUFont.labelMicro)
                    .tracking(1.5)
                    .foregroundStyle(Color.bruMuted)
                Text(line.best.map(bestLabel) ?? "—")
                    .font(BRUFont.bodyEmphasis)
                    .monospacedDigit()
                    .foregroundStyle(line.prKinds.isEmpty ? Color.bruInk : Color.bruSignal)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    private func notesBlock(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BRUSectionHead("Notes")
            Text(notes)
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruInk)
                .padding(.horizontal, 16)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Formatting

    private var displayName: String {
        if let name = session.templateName, !name.isEmpty { return name }
        if !session.routineSnapshotName.isEmpty { return session.routineSnapshotName }
        return "Workout"
    }

    private var dateLine: String {
        session.startedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
    }

    private var unitLabel: String {
        (settingsList.first?.weightUnit ?? .kg).rawValue
    }

    private func durationLabel(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return String(format: "%d:%02d", h, m) + "h" }
        return "\(m)m"
    }

    private func volumeLabel(_ volume: Double) -> String {
        Int(volume.rounded()).formatted(.number.grouping(.automatic))
    }

    private func setsLine(_ line: SessionSummary.ExerciseLine) -> String {
        let sets = line.workingSets == 1 ? "1 set" : "\(line.workingSets) sets"
        guard line.volume > 0 else { return sets }
        return "\(sets) · \(volumeLabel(line.volume)) \(unitLabel)"
    }

    private func bestLabel(_ best: SessionSummary.BestSet) -> String {
        let w = String(format: "%g", best.weight)
        if let rpe = best.rpe {
            return "\(w) × \(best.reps) @ \(String(format: "%g", rpe))"
        }
        return "\(w) × \(best.reps)"
    }

    private func prLabel(_ kind: PRKind) -> String {
        switch kind {
        case .weight: return "Weight"
        case .reps:   return "Reps"
        case .volume: return "Volume"
        case .e1RM:   return "e1RM"
        }
    }
}

#if DEBUG
#Preview("session detail") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let ex = Exercise.previewSample(name: "Barbell Bench Press", equipment: .barbell, mechanic: .compound)
    ctx.insert(ex)
    let session = Session()
    ctx.insert(session)
    session.startedAt = .now.addingTimeInterval(-3600)
    session.completedAt = .now
    session.routineSnapshotName = "Push A"
    let se = SessionExercise()
    ctx.insert(se)
    se.session = session
    se.exercise = ex
    se.exerciseNameSnapshot = ex.name
    for i in 0..<3 {
        let entry = SetEntry()
        ctx.insert(entry)
        entry.sessionExercise = se
        entry.orderIndex = i
        entry.weight = 100
        entry.reps = 5
        entry.isComplete = true
    }
    try? ctx.save()
    return SessionDetailView(session: session, onDone: {})
        .modelContainer(container)
}
#endif
