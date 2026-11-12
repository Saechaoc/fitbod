// ExerciseHistoryView.swift
// fitbod — Phase 2.1 Plan 10 → Phase 06.1-06 BRU toolbar pass
//
// BRU rewrite of the per-exercise history view.
// UI-SPEC v2 § Exercise history view (lines 423-439, 607-614).
//
// ## Composition
//
//   BRUHeaderBar (safeAreaInset .top, navigationBarHidden)
//   exercise.name in BRUFont.displayLarge 32pt
//   3-cell stat strip: 'Workouts · 30d' / 'Tonnage' bruSignal / 'PRs · 30d'
//   BRUDivider(.ink)
//   IntentFilterChipRow full-bleed strip (2pt rules drawn internally)
//   MachineFilterChipRow, when the exercise was done on more than one machine (RM-066)
//   set-count summary row (bouts for cardio, RM-062)
//   BRUDivider(.hair)
//   one ExerciseHistoryRow per workout, newest first; the row carries the date
//   and opens that workout's summary, where it can be corrected
//   PRStripFooter at bottom
//
// ## Empty states (UI-SPEC verbatim; "bouts" for cardio, RM-062)
//   All filter + no sets: "No logged sets yet" / "Log this exercise in a workout to see history."
//   Filtered + no match: "No {INTENT} sets" / "Try a different intent filter." + "SHOW ALL" BRUButton
//
// ## Performance
//   Same @Query shape as pre-BRU version: exerciseID-only predicate, intent gate in Swift.
//   Pitfall 1 workaround: capture exerciseID into a local let before #Predicate body.
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor /
//               NO Image(systemName:) / NO Color(.system*) /
//               NO .font(.body/.headline/.title*/caption)
//
// Phase 06.1-06: replaced Phase-6 chart SF Symbol route with BRU HeaderAction("PROGRESS")
//               wired through BRUHeaderBar right slot. FILTER stub removed (was unimplemented).

import SwiftUI
import SwiftData

// MARK: - ExerciseHistoryView

/// BRU-compliant per-exercise history view with intent-split filter.
///
/// Composed of an outer view owning filter state and an inner SwiftData-querying
/// view re-keyed whenever the selected intent changes (standard SwiftData pattern).
public struct ExerciseHistoryView: View {
    public let exercise: Exercise

    @Environment(\.dismiss) private var dismiss

    /// nil = "ALL" — no intent filter. Bound to IntentFilterChipRow.
    @State private var intentFilter: Intent? = nil
    @State private var machineFilter: MachineFilter = .all

    /// Navigation state for "PROGRESS" HeaderAction — pushes ExerciseProgressView
    /// on the stack that pushed this view (Library's).
    @State private var presentingProgress = false

    /// Whether the exercise has any logged set entries (drives PROGRESS affordance visibility).
    @State private var hasHistory: Bool = false

    public init(exercise: Exercise) {
        self.exercise = exercise
    }

    /// No NavigationStack of its own: the view is pushed on Library's stack,
    /// one stack per tab. A nested stack sent VIEW ALL HISTORY back to the
    /// Library list.
    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Exercise name sub-line
                HStack {
                    Text(exercise.name)
                        .font(BRUFont.displayLarge)
                        .foregroundStyle(Color.bruInk)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Inner query view — re-keyed on intentFilter to rebuild @Query predicate
                FilteredHistoryContent(
                    exercise: exercise,
                    intentFilter: $intentFilter,
                    machineFilter: $machineFilter,
                    onHistoryChanged: { count in
                        hasHistory = count > 0
                    }
                )
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $presentingProgress) {
            ExerciseProgressView(exercise: exercise)
        }
        .safeAreaInset(edge: .top) {
            BRUHeaderBar(
                left: HeaderAction("‹ Back", action: { dismiss() }),
                center: "History",
                right: hasHistory
                    ? HeaderAction("PROGRESS", isSignal: false, action: { presentingProgress = true })
                    : nil
            )
        }
    }
}

// MARK: - FilteredHistoryContent

/// Inner view that owns the @Query. Re-initialized whenever intentFilter changes
/// to rebuild the SwiftData predicate (standard SwiftData re-keying pattern).
private struct FilteredHistoryContent: View {
    let exercise: Exercise
    @Binding var intentFilter: Intent?
    @Binding var machineFilter: ExerciseHistoryView.MachineFilter

    /// Callback to inform the outer view whether any history exists (drives PROGRESS affordance).
    let onHistoryChanged: (Int) -> Void

    @Query private var sessionExercises: [SessionExercise]
    @Environment(\.weightUnit) private var defaultUnit

    init(
        exercise: Exercise, intentFilter: Binding<Intent?>, machineFilter: Binding<ExerciseHistoryView.MachineFilter>,
        onHistoryChanged: @escaping (Int) -> Void
    ) {
        self.exercise = exercise
        self._intentFilter = intentFilter
        self._machineFilter = machineFilter
        self.onHistoryChanged = onHistoryChanged

        // Pitfall 1 workaround: capture comparison value into local before #Predicate
        let targetID = exercise.id
        self._sessionExercises = Query(
            filter: #Predicate<SessionExercise> { se in
                se.exercise?.id == targetID
            },
            sort: [SortDescriptor(\.session?.startedAt, order: .reverse)]
        )
    }

    var body: some View {
        // The machine strip shows when the sets were done on two machines or
        // more, or on one and on none; without it every machine's sets show.
        let machineOptions = ExerciseHistoryView.machineOptions(
            in: ExerciseHistoryView.completedSets(from: sessionExercises, intent: nil)
        )
        let machine = machineOptions.count >= 2 ? machineFilter : .all
        let completed = ExerciseHistoryView.completedSets(from: sessionExercises, intent: intentFilter, machine: machine)
        let countsByIntent = buildCounts(machine: machine)
        let totalCount = completed.count
        // The PR replay runs once: the rows' "★ PR" and "PRs · 30d" read it.
        let prSetIDs = ExerciseHistoryView.prSets(from: completed)
        let rows = ExerciseHistoryView.rows(
            from: completed, prSetIDs: prSetIDs, unit: .effective(for: exercise, default: defaultUnit)
        )
        let prFooter = prStats(from: completed)

        // 3-cell stat strip: side by side while every label fits on one
        // line, stacked otherwise, so no label breaks inside a word.
        let workouts = ExerciseHistoryView.workouts30d(from: completed)
        // A history of timed sets has no load to total or rank: the strip
        // shows the longest time, and the weight and reps footer is left out.
        let longest = ExerciseHistoryView.longestTime(in: completed)
        let middle = longest.map { BRUReadout(label: "Longest", value: SetText.duration($0), valueColor: .bruSignal) }
            ?? BRUReadout(label: "Tonnage", value: tonnageLabel(from: completed), valueColor: .bruSignal)
        let prs = ExerciseHistoryView.prs30d(from: completed, prSetIDs: prSetIDs)
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) { statCells(sideBySide: true, workouts: workouts, middle: middle, prs: prs) }
            VStack(alignment: .leading, spacing: 0) {
                statCells(sideBySide: false, workouts: workouts, middle: middle, prs: prs)
            }
        }
        // Inform outer view of history count so it can show/hide PROGRESS
        // affordance. It runs after the view draws: a state change from
        // `body` is a change during a view update.
        .onChange(of: totalCount, initial: true) { _, count in
            onHistoryChanged(count)
        }
        BRUDivider(.ink)

        // Intent filter chip row (2pt rules drawn internally)
        IntentFilterChipRow(filter: $intentFilter, counts: countsByIntent)
        if machineOptions.count >= 2 {
            let inIntent = ExerciseHistoryView.completedSets(from: sessionExercises, intent: intentFilter)
            MachineFilterChipRow(filter: $machineFilter, options: machineOptions.map { option in
                (option.filter, option.label, inIntent.filter { option.filter.includes($0.sessionExercise) }.count)
            })
        }

        // Set-count summary row: the sets and the workouts the list shows
        HStack {
            Text(ExerciseHistoryView.countLine(totalCount, across: rows.count, of: exercise))
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)

        BRUDivider(.hair)

        // Content: empty state or one row per workout
        if completed.isEmpty {
            emptyState
        } else {
            // One row per workout, which shows its date and opens the
            // workout's summary (a row's id is its workout's).
            ForEach(rows) { entry in
                NavigationLink {
                    SessionSummaryDestination(sessionID: entry.id)
                } label: {
                    ExerciseHistoryRow(entry: entry)
                }
                .buttonStyle(.bruRow)
                // The row's date, e1RM and set chips stay readable one by one.
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("exerciseHistory.row")
                BRUDivider(.hair)
            }

            // PR strip footer
            if longest == nil {
                PRStripFooter(
                    topWeight: prFooter.topWeight,
                    topReps: prFooter.topReps,
                    volPR: prFooter.volPR
                )
            }
        }
    }

    // MARK: - Stat strip

    /// The strip's three cells. Side by side, each label keeps its one-line
    /// width and the cells share what is left; stacked, rules divide them.
    @ViewBuilder
    private func statCells(sideBySide: Bool, workouts: Int, middle: BRUReadout, prs: Int) -> some View {
        statCell(BRUReadout(label: "Workouts · 30d", value: "\(workouts)"), sideBySide: sideBySide)
        statRule(sideBySide: sideBySide)
        statCell(middle, sideBySide: sideBySide)
        statRule(sideBySide: sideBySide)
        statCell(BRUReadout(label: "PRs · 30d", value: "\(prs)"), sideBySide: sideBySide)
    }

    private func statCell(_ readout: BRUReadout, sideBySide: Bool) -> some View {
        readout
            .fixedSize(horizontal: sideBySide, vertical: false)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statRule(sideBySide: Bool) -> some View {
        Rectangle().fill(Color.bruHair)
            .frame(width: sideBySide ? 1 : nil, height: sideBySide ? nil : 1)
    }

    // MARK: - Computed properties

    /// Tonnage display label (e.g. "71.2k").
    private func tonnageLabel(from sets: [(setEntry: SetEntry, sessionExercise: SessionExercise)]) -> String {
        let total = sets.reduce(0.0) { $0 + $1.setEntry.tonnage }
        if total >= 1000 {
            return String(format: "%.1fk", total / 1000)
        }
        return "\(Int(total))"
    }

    /// Counts by intent for IntentFilterChipRow, on the machine shown.
    private func buildCounts(machine: ExerciseHistoryView.MachineFilter) -> [Intent?: Int] {
        var counts: [Intent?: Int] = [:]
        for se in sessionExercises where machine.includes(se) {
            let sets = (se.sets ?? []).filter { $0.isComplete && !$0.isWarmup }
            if sets.isEmpty { continue }
            let intent = se.session?.intent
            counts[intent, default: 0] += sets.count
        }
        return counts
    }

    // MARK: - PR footer stats

    private struct PRStats {
        let topWeight: String
        let topReps: String
        let volPR: String
    }

    private func prStats(
        from sets: [(setEntry: SetEntry, sessionExercise: SessionExercise)]
    ) -> PRStats {
        let allSets = sets.map { $0.setEntry }
        let topWeight = allSets.max(by: { $0.weight < $1.weight })
        let topReps = allSets.max(by: { $0.reps < $1.reps })

        let topWeightLabel = topWeight.map { NumberText.weight($0.weight) } ?? "—"

        let topRepsLabel = topReps.map { "\($0.reps)" } ?? "—"

        // Volume PR = session with highest total volume
        let bySession = Dictionary(grouping: sets) { $0.sessionExercise.session?.id }
        let sessionVols = bySession.values.map { pairs in
            pairs.reduce(0.0) { $0 + $1.setEntry.tonnage }
        }
        let maxVol = sessionVols.max() ?? 0
        let volLabel: String
        if maxVol >= 1000 {
            volLabel = String(format: "%.1fk", maxVol / 1000)
        } else if maxVol > 0 {
            volLabel = "\(Int(maxVol))"
        } else {
            volLabel = "—"
        }

        return PRStats(topWeight: topWeightLabel, topReps: topRepsLabel, volPR: volLabel)
    }

    // MARK: - Empty state

    @ViewBuilder private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 48)
            if intentFilter == nil {
                Text(exercise.isCardio ? "No logged bouts yet" : "No logged sets yet") // UI-SPEC verbatim; cardio logs bouts (RM-062)
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruInk)
                Text("Log this exercise in a workout to see history.")  // UI-SPEC verbatim
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .multilineTextAlignment(.center)
            } else {
                Text("No \(intentFilter!.rawValue.capitalized) \(exercise.isCardio ? "bouts" : "sets")") // UI-SPEC verbatim format
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruInk)
                Text("Try a different intent filter.")                   // UI-SPEC verbatim
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .multilineTextAlignment(.center)
                BRUButton("SHOW ALL", kind: .signal, size: .md) {       // UI-SPEC verbatim
                    intentFilter = nil
                }
            }
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shown sets and workouts

extension ExerciseHistoryView {

    /// The longest time among `sets` when every one of them is timed; nil
    /// when any set has reps, or there are none.
    static func longestTime(in sets: [(setEntry: SetEntry, sessionExercise: SessionExercise)]) -> Int? {
        sets.allSatisfy(\.setEntry.isTimed) ? sets.compactMap(\.setEntry.durationSeconds).max() : nil
    }

    /// The sets the history shows: the completed working sets of the
    /// exercise's logs, from the workouts of `intent`, or of any intent
    /// when it is nil, on `machine`.
    static func completedSets(
        from logs: [SessionExercise],
        intent: Intent?,
        machine: MachineFilter = .all
    ) -> [(setEntry: SetEntry, sessionExercise: SessionExercise)] {
        let intentGate: String? = intent?.rawValue
        return logs.filter(machine.includes).flatMap { se in
            (se.sets ?? [])
                .filter { $0.isComplete && !$0.isWarmup }
                .map { (setEntry: $0, sessionExercise: se) }
        }
        .filter { pair in
            guard let targetIntent = intentGate else { return true }
            return pair.sessionExercise.session?.intentRaw == targetIntent
        }
    }

    /// "Workouts · 30d": the workouts the list shows, one row each, that
    /// started in the last 30 days. A workout shows once it has a set in
    /// `sets`, so one in progress counts from its first completed working
    /// set, and an empty one never counts.
    static func workouts30d(
        from sets: [(setEntry: SetEntry, sessionExercise: SessionExercise)],
        now: Date = .now
    ) -> Int {
        let cutoff = last30DaysStart(now: now)
        return Set(sets.compactMap { pair -> UUID? in
            guard let session = pair.sessionExercise.session, session.startedAt >= cutoff else { return nil }
            return session.id
        }).count
    }

    /// The start of the last 30 days, the window both "· 30d" cells count.
    private static func last30DaysStart(now: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
    }
}

// MARK: - Machines (RM-066)

extension ExerciseHistoryView {

    /// Which machine's sets the history shows.
    enum MachineFilter: Hashable {
        case all
        /// The sets logged without a machine.
        case noMachine
        case machine(UUID)

        func includes(_ log: SessionExercise) -> Bool {
            switch self {
            case .all: true
            case .noMachine: log.machine == nil
            case .machine(let id): log.machine?.id == id
            }
        }
    }

    /// The machine strip's choices for `sets`: each machine they were done
    /// on, the most recent first, then NO MACHINE when some named none.
    static func machineOptions(
        in sets: [(setEntry: SetEntry, sessionExercise: SessionExercise)]
    ) -> [(filter: MachineFilter, label: String)] {
        var latest: [UUID: (name: String, at: Date)] = [:]
        var hasNone = false
        for log in sets.map(\.sessionExercise) {
            guard let machine = log.machine else { hasNone = true; continue }
            let at = log.session?.startedAt ?? .distantPast
            if at >= latest[machine.id]?.at ?? .distantPast { latest[machine.id] = (machine.displayName, at) }
        }
        // Two machines of one workout, a switch partway through, go by name.
        let machines = latest
            .sorted { $0.value.at != $1.value.at ? $0.value.at > $1.value.at : $0.value.name < $1.value.name }
            .map { (filter: MachineFilter.machine($0.key), label: $0.value.name) }
        return machines + (hasNone ? [(filter: .noMachine, label: "No machine")] : [])
    }
}

// MARK: - PR count

extension ExerciseHistoryView {

    /// The working sets from the last 30 days that set a personal record, by
    /// the in-workout PR banner's check: every set the history shows is
    /// replayed oldest first through `PRDetector.check(set:against:)` from an
    /// empty table, and a set counts when it tops any PR kind. A set is from
    /// the last 30 days when its workout started in them, the window
    /// "Workouts · 30d" counts.
    ///
    /// Oldest first is by workout start, then the time each set was logged,
    /// then log order and set order, whatever order SwiftData returns the
    /// sets in. On equal values the earlier set keeps the record.
    static func prs30d(
        from sets: [(setEntry: SetEntry, sessionExercise: SessionExercise)],
        now: Date = .now
    ) -> Int {
        prs30d(from: sets, prSetIDs: prSets(from: sets), now: now)
    }

    /// `prs30d(from:now:)` from `prSetIDs`, the replay's result for the
    /// same sets, which the history's rows read too, so it runs once.
    static func prs30d(
        from sets: [(setEntry: SetEntry, sessionExercise: SessionExercise)],
        prSetIDs: Set<ObjectIdentifier>,
        now: Date = .now
    ) -> Int {
        let cutoff = last30DaysStart(now: now)
        return sets.filter { pair in
            prSetIDs.contains(ObjectIdentifier(pair.setEntry))
                && (pair.sessionExercise.session?.startedAt ?? .distantPast) >= cutoff
        }.count
    }

    /// The sets that set a personal record, by the replay `prs30d`
    /// describes, at any date. A history row shows "★ PR" when its
    /// workout has one.
    static func prSets(
        from sets: [(setEntry: SetEntry, sessionExercise: SessionExercise)]
    ) -> Set<ObjectIdentifier> {
        var table = PRTable()
        return Set(PRDetector.replay(sets.map(\.setEntry), into: &table).map { ObjectIdentifier($0.set) })
    }
}

// MARK: - Rows

extension ExerciseHistoryView {

    /// One row per workout, newest first, from the completed working sets
    /// the history shows. A row's id is its workout's, so two workouts on
    /// one day are two rows, and the row shows the date. A row reads every
    /// log of the exercise in its workout, so its top set, e1RM, set count
    /// and chips cover all of them. `prSetIDs` is `prSets(from:)` for the
    /// same sets: a row shows "★ PR" when one of its sets is in it. `unit`
    /// names a timed set's distance; weights show without a unit.
    static func rows(
        from sets: [(setEntry: SetEntry, sessionExercise: SessionExercise)],
        prSetIDs: Set<ObjectIdentifier>,
        unit: WeightUnit = .default
    ) -> [HistoryEntry] {
        Dictionary(grouping: sets) { $0.sessionExercise.session?.id }
            .values
            .compactMap { pairs -> (startedAt: Date, entry: HistoryEntry)? in
                guard let session = pairs.first?.sessionExercise.session else { return nil }
                return (session.startedAt, row(for: session, from: pairs, prSetIDs: prSetIDs, unit: unit))
            }
            .sorted { $0.startedAt > $1.startedAt }
            .map(\.entry)
    }

    /// One workout's row, from its pairs in `sets`.
    private static func row(
        for session: Session,
        from pairs: [(setEntry: SetEntry, sessionExercise: SessionExercise)],
        prSetIDs: Set<ObjectIdentifier>,
        unit: WeightUnit
    ) -> HistoryEntry {
        // All working sets for this session, across every log of the
        // exercise in it: in log order, then set order (`orderIndex`
        // both times), whatever order SwiftData returns them in.
        let ordered = pairs
            .sorted {
                ($0.sessionExercise.orderIndex, $0.setEntry.orderIndex)
                    < ($1.sessionExercise.orderIndex, $1.setEntry.orderIndex)
            }
        let sets = ordered.map(\.setEntry)
        // The machines the sets were done on, each once, in log order.
        var machines: [String] = []
        for name in ordered.compactMap({ $0.sessionExercise.machine?.displayName }) where !machines.contains(name) {
            machines.append(name)
        }

        // The top set is the set the e1RM comes from, the one with the
        // highest e1RM. When no set has an e1RM, all of them 0 or less so
        // the e1RM reads "—", it is the set with the most volume, weight
        // times reps, and among timed sets the longest. `max(by:)` keeps
        // the first of equal elements, so the earlier set wins a tie.
        let best = sets.max { e1RM(of: $0) < e1RM(of: $1) }
        let bestE1RM = best.map(e1RM(of:)) ?? 0
        let topSet = bestE1RM > 0
            ? best
            : sets.max { size(of: $0) < size(of: $1) }
        // A workout of timed sets has no e1RM to show, not a missing one.
        let e1RMLabel: String? = sets.allSatisfy(\.isTimed)
            ? nil
            : bestE1RM > 0
                ? (bestE1RM.truncatingRemainder(dividingBy: 1) == 0
                   ? "\(Int(bestE1RM))"
                   : String(format: "%.1f", bestE1RM))
                : "—"

        return HistoryEntry(
            id: session.id,
            dateLabel: formatDateLabel(session.startedAt),
            intentLabel: shortIntentLabel(session.intent),
            isPR: sets.contains { prSetIDs.contains(ObjectIdentifier($0)) },
            e1RMLabel: e1RMLabel,
            topSetLabel: topSet.map { setLabel($0, unit: unit) } ?? "—",
            setCount: sets.count,
            countNoun: pairs.first?.sessionExercise.exercise?.isCardio == true ? "bout" : "set",
            setChips: sets.map { setLabel($0, unit: unit) },
            machineLabel: machines.isEmpty ? nil : machines.joined(separator: " · ")
        )
    }

    /// The line over the rows, "3 sets across 2 workouts", or "1 bout
    /// across 1 workout" for a cardio exercise, which logs bouts (RM-062).
    static func countLine(_ count: Int, across workouts: Int, of exercise: Exercise) -> String {
        "\(BRUCountLabel.text(count, exercise.isCardio ? "bout" : "set")) across \(BRUCountLabel.text(workouts, "workout"))"
    }

    /// How a set ranks when no set has an e1RM: by volume, then by time.
    private static func size(of set: SetEntry) -> (Double, Int) {
        (set.weight * Double(set.reps), set.isTimed ? set.durationSeconds ?? 0 : 0)
    }

    /// A set's e1RM, as Progress and the PR list estimate it; 0 when the
    /// estimate leaves the set out (more than 10 reps, or no load).
    private static func e1RM(of set: SetEntry) -> Double {
        OneRepMaxEstimator.estimate(weight: set.weight, reps: set.reps) ?? 0
    }

    /// A set as its chip and the TOP line read, such as "107.5×2 @9.5", or
    /// "20:00 2.5mi" for a timed set.
    private static func setLabel(_ set: SetEntry, unit: WeightUnit) -> String {
        let result = set.resultText(unit: unit, compact: true)
        if let rpe = set.rpe {
            let rpeStr = rpe.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(rpe))" : String(format: "%.1f", rpe)
            return "\(result) @\(rpeStr)"
        }
        return result
    }

    private static func formatDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "TODAY"
        }
        // "MON, MAY 11" — uppercased EEE, MMM d
        return date.formatted(
            .dateTime
                .weekday(.abbreviated)
                .month(.abbreviated)
                .day()
        ).uppercased()
    }

    private static func shortIntentLabel(_ intent: Intent) -> String {
        switch intent {
        case .strength:    return "STR"
        case .hypertrophy: return "HYP"
        case .power:       return "PWR"
        case .endurance:   return "END"
        case .technique:   return "TECH"
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ExerciseHistoryView (empty)") {
    let container = PreviewModelContainer.make()
    let exercises = try! container.mainContext.fetch(FetchDescriptor<Exercise>())
    if let first = exercises.first {
        return AnyView(
            NavigationStack {
                ExerciseHistoryView(exercise: first)
            }
            .modelContainer(container)
        )
    }
    return AnyView(Text("No exercises").modelContainer(container))
}
#endif
