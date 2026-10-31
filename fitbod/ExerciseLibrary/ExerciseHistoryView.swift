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
//   3-cell stat strip: 'Sessions · 30d' / 'Tonnage' bruSignal / 'PRs · 30d'
//   BRUDivider(.ink)
//   IntentFilterChipRow full-bleed strip (2pt rules drawn internally)
//   set-count summary row
//   BRUDivider(.hair)
//   one ExerciseHistoryRow per workout, newest first; the row carries the date
//   PRStripFooter at bottom
//
// ## Empty states (UI-SPEC verbatim)
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
                left: HeaderAction("‹", action: { dismiss() }),
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

    /// Callback to inform the outer view whether any history exists (drives PROGRESS affordance).
    let onHistoryChanged: (Int) -> Void

    @Query private var sessionExercises: [SessionExercise]

    init(exercise: Exercise, intentFilter: Binding<Intent?>, onHistoryChanged: @escaping (Int) -> Void) {
        self.exercise = exercise
        self._intentFilter = intentFilter
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
        let completed = completedSets
        let countsByIntent = buildCounts()
        let totalCount = completed.count
        let sessionCount = Set(sessionExercises.compactMap { $0.session?.id }).count
        let grouped = ExerciseHistoryView.groupedByDate(from: completed)
        let prFooter = prStats(from: completed)

        // 3-cell stat strip: side by side while every label fits on one
        // line, stacked otherwise, so no label breaks inside a word.
        let tonnage = tonnageLabel(from: completed)
        let prs = ExerciseHistoryView.prs30d(from: completed)
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) { statCells(sideBySide: true, tonnage: tonnage, prs: prs) }
            VStack(alignment: .leading, spacing: 0) { statCells(sideBySide: false, tonnage: tonnage, prs: prs) }
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

        // Set-count summary row
        HStack {
            Text("\(totalCount) sets across \(sessionCount) sessions")
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
            // One row per workout, which shows its date. Date sections
            // keyed by the workout hid their one row, which had the same id.
            ForEach(grouped.flatMap(\.entries)) { entry in
                ExerciseHistoryRow(entry: entry)
                BRUDivider(.hair)
            }

            // PR strip footer
            PRStripFooter(
                topWeight: prFooter.topWeight,
                topReps: prFooter.topReps,
                volPR: prFooter.volPR
            )
        }
    }

    // MARK: - Stat strip

    /// The strip's three cells. Side by side, each label keeps its one-line
    /// width and the cells share what is left; stacked, rules divide them.
    @ViewBuilder
    private func statCells(sideBySide: Bool, tonnage: String, prs: Int) -> some View {
        statCell(BRUReadout(label: "Sessions · 30d", value: "\(sessions30d)"), sideBySide: sideBySide)
        statRule(sideBySide: sideBySide)
        statCell(BRUReadout(label: "Tonnage", value: tonnage, valueColor: .bruSignal), sideBySide: sideBySide)
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

    /// All completed working sets, post-filtered by intent if filter is active.
    private var completedSets: [(setEntry: SetEntry, sessionExercise: SessionExercise)] {
        let intentGate: String? = intentFilter?.rawValue
        return sessionExercises.flatMap { se in
            (se.sets ?? [])
                .filter { $0.isComplete && !$0.isWarmup }
                .map { (setEntry: $0, sessionExercise: se) }
        }
        .filter { pair in
            guard let targetIntent = intentGate else { return true }
            return pair.sessionExercise.session?.intentRaw == targetIntent
        }
    }

    /// Count of sessions in the last 30 days.
    private var sessions30d: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        let recentSEs = sessionExercises.filter {
            ($0.session?.startedAt ?? .distantPast) >= cutoff
        }
        return Set(recentSEs.compactMap { $0.session?.id }).count
    }

    /// Tonnage display label (e.g. "71.2k").
    private func tonnageLabel(from sets: [(setEntry: SetEntry, sessionExercise: SessionExercise)]) -> String {
        let total = sets.reduce(0.0) { $0 + $1.setEntry.weight * Double($1.setEntry.reps) }
        if total >= 1000 {
            return String(format: "%.1fk", total / 1000)
        }
        return "\(Int(total))"
    }

    /// Counts by intent for IntentFilterChipRow.
    private func buildCounts() -> [Intent?: Int] {
        var counts: [Intent?: Int] = [:]
        for se in sessionExercises {
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

        let topWeightLabel: String
        if let tw = topWeight {
            topWeightLabel = tw.weight.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(tw.weight))"
                : String(format: "%.1f", tw.weight)
        } else {
            topWeightLabel = "—"
        }

        let topRepsLabel = topReps.map { "\($0.reps)" } ?? "—"

        // Volume PR = session with highest total volume
        let bySession = Dictionary(grouping: sets) { $0.sessionExercise.session?.id }
        let sessionVols = bySession.values.map { pairs in
            pairs.reduce(0.0) { $0 + $1.setEntry.weight * Double($1.setEntry.reps) }
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
                Text("No logged sets yet")              // UI-SPEC verbatim
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruInk)
                Text("Log this exercise in a workout to see history.")  // UI-SPEC verbatim
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .multilineTextAlignment(.center)
            } else {
                Text("No \(intentFilter!.rawValue.capitalized) sets")   // UI-SPEC verbatim format
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

// MARK: - PR count

extension ExerciseHistoryView {

    /// The working sets from the last 30 days that set a personal record, by
    /// the in-workout PR banner's check: every set the history shows is
    /// replayed oldest first through `PRDetector.check(set:against:)` from an
    /// empty table, and a set counts when it tops any PR kind. A set is from
    /// the last 30 days when its workout started in them, the window
    /// "Sessions · 30d" counts.
    ///
    /// Oldest first is by workout start, then the time each set was logged,
    /// then log order and set order, whatever order SwiftData returns the
    /// sets in. On equal values the earlier set keeps the record.
    static func prs30d(
        from sets: [(setEntry: SetEntry, sessionExercise: SessionExercise)],
        now: Date = .now
    ) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let prSetIDs = prSets(from: sets)
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
        let oldestFirst = sets.sorted { a, b in
            let aStart = a.sessionExercise.session?.startedAt ?? .distantPast
            let bStart = b.sessionExercise.session?.startedAt ?? .distantPast
            return (aStart, a.setEntry.completedAt, a.sessionExercise.orderIndex, a.setEntry.orderIndex)
                < (bStart, b.setEntry.completedAt, b.sessionExercise.orderIndex, b.setEntry.orderIndex)
        }
        var table = PRTable()
        var prSetIDs: Set<ObjectIdentifier> = []
        for pair in oldestFirst where !PRDetector.check(set: pair.setEntry, against: &table).isEmpty {
            prSetIDs.insert(ObjectIdentifier(pair.setEntry))
        }
        return prSetIDs
    }
}

// MARK: - Date grouping

extension ExerciseHistoryView {

    /// One workout's row. Its id is the workout's, so two workouts on one
    /// day are two rows. The list shows its one entry, not a date section,
    /// so the date shows once, in the row.
    struct DateGroup: Identifiable {
        let id: UUID
        let dateKey: String
        let dateLabel: String
        let startedAt: Date
        let entries: [HistoryEntry]
    }

    /// One row per workout, newest date first and, on one date, newest
    /// workout first, from the completed working sets the history shows.
    /// A row reads every log of the exercise in its workout, so its top
    /// set, e1RM, set count and chips cover all of them.
    static func groupedByDate(
        from sets: [(setEntry: SetEntry, sessionExercise: SessionExercise)]
    ) -> [DateGroup] {
        let prSetIDs = prSets(from: sets)
        // Group by session identity (same session = same date group)
        let bySession = Dictionary(grouping: sets) { pair -> String in
            pair.sessionExercise.session?.id.uuidString ?? UUID().uuidString
        }

        return bySession
            .compactMap { (sessionID, pairs) -> DateGroup? in
                guard let firstPair = pairs.first,
                      let session = firstPair.sessionExercise.session else { return nil }
                let date = session.startedAt
                let dateKey = ISO8601DateFormatter().string(
                    from: Calendar.current.startOfDay(for: date)
                )
                let dateLabel = Self.formatDateLabel(date)
                let intent = session.intent

                // All working sets for this session, across every log of the
                // exercise in it: in log order, then set order (`orderIndex`
                // both times), whatever order SwiftData returns them in.
                // `max(by:)` keeps the first of equal elements, so the
                // earlier set wins a tie for the top set.
                let allSetsForSession = pairs
                    .sorted {
                        ($0.sessionExercise.orderIndex, $0.setEntry.orderIndex)
                            < ($1.sessionExercise.orderIndex, $1.setEntry.orderIndex)
                    }
                    .map(\.setEntry)

                let topSet = allSetsForSession.max(by: {
                    $0.weight * Double($0.reps) < $1.weight * Double($1.reps)
                })
                let topSetLabel = topSet.map { set -> String in
                    let w = set.weight.truncatingRemainder(dividingBy: 1) == 0
                        ? "\(Int(set.weight))"
                        : String(format: "%.1f", set.weight)
                    if let rpe = set.rpe {
                        let rpeStr = rpe.truncatingRemainder(dividingBy: 1) == 0
                            ? "\(Int(rpe))" : String(format: "%.1f", rpe)
                        return "\(w)×\(set.reps) @\(rpeStr)"
                    }
                    return "\(w)×\(set.reps)"
                } ?? "—"

                let e1RM = allSetsForSession.compactMap { set -> Double? in
                    let rpe = set.rpe ?? 8.0
                    let rir = 10.0 - rpe
                    return set.weight * (1 + (Double(set.reps) + rir) / 30.0)
                }.max() ?? 0
                let e1RMLabel = e1RM > 0
                    ? (e1RM.truncatingRemainder(dividingBy: 1) == 0
                       ? "\(Int(e1RM))"
                       : String(format: "%.1f", e1RM))
                    : "—"

                let chips = allSetsForSession.map { set -> String in
                    let w = set.weight.truncatingRemainder(dividingBy: 1) == 0
                        ? "\(Int(set.weight))"
                        : String(format: "%.1f", set.weight)
                    if let rpe = set.rpe {
                        let rpeStr = rpe.truncatingRemainder(dividingBy: 1) == 0
                            ? "\(Int(rpe))" : String(format: "%.1f", rpe)
                        return "\(w)×\(set.reps) @\(rpeStr)"
                    }
                    return "\(w)×\(set.reps)"
                }

                let entry = HistoryEntry(
                    id: UUID(uuidString: sessionID) ?? UUID(),
                    dateLabel: dateLabel,
                    intentLabel: Self.shortIntentLabel(intent),
                    isPR: allSetsForSession.contains { prSetIDs.contains(ObjectIdentifier($0)) },
                    e1RMLabel: e1RMLabel,
                    topSetLabel: topSetLabel,
                    setCount: allSetsForSession.count,
                    setChips: chips
                )
                return DateGroup(
                    id: session.id,
                    dateKey: dateKey,
                    dateLabel: dateLabel,
                    startedAt: date,
                    entries: [entry]
                )
            }
            .sorted { ($0.dateKey, $0.startedAt) > ($1.dateKey, $1.startedAt) }
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
