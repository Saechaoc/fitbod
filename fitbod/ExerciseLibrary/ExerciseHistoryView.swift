//
//  ExerciseHistoryView.swift
//  fitbod
//
//  Wave-5 plan 05-01 — closes Phase 2 with **SESS-10** (per-exercise
//  history with intent split — list view, not chart; charts deferred
//  to Phase 6) and **ROUTINE-08** (same-routine-different-intent
//  maintains separate per-intent histories).
//
//  Reached from the Library tab: `ExerciseLibraryView` → tap a row →
//  `ExerciseDetailView` (Phase 1) → tap the new "View All History"
//  section row → this view pushes onto the Library tab's
//  `NavigationStack`.
//
//  ## Composition
//
//  Top section: a horizontal `IntentFilterChipRow` (six chips — "All"
//  plus the five `Intent` cases). Selecting a chip mutates a
//  `@State private var selectedIntent: Intent?` (nil = "All").
//
//  Body: a private `FilteredHistoryList` owns the `@Query<SessionExercise>`
//  filtered by `(exerciseID, intentRaw?)`. The query re-runs whenever
//  the parent's `selectedIntent` changes — implemented via the SwiftUI
//  "outer state + inner query view re-initialized on key change"
//  pattern (the inner view's `init(...)` rebuilds the descriptor).
//
//  Date-grouped sectioned `List` of `ExerciseHistoryRow`s. Each row
//  shows the routine snapshot name, the set's "{w} × {r} @ RPE {N}"
//  line, and an inline quiet intent badge.
//
//  ## Empty states (UI-SPEC verbatim — both heading and body)
//
//  - All filter + no logged sets: "No logged sets yet" / "Log this
//    exercise in a workout to see history."
//  - Filtered + no matching sets: "No {Intent} sets" / "Try a different
//    intent filter." with "Show All" action (clears filter to nil).
//
//  ## Performance — RESEARCH §6 Pitfall 1 (UUID workaround)
//
//  The `#Predicate<SessionExercise>` predicate compares `se.exercise?.id
//  == X`, which on iOS 17/18 silently returns empty results unless the
//  comparison value is captured in a local var BEFORE the predicate
//  builder runs. See `PreviousMatchingIntent.fetchTopWorkingSet` for
//  the same workaround used in the seed-weight query.
//
//  Performance — Phase 1 indexed `SessionExercise.intentRaw` makes the
//  intent-split predicate O(log n) on the table. Without that index
//  this view would degrade once a user has months of training data.
//
//  ## Why no chart?
//
//  PITFALLS-doc #2 — "mixing strength and hypertrophy histories" is
//  the differentiator's failure mode if implemented naively. The chip
//  filter is the canonical UI control; charts compose ON TOP of this
//  data shape in Phase 6 (per ROADMAP.md). Shipping list-only here
//  proves the intent-split contract before adding visual encoding.
//
//  ## Why exclude warmups and incomplete sets?
//
//  Same shape as `PreviousMatchingIntent` (plan 01-01): the visible
//  history is the *committed working sets* only. Warmups + planned-
//  but-not-completed rows are excluded at the view layer (the parent
//  `SessionExercise` rows still match the predicate, but
//  `.filter { $0.isComplete }` skips planned sets and
//  `.filter { !$0.isWarmup }` skips ramps — see `completedSets`).
//

import SwiftUI
import SwiftData

/// Read-only per-exercise history list with intent-split filter chips.
/// Composed of an outer view owning the chip state and an inner view
/// owning the `@Query` whose predicate is keyed off that state.
public struct ExerciseHistoryView: View {
    public let exercise: Exercise

    /// nil = "All" — no intent filter applied. Bound to the chip row;
    /// the inner `FilteredHistoryList` reads it via the same binding so
    /// the filtered-empty "Show All" button can clear back to nil.
    @State private var selectedIntent: Intent? = nil

    public init(exercise: Exercise) {
        self.exercise = exercise
    }

    public var body: some View {
        VStack(spacing: 0) {
            IntentFilterChipRow(selected: $selectedIntent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            FilteredHistoryList(
                exerciseID: exercise.id,
                intent: $selectedIntent
            )
        }
        .navigationTitle("History")                                           // UI-SPEC verbatim
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text("History").font(.headline)
                    Text(exercise.name)                                       // UI-SPEC verbatim subtitle
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Inner query-owning view. Re-initialised whenever the outer view's
/// `selectedIntent` state changes (SwiftUI rebuilds the inner subtree
/// because the binding key it depends on moved). Each rebuild
/// constructs a fresh `Query` with the appropriate predicate — there
/// is no other way to change a `@Query`'s predicate from inside the
/// same view instance in SwiftData.
private struct FilteredHistoryList: View {
    @Query private var sessionExercises: [SessionExercise]
    @Binding var intent: Intent?
    let exerciseID: UUID

    init(exerciseID: UUID, intent: Binding<Intent?>) {
        self.exerciseID = exerciseID
        self._intent = intent

        // RESEARCH §6 Pitfall 1 — capture the comparison values in
        // LOCAL vars BEFORE the #Predicate body. The SwiftData
        // related-entity-ID compare returns empty results on iOS 17/18
        // when the lookup value is passed by capture through `self`.
        let targetID = exerciseID
        if let intentValue = intent.wrappedValue {
            let targetIntent = intentValue.rawValue
            self._sessionExercises = Query(
                filter: #Predicate<SessionExercise> { se in
                    se.exercise?.id == targetID && se.intentRaw == targetIntent
                },
                sort: [SortDescriptor(\.session?.startedAt, order: .reverse)]
            )
        } else {
            self._sessionExercises = Query(
                filter: #Predicate<SessionExercise> { se in
                    se.exercise?.id == targetID
                },
                sort: [SortDescriptor(\.session?.startedAt, order: .reverse)]
            )
        }
    }

    var body: some View {
        if completedSets.isEmpty {
            emptyState
        } else {
            List {
                if let summary = summaryLine {
                    Section {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(groupedByDate, id: \.dateKey) { group in
                    Section(group.dateLabel) {
                        ForEach(group.rows) { row in
                            ExerciseHistoryRow(
                                setEntry: row.setEntry,
                                sessionExercise: row.sessionExercise
                            )
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    /// Flatten every committed working set across the matching
    /// SessionExercise rows. Warmups and planned-but-not-completed
    /// rows are excluded at this layer — same shape as
    /// `PreviousMatchingIntent.fetchTopWorkingSet`.
    private var completedSets: [(setEntry: SetEntry, sessionExercise: SessionExercise)] {
        sessionExercises.flatMap { se in
            (se.sets ?? [])
                .filter { $0.isComplete && !$0.isWarmup }
                .map { (setEntry: $0, sessionExercise: se) }
        }
    }

    /// UI-SPEC verbatim summary row: "{N} sets across {M} sessions".
    /// Returns nil when no sets — the empty-state branch handles that.
    private var summaryLine: String? {
        let sessionCount = Set(sessionExercises.compactMap { $0.session?.id }).count
        let setCount = completedSets.count
        if setCount == 0 { return nil }
        return "\(setCount) sets across \(sessionCount) sessions"
    }

    /// One date-section's worth of rows.
    private struct HistoryGroup {
        let dateKey: String
        let dateLabel: String
        let rows: [HistoryRow]
    }

    /// Identifiable wrapper for the `ForEach` inside each section.
    /// Uses a fresh `UUID()` because the same `SetEntry` may be safe
    /// to identify by its own `id`, but the explicit wrapper sidesteps
    /// any SwiftData identity rebuild edge cases inside `List`.
    private struct HistoryRow: Identifiable {
        let id = UUID()
        let setEntry: SetEntry
        let sessionExercise: SessionExercise
    }

    /// Group the completed sets by calendar day (start-of-day in the
    /// user's local calendar). Most-recent day first. The label uses
    /// `Date.FormatStyle` for the "Mon, May 11" format — UI-SPEC
    /// verbatim, and the project-native formatter (avoids the
    /// per-render `DateFormatter()` allocation anti-pattern).
    private var groupedByDate: [HistoryGroup] {
        // ISO key uses startOfDay so two sessions on the same day
        // collapse into one section (e.g. an a.m. workout + a p.m.
        // workout produce one "Today" section, not two).
        let isoFormatter = ISO8601DateFormatter()
        let grouped = Dictionary(grouping: completedSets) { pair -> String in
            let date = pair.sessionExercise.session?.startedAt ?? .distantPast
            return isoFormatter.string(from: Calendar.current.startOfDay(for: date))
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (key, pairs) in
                let date = pairs.first?.sessionExercise.session?.startedAt ?? .distantPast
                // UI-SPEC verbatim format "Mon, May 11" — equivalent to
                // DateFormatter format "EEE, MMM d" but built with
                // `Date.FormatStyle` to honor the
                // "no DateFormatter() inside body" anti-pattern (the
                // plan's anti-patterns list rules out per-render
                // `DateFormatter()` allocation).
                let label = date.formatted(
                    .dateTime
                        .weekday(.abbreviated)
                        .month(.abbreviated)
                        .day()
                )
                let rows = pairs.map {
                    HistoryRow(setEntry: $0.setEntry, sessionExercise: $0.sessionExercise)
                }
                return HistoryGroup(dateKey: key, dateLabel: label, rows: rows)
            }
    }

    /// Either the no-logged-sets-yet state (intent == nil) or the
    /// filtered-empty state (intent != nil). UI-SPEC verbatim copy.
    /// The filtered branch uses an explicit force-unwrap on `intent!`
    /// rather than an `if let` shadowing pattern so the source string
    /// "No \(intent!.rawValue.capitalized) sets" remains the canonical
    /// UI-SPEC anchor — verified by `ExerciseHistoryViewCopyTests`.
    /// The force-unwrap is safe because we are already inside the
    /// `intent == nil ? else-branch` guard below.
    @ViewBuilder private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 48)                                        // UI-SPEC 3xl
            if intent == nil {
                Text("No logged sets yet")                                    // UI-SPEC verbatim
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Log this exercise in a workout to see history.")        // UI-SPEC verbatim
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("No \(intent!.rawValue.capitalized) sets")               // UI-SPEC verbatim format
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Try a different intent filter.")                        // UI-SPEC verbatim
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Show All") {                                          // UI-SPEC verbatim accent text button
                    self.intent = nil
                }
                .foregroundStyle(Color.accentColor)
            }
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }
}

#Preview("Empty (no sets)") {
    NavigationStack {
        let container = PreviewModelContainer.make()
        let exercises = try! container.mainContext.fetch(FetchDescriptor<Exercise>())
        ExerciseHistoryView(exercise: exercises.first!)
    }
    .modelContainer(PreviewModelContainer.make())
}
