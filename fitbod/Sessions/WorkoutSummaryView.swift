//
//  WorkoutSummaryView.swift
//  fitbod
//
//  The finished-workout recap. Two presentations of the same screen:
//
//    .justFinished — inside the workout cover right after Finish, with a
//                    thumb-zone DONE bar that returns to the tabs.
//    .history      — pushed from History / Today, with a Delete action.
//
//  Content: iron hero (routine snapshot name, date + time range, Time /
//  Sets / Reps / Volume), then one row per exercise with every completed
//  set, the best set, and the change versus the previous matching-intent
//  session ("+10 lb", "+1 rep", "Same as last", "First time").
//
//  Everything shown comes from the session snapshot — renaming or editing
//  the routine afterwards never changes this screen.
//

import SwiftUI
import SwiftData

public struct WorkoutSummaryView: View {
    public enum Presentation: Sendable {
        case justFinished
        case history
    }

    @Environment(\.modelContext) private var ctx
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Bindable public var session: Session
    public let presentation: Presentation
    @Query private var settingsList: [UserSettings]

    @State private var recaps: [ExerciseRecap] = []
    @State private var presentingDelete = false

    public init(session: Session, presentation: Presentation) {
        self.session = session
        self.presentation = presentation
    }

    public var body: some View {
        let stats = WorkoutStats.compute(for: session)
        ScrollView {
            VStack(alignment: .leading, spacing: Chalk.Space.xl) {
                hero(stats)
                if let notes = session.notes, !notes.isEmpty {
                    ChalkInlineMessage(notes)
                }
                VStack(alignment: .leading, spacing: Chalk.Space.sm) {
                    ChalkSectionHeader("Exercises") {
                        Text("Best set · vs last").chalkLabelStyle()
                    }
                    if recaps.isEmpty {
                        Text("No completed sets were recorded.")
                            .font(.chalkBody)
                            .foregroundStyle(.chalkInk2)
                            .padding(.vertical, Chalk.Space.md)
                    }
                    ForEach(recaps) { recap in
                        recapRow(recap)
                    }
                }
            }
            .padding(.horizontal, Chalk.Space.gutter)
            .padding(.vertical, Chalk.Space.lg)
        }
        .background {
            Color.chalkCanvas.ignoresSafeArea()
        }
        .navigationTitle(screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(presentation == .justFinished)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if presentation == .history {
                    Menu {
                        Button(role: .destructive) {
                            presentingDelete = true
                        } label: {
                            Label("Delete workout", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("Workout options")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if presentation == .justFinished {
                ChalkBottomBar {
                    Button("Done") {
                        router.dismissWorkout()
                    }
                    .buttonStyle(.chalk(.inverse, size: .large, fullWidth: true))
                    .accessibilityIdentifier("summary.done")
                }
            }
        }
        .alert("Delete this workout?", isPresented: $presentingDelete) {
            Button("Delete", role: .destructive) {
                dismiss()
                let target = session
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    WorkoutFinisher.discard(target, context: ctx)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its sets will no longer count toward history or previous performance.")
        }
        .task(id: session.completedAt) {
            recaps = ExerciseRecap.build(for: session, context: ctx)
        }
    }

    // MARK: Hero

    private func hero(_ stats: WorkoutStats) -> some View {
        ChalkPanel {
            VStack(alignment: .leading, spacing: Chalk.Space.md) {
                if presentation == .justFinished {
                    Label("Workout complete", systemImage: "checkmark")
                        .chalkLabelStyle(color: .chalkAccentOnPanel)
                }
                Text(session.routineSnapshotName.isEmpty ? "Workout" : session.routineSnapshotName)
                    .font(.chalkDisplay)
                    .textCase(.uppercase)
                    .foregroundStyle(.chalkOnPanel)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("summary.title")
                Text(dateLine)
                    .font(.chalkCallout)
                    .foregroundStyle(.chalkOnPanel2)
                Rectangle()
                    .fill(Color.chalkPanelRaised)
                    .frame(height: Chalk.Line.hairline)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 72), spacing: Chalk.Space.md, alignment: .leading)],
                    alignment: .leading,
                    spacing: Chalk.Space.md
                ) {
                    ChalkMetric("Time", value: ChalkFormat.clock(seconds: stats.durationSeconds), onPanel: true)
                    ChalkMetric("Sets", value: "\(stats.completedSets)", onPanel: true)
                        .accessibilityIdentifier("summary.sets")
                    ChalkMetric("Reps", value: "\(stats.totalReps)", onPanel: true)
                    ChalkMetric("Vol \(unitLabel)", value: ChalkFormat.volume(stats.volume), onPanel: true)
                }
            }
        }
    }

    private var screenTitle: String {
        presentation == .justFinished ? "SUMMARY" : "WORKOUT"
    }

    private var dateLine: String {
        let day = session.startedAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        let start = session.startedAt.formatted(date: .omitted, time: .shortened)
        if let end = session.completedAt {
            return "\(day) · \(start)–\(end.formatted(date: .omitted, time: .shortened))"
        }
        return "\(day) · started \(start)"
    }

    private var unitLabel: String {
        (settingsList.first?.weightUnit ?? .lb).rawValue
    }

    // MARK: Rows

    private func recapRow(_ recap: ExerciseRecap) -> some View {
        VStack(alignment: .leading, spacing: Chalk.Space.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Chalk.Space.md) {
                Text(recap.name)
                    .font(.chalkHeadline)
                    .foregroundStyle(.chalkInk)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Chalk.Space.sm)
                if let best = recap.best {
                    Text("\(ChalkFormat.weight(best.weight)) × \(best.reps)")
                        .font(.chalkMetric)
                        .foregroundStyle(.chalkInk)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: Chalk.Space.md) {
                Text(setsLine(recap))
                    .font(.chalkFootnote)
                    .foregroundStyle(.chalkInk2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Chalk.Space.sm)
                Text(deltaText(recap.delta))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(deltaIsGain(recap.delta) ? Color.chalkAccentInk : Color.chalkInk2)
            }
            Rectangle()
                .fill(Color.chalkDivider)
                .frame(height: Chalk.Line.hairline)
                .padding(.top, Chalk.Space.sm)
        }
        .accessibilityElement(children: .combine)
    }

    private func setsLine(_ recap: ExerciseRecap) -> String {
        let sets = recap.lines.map { "\(ChalkFormat.weight($0.weight))×\($0.reps)" }.joined(separator: ", ")
        return "\(recap.lines.count) set\(recap.lines.count == 1 ? "" : "s") · \(sets)"
    }

    private func deltaText(_ delta: ExerciseRecap.Delta) -> String {
        switch delta {
        case .firstTime: return "First time"
        case .same: return "Same as last"
        case .heavier(let w): return "+\(ChalkFormat.weight(w)) \(unitLabel)"
        case .lighter(let w): return "−\(ChalkFormat.weight(w)) \(unitLabel)"
        case .moreReps(let n): return "+\(n) rep\(n == 1 ? "" : "s")"
        case .fewerReps(let n): return "−\(n) rep\(n == 1 ? "" : "s")"
        }
    }

    private func deltaIsGain(_ delta: ExerciseRecap.Delta) -> Bool {
        switch delta {
        case .heavier, .moreReps: return true
        default: return false
        }
    }
}

#Preview("Summary — finished workout") {
    let container = PreviewModelContainer.makeDemo()
    let sessions = (try? container.mainContext.fetch(FetchDescriptor<Session>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)]))) ?? []
    return NavigationStack {
        if let session = sessions.first {
            WorkoutSummaryView(session: session, presentation: .justFinished)
        }
    }
    .environment(AppRouter())
    .modelContainer(container)
}
