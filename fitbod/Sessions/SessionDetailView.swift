// SessionDetailView.swift
// fitbod
//
// Workout summary for one logged Session. Two entry points share it:
//
//   1. Post-Finish: SessionLoggerView presents it full-screen with an
//      `onDone` closure. The header shows "DONE" and a full-width DONE
//      button sits at the bottom; tapping either returns to Today.
//   2. History: push `SessionDetailView(session:)` onto a NavigationStack.
//      With no `onDone`, the header goes back with "‹ BACK" instead, and a
//      finished workout offers EDIT, which opens WorkoutEditView.
//
// Content (all read from logged rows via SessionSummary, never from the
// template): name + date, a DURATION / SETS / VOLUME stat strip, a PR band
// when any PR landed, then each exercise with its working-set count,
// volume and PR kinds. Each opens compact; a tap shows every set it
// logged, the best one marked.
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor
//               NO Image(systemName:) / NO .font(.body/.headline/.title/.caption)
//               NO .buttonStyle(.bordered) / NO Color(.system*)

import SwiftUI
import SwiftData

public struct SessionDetailView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var weightUnit
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(HistoryEdits.self) private var historyEdits: HistoryEdits?

    public let session: Session
    private let onDone: (() -> Void)?
    private let onDeleted: () -> Void

    @State private var summary: SessionSummary?
    @State private var editing = false
    /// Exercises showing their sets; the rest read as one line (FT-12).
    @State private var expanded: Set<UUID> = []

    private struct SummaryKey: Equatable {
        let sessionID: UUID
        let edits: Int
    }

    /// History entry point: push onto a NavigationStack. `onDeleted` runs
    /// after Edit workout deletes the workout, for the caller to leave.
    public init(session: Session, onDeleted: @escaping () -> Void = {}) {
        self.session = session
        self.onDone = nil
        self.onDeleted = onDeleted
    }

    /// Post-Finish entry point: `onDone` runs for the DONE actions.
    public init(session: Session, onDone: @escaping () -> Void) {
        self.session = session
        self.onDone = onDone
        self.onDeleted = {}
    }

    /// A finished workout opened from History can be corrected.
    private var canEdit: Bool {
        onDone == nil && session.completedAt != nil
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
                        let unit = (session.exercises ?? []).first(where: { $0.id == line.id })?
                            .exercise?.unitOverride ?? weightUnit
                        exerciseRow(line, unit: unit)
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
            // After Finish the summary closes from its bottom Done button
            // (one Done, not two); opened from history it goes back with ‹ BACK.
            BRUHeaderBar(
                left: onDone == nil ? HeaderAction("‹ Back") { dismiss() } : nil,
                center: "Summary",
                right: canEdit ? HeaderAction("Edit") { editing = true } : nil
            )
        }
        .fullScreenCover(isPresented: $editing) {
            NavigationStack {
                WorkoutEditView(session: session, onDeleted: onDeleted)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let onDone {
                BRUButton("Done", kind: .primary, size: .lg) { onDone() }
                    .accessibilityIdentifier("summary.done")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.bruPaper)
                    .overlay(Rectangle().fill(Color.bruInk).frame(height: 2), alignment: .top)
            }
        }
        .task(id: SummaryKey(sessionID: session.id, edits: historyEdits?.version ?? 0)) {
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
                .foregroundStyle(session.completedAt == nil ? Color.bruMuted : Color.bruSignalText)
            Text(session.displayName)
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

    /// Three columns, or at accessibility sizes one cell under another, as
    /// TodayStatStrip's are, so no label or value breaks inside itself.
    private func statStrip(_ summary: SessionSummary) -> some View {
        statLayout {
            BRUReadout(label: "Duration", value: durationLabel(summary.durationSeconds))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            statDivider
            BRUReadout(label: "Sets", value: "\(summary.workingSetCount)")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            statDivider
            BRUReadout(label: "Volume · \(unitLabel)", value: volumeLabel(summary.totalVolume))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// 1pt bruInk rule between cells: upright beside them, flat once they stack.
    private var statDivider: some View {
        Rectangle()
            .fill(Color.bruInk)
            .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 1,
                   height: dynamicTypeSize.isAccessibilitySize ? 1 : nil)
    }

    private var statLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(spacing: 0))
    }

    private func prBand(_ summary: SessionSummary) -> some View {
        let count = summary.prExerciseCount
        return HStack(spacing: 8) {
            Text("PR")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .foregroundStyle(Color.bruOnSignal)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.bruSignal)
            Text("\(count == 1 ? "New record" : "New records") on \(BRUCountLabel.text(count, "exercise"))")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruPaper)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bruInk)
    }

    /// One exercise: its name, sets line and PRs, which open its sets on tap.
    private func exerciseRow(_ line: SessionSummary.ExerciseLine, unit: WeightUnit) -> some View {
        let open = expanded.contains(line.id)
        return VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if open { expanded.remove(line.id) } else { expanded.insert(line.id) }
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(line.name)
                            .font(BRUFont.bodyEmphasis)
                            .foregroundStyle(Color.bruInk)
                            .fixedSize(horizontal: false, vertical: true)
                        if let machine = line.machineName {
                            Text(machine)
                                .font(BRUFont.labelSmall)
                                .tracking(1.2)
                                .textCase(.uppercase)
                                .foregroundStyle(Color.bruMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(setsLine(line, unit: unit))
                            .font(BRUFont.labelSmall)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.bruMuted)
                        if !line.prKinds.isEmpty {
                            Text("PR · " + line.prKinds.map(prLabel).joined(separator: " · "))
                                .font(BRUFont.labelSmall)
                                .tracking(1.2)
                                .textCase(.uppercase)
                                .foregroundStyle(Color.bruSignalText)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(open ? "▾" : "▸")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(open ? "Expanded" : "Collapsed")
            .accessibilityHint("Shows or hides its sets")
            .accessibilityIdentifier("summary.exercise")
            if open {
                ForEach(Array(line.sets.enumerated()), id: \.offset) { index, set in
                    setRow(number: index + 1, set: set, isRecord: !line.prKinds.isEmpty, unit: unit)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    /// One logged set: its number, its weight × reps or its time, the best
    /// set's tag and the RPE. The tag turns signal when the exercise set a
    /// record.
    private func setRow(number: Int, set: SessionSummary.LoggedSet, isRecord: Bool, unit: WeightUnit) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(BRUFont.labelSmall)
                .monospacedDigit()
                .foregroundStyle(Color.bruMuted)
                .frame(minWidth: 20, alignment: .leading)
            Text(set.resultText(unit: unit))
                .font(BRUFont.bodyEmphasis)
                .monospacedDigit()
                .foregroundStyle(Color.bruInk)
            if set.isBest {
                Text("Best")
                    .font(BRUFont.labelMicro)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(isRecord ? Color.bruSignalText : Color.bruMuted)
            }
            Spacer(minLength: 8)
            if let rpe = set.rpe {
                Text("@ \(NumberText.weight(rpe))")
                    .font(BRUFont.bodyDefault)
                    .monospacedDigit()
                    .foregroundStyle(Color.bruMuted)
            }
        }
        .frame(minHeight: 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(setLabel(number: number, set: set, unit: unit))
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

    private var dateLine: String {
        session.startedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
    }

    private var unitLabel: String {
        weightUnit.rawValue
    }

    private func durationLabel(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return String(format: "%d:%02d", h, m) + "h" }
        return "\(m)m"
    }

    private func volumeLabel(_ volume: Double) -> String {
        SessionHistoryFormat.roundedVolume(volume)
    }

    /// "3 sets · 4,050 lb", then the exercise's time when it has one.
    private func setsLine(_ line: SessionSummary.ExerciseLine, unit: WeightUnit) -> String {
        let sets = SessionHistoryFormat.setsLine(count: line.workingSets, volume: line.volume, unit: unit)
        return line.exerciseSeconds.map { sets + " · " + SetText.duration($0) } ?? sets
    }

    private func setLabel(number: Int, set: SessionSummary.LoggedSet, unit: WeightUnit) -> String {
        var label = "Set \(number), " + set.resultText(unit: unit).replacingOccurrences(of: "×", with: "by")
        if let rpe = set.rpe { label += ", RPE \(NumberText.weight(rpe))" }
        if set.isBest { label += ", best set" }
        return label
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
