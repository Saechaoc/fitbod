//
//  ExercisePRsView.swift
//  fitbod
//
//  Wave-4 plan 06-07 — per-exercise / all-exercises PR list (CONTEXT
//  D-10..D-13 + REQUIREMENTS PROG-05).
//
//  ## Scope (CONTEXT D-13)
//
//    .forExercise(UUID) — single exercise PR detail
//    .allExercises      — all-exercises feed (consumed by
//                         ProgressHomeView's "Personal Records" row)
//
//  ## Layout (Phase 6.1 BRU reskin — 06.1-03)
//
//  BRUHeaderBar(left: back, center: nav title, right: "ALL TIME")
//  3-segment inverted-active intent toggle bar (stacked above default text)
//  BRUDivider(.ink)
//  ScrollView → LazyVStack of 4 sections (Weight / Reps / Volume / e1RM)
//
//  ## Rows per (kind, bucket)
//
//  PRDetector.PRTable holds ONE PRRecord per slot (the current best).
//  This view lists up to three records per exercise, so it ranks the
//  @Query<SetEntry> result itself (`PRBucketRanking`): one row per
//  distinct set (same exercise, weight and reps), dated when it was
//  first logged like PRDetector's tie rule, ranked by the bucket's
//  measure across exercises, at most three rows per exercise. Each row
//  names its exercise. Only the working sets PR detection counts
//  (`PRDetector.isWorkingSet`) rank, so drop, failure and rest-pause sets
//  and sets without weight never show. Acceptable at v1 single-user scale
//  per CONTEXT D-12 ("computed on-demand from SetEntry history; NOT
//  denormalized").
//
//  Every section has the same buckets and a set shows once per section,
//  so bucket and row ids include the kind: repeated ids leave the later
//  buckets blank in the LazyVStack.
//
//  ## Empty state (UI-SPEC verbatim)
//
//    Heading: "No PRs yet"
//    Body:    "Complete a working set to set your first record."
//
//  ## Outer/inner @Query split (PATTERNS §Pattern D)
//
//  Outer view owns the IntentFilter @State + scope param. Inner
//  `PRsHost` declares `@Query<SetEntry>` predicate-narrowed to the
//  scope (UUID local-let capture per Pitfall 3) and computes the
//  display rows inline.
//
//  ## Row tap → session destination
//
//  No `CompletedSessionView` exists in v1. PR row taps push a
//  placeholder `Text("Session of {date}")` per the plan; documented
//  as a v2 follow-up entry point.
//
//  [CITED: CONTEXT D-10..D-13 + UI-SPEC § ExercisePRsView + PROG-05]
//

import SwiftData
import SwiftUI
import UIKit

// MARK: - Scope + IntentFilter

public enum ExercisePRsViewScope: Hashable, Sendable {
    case forExercise(UUID)
    case allExercises
}

public enum ExercisePRsIntentFilter: String, CaseIterable, Sendable {
    case strength
    case hypertrophy
    case all

    public var label: String {
        switch self {
        case .strength:    return "Strength"
        case .hypertrophy: return "Hypertrophy"
        case .all:         return "All"
        }
    }

    public func matches(intent: Intent) -> Bool {
        switch self {
        case .strength:    return intent == .strength
        case .hypertrophy: return intent == .hypertrophy
        case .all:         return true
        }
    }
}

// MARK: - ExercisePRsView (outer)

public struct ExercisePRsView: View {
    public let scope: ExercisePRsViewScope
    @State private var intentFilter: ExercisePRsIntentFilter = .all
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(scope: ExercisePRsViewScope) {
        self.scope = scope
    }

    public var body: some View {
        VStack(spacing: 0) {
            BRUHeaderBar(
                left: HeaderAction("‹ Back") { dismiss() },
                center: navTitle,
                // The range this screen covers, not a control.
                right: .text("ALL TIME")
            )

            // 3-segment inverted-active intent toggle bar
            intentToggle

            BRUDivider(.ink)

            PRsHost(scope: scope, intentFilter: intentFilter)
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - Intent Toggle

    private var intentToggle: some View {
        // Above default text the segments stack, as in TodayStatStrip, so each
        // label gets the full width: in a third of the 390pt phone,
        // HYPERTROPHY nearly touches its dividers at xLarge and breaks
        // mid-word from xxLarge.
        let isStacked = dynamicTypeSize >= .xLarge
        let segments = isStacked
            ? AnyLayout(VStackLayout(spacing: 0))
            : AnyLayout(HStackLayout(spacing: 0))

        return segments {
            ForEach(Array(ExercisePRsIntentFilter.allCases.enumerated()), id: \.element) { index, filter in
                let isSelected = intentFilter == filter
                let isLast = index == ExercisePRsIntentFilter.allCases.count - 1

                Button {
                    let generator = UISelectionFeedbackGenerator()
                    generator.selectionChanged()
                    intentFilter = filter
                } label: {
                    Text(filter.label.uppercased())
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .foregroundStyle(isSelected ? Color.bruPaper : Color.bruInk)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, minHeight: BRUMetrics.touchTarget)
                        .background(isSelected ? Color.bruInk : Color.clear)
                        // The whole segment is the tap target, not just its
                        // text: a plain button ignores the clear background.
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])

                if !isLast {
                    Rectangle()
                        .fill(Color.bruInk)
                        .frame(width: isStacked ? nil : 1,
                               height: isStacked ? 1 : nil)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay(
            Rectangle()
                .stroke(Color.bruInk, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.bruPaper)
    }

    private var navTitle: String {
        "Personal Records"
    }
}

// MARK: - PRsHost (inner @Query host)

private struct PRsHost: View {
    @Query private var sets: [SetEntry]
    @Environment(\.weightUnit) private var defaultUnit
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let scope: ExercisePRsViewScope
    let intentFilter: ExercisePRsIntentFilter

    init(scope: ExercisePRsViewScope, intentFilter: ExercisePRsIntentFilter) {
        self.scope = scope
        self.intentFilter = intentFilter
        // Broad predicate + Swift post-filter: a multi-level optional chain
        // (entry.sessionExercise?.exercise?.id) inside #Predicate crashes
        // SwiftData at fetch time ("Unsupported function expression"). The
        // scope and the working-set rule (PRDetector.isWorkingSet, which
        // reads the computed setType) are applied in Swift.
        _sets = Query(
            filter: #Predicate<SetEntry> { entry in
                entry.isComplete && !entry.isWarmup
            },
            sort: \SetEntry.completedAt,
            order: .reverse
        )
    }

    /// The scope's working sets, the only sets PR detection counts. With
    /// none, the list shows its empty state rather than empty sections.
    private var scopedSets: [SetEntry] {
        let working = sets.filter { PRDetector.isWorkingSet($0) }
        switch scope {
        case .forExercise(let exerciseID):
            return working.filter { $0.sessionExercise?.exercise?.id == exerciseID }
        case .allExercises:
            return working
        }
    }

    var body: some View {
        let filtered = scopedSets.filter { entry in
            guard let session = entry.sessionExercise?.session else { return false }
            let intent = Intent(rawValue: session.intentRaw) ?? .strength
            return intentFilter.matches(intent: intent)
        }
        Group {
            if filtered.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        prSection(kind: .weight, label: "Weight", sets: filtered)
                        prSection(kind: .reps, label: "Reps", sets: filtered)
                        prSection(kind: .volume, label: "Volume", sets: filtered)
                        prSection(kind: .e1RM, label: "e1RM", sets: filtered)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No PRs yet")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
            Text("Complete a working set to set your first record.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Section

    @ViewBuilder
    private func prSection(kind: PRKind, label: String, sets: [SetEntry]) -> some View {
        BRUSectionHead(label)

        ForEach(bucketsToRender(kind: kind).map { PRBucketID(kind: kind, bucket: $0) }, id: \.self) { id in
            bucketBlock(kind: id.kind, bucket: id.bucket, sets: sets)
        }

        if kind == .e1RM {
            Text("Suppressed for reps above 10.")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .foregroundStyle(Color.bruMuted)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            BRUDivider(.ink)
        }
    }

    private func bucketsToRender(kind: PRKind) -> [RepBucket] {
        if kind == .e1RM {
            return [.strength, .hypertrophy]   // omit .highRep per D-04
        }
        return RepBucket.allCases
    }

    // MARK: - Bucket Block

    @ViewBuilder
    private func bucketBlock(kind: PRKind, bucket: RepBucket, sets: [SetEntry]) -> some View {
        let bucketSets = sets.filter { RepBucket.bucket(for: $0.reps) == bucket }
        let rows = PRBucketRanking.rows(kind: kind, sets: bucketSets)

        if !rows.isEmpty {
            // Bucket sub-header
            Text(bucketLabel(bucket: bucket).uppercased())
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .foregroundStyle(Color.bruMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

            let bucketID = PRBucketID(kind: kind, bucket: bucket)
            ForEach(rows.map { PRRowItem(id: bucketID.rowID($0), entry: $0) }) { item in
                let entry = item.entry
                NavigationLink(
                    value: PRsRouteDestination.session(date: entry.completedAt, setEntryID: entry.id)
                ) {
                    prRow(kind: kind, entry: entry)
                }
                .buttonStyle(.bruRow)
                .accessibilityLabel("\(PRBucketRanking.exerciseName(entry)), \(prKindLabel(kind: kind)), \(PRRowText.spoken(rowText(kind: kind, set: entry)))")
                .accessibilityValue(entry.completedAt.formatted(date: .abbreviated, time: .omitted))

                if entry.id != rows.last?.id {
                    BRUDivider(.hair)
                }
            }
        }
    }

    // MARK: - PR Row (exercise name over the 3-column BRU layout per bru-screens/progress-chart.jsx)

    private func prRow(kind: PRKind, entry: SetEntry) -> some View {
        let isCurrentDay = Calendar.current.isDateInToday(entry.completedAt)
        let rowKindColor: Color = isCurrentDay ? .bruSignal : .bruInk
        let kindLabel = prKindLabel(kind: kind)
        let valueText = rowText(kind: kind, set: entry)
        let dateText = entry.completedAt.formatted(.dateTime.month().day().year()).uppercased()
        // The three columns stack at accessibility sizes, as in
        // TodayStatStrip, and from xxxLarge, where WEIGHT PR and VOLUME PR
        // are wider than the 110pt kind column and would wrap to two lines.
        let isStacked = dynamicTypeSize >= .xxxLarge
        let columns = isStacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 10))

        return VStack(alignment: .leading, spacing: 4) {
            Text(PRBucketRanking.exerciseName(entry))
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
                .frame(maxWidth: .infinity, alignment: .leading)

            columns {
                // (a) Leading ~110pt fixed — kind label
                Text(kindLabel.uppercased())
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .foregroundStyle(rowKindColor)
                    .frame(width: isStacked ? nil : 110, alignment: .leading)

                // (b) Center — PR value display
                BRUDisplay(valueText, size: .medium)
                    .frame(maxWidth: .infinity, alignment: isStacked ? .leading : .center)

                // (c) Trailing — mono date
                Text(dateText)
                    .font(BRUFont.labelMicro)
                    .tracking(0.5)
                    .foregroundStyle(Color.bruMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .background(isCurrentDay ? Color.bruSignal.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
    }

    // MARK: - Kind Label

    private func prKindLabel(kind: PRKind) -> String {
        switch kind {
        case .weight: return "Weight PR"
        case .reps:   return "Top Reps"
        case .volume: return "Volume PR"
        case .e1RM:   return "e1RM PR"
        }
    }

    // MARK: - Bucket Label

    private func bucketLabel(bucket: RepBucket) -> String {
        switch bucket {
        case .strength:    return "1–6 reps"      // en-dash
        case .hypertrophy: return "7–10 reps"     // en-dash
        case .highRep:     return "11+ reps"
        }
    }

    // MARK: - Row Text

    /// The PR's value in the exercise's own unit (`PRRowText`).
    private func rowText(kind: PRKind, set: SetEntry) -> String {
        PRRowText.value(
            kind: kind,
            weight: set.weight,
            reps: set.reps,
            rpe: set.rpe,
            unit: WeightUnit.effective(for: set.sessionExercise?.exercise, default: defaultUnit)
        )
    }
}

// MARK: - Row text

/// A PR row's value, such as "160 lb × 3 @ RPE 9". A set logged without an
/// RPE leaves the RPE out rather than showing a dash.
///
/// No-break spaces hold together the phrases a lifter reads as one, so a
/// narrow column wraps the value between them: "@" never ends a line, and
/// "@ RPE 9", a rep PR's "@ 100 lb" and its "RPE 9" each move to the next
/// line whole. VoiceOver reads the copy with plain spaces (`spoken`).
enum PRRowText {
    static func value(kind: PRKind, weight: Double, reps: Int, rpe: Double?, unit: WeightUnit) -> String {
        let unit = unit.rawValue
        let weightStr = formatWeight(weight)
        let rpePhrase = rpe.map { "RPE\(noBreak)" + String(format: "%g", $0) }
        switch kind {
        case .weight:
            return "\(weightStr) \(unit) × \(reps)" + (rpePhrase.map { " @\(noBreak)\($0)" } ?? "")
        case .reps:
            return "\(BRUCountLabel.text(reps, "rep")) @\(noBreak)\(weightStr)\(noBreak)\(unit)" + (rpePhrase.map { ", \($0)" } ?? "")
        case .volume:
            let tonnage = Int((weight * Double(reps)).rounded())
            return "\(tonnage) \(unit) single-set (\(weightStr) × \(reps))"
        case .e1RM:
            let e1rm = OneRepMax.estimate(weight: weight, reps: reps).map { Int($0.rounded()) } ?? 0
            return "\(e1rm) \(unit) e1RM (\(weightStr) × \(reps))"
        }
    }

    /// `value` as VoiceOver reads it in the row's label: the same copy, with
    /// plain spaces.
    static func spoken(_ value: String) -> String {
        value.replacing(noBreak, with: " ")
    }

    private static let noBreak = "\u{00A0}"

    private static func formatWeight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%g", value)
    }
}

// MARK: - Row ids

/// A bucket within one section. Every section has the same buckets and
/// lists a set once, so ids that pair the kind and bucket with the set stay
/// unique across the whole list.
private struct PRBucketID: Hashable {
    let kind: PRKind
    let bucket: RepBucket

    func rowID(_ entry: SetEntry) -> String {
        "\(kind.rawValue)-\(bucket.rawValue)-\(entry.id.uuidString)"
    }
}

private struct PRRowItem: Identifiable {
    let id: String
    let entry: SetEntry
}

// MARK: - Bucket ranking

/// The rows one bucket lists. Only working sets rank, as in PR detection
/// (`PRDetector.isWorkingSet`). A distinct set is one exercise, weight and
/// reps, kept from when it was first logged (PRDetector's tie rule). The
/// sets are ranked by the bucket's measure across exercises, with at most
/// three rows per exercise. Detecting PRs stays PRDetector's job.
enum PRBucketRanking {
    static let rowsPerExercise = 3

    /// - Parameter sets: one bucket's completed sets, already scoped and
    ///   filtered by intent. Sets PR detection never counts are skipped.
    static func rows(kind: PRKind, sets: [SetEntry]) -> [SetEntry] {
        var firstLogged: [SetKey: SetEntry] = [:]
        for entry in sets where PRDetector.isWorkingSet(entry) {
            let key = SetKey(exercise: exerciseKey(entry), weight: entry.weight, reps: entry.reps)
            if let kept = firstLogged[key], kept.completedAt <= entry.completedAt { continue }
            firstLogged[key] = entry
        }

        let ranked = firstLogged.values
            .compactMap { entry -> (entry: SetEntry, score: Double)? in
                measure(kind, entry).map { (entry, $0) }
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                let lhsTie = tiebreak(kind, lhs.entry)
                let rhsTie = tiebreak(kind, rhs.entry)
                if lhsTie != rhsTie { return lhsTie > rhsTie }
                if lhs.entry.completedAt != rhs.entry.completedAt {
                    return lhs.entry.completedAt < rhs.entry.completedAt
                }
                return lhs.entry.id.uuidString < rhs.entry.id.uuidString
            }

        var shown: [String: Int] = [:]
        return ranked.compactMap { pair in
            let exercise = exerciseKey(pair.entry)
            let count = shown[exercise, default: 0]
            guard count < rowsPerExercise else { return nil }
            shown[exercise] = count + 1
            return pair.entry
        }
    }

    /// The bucket's measure, or nil when the set has none (no e1RM above
    /// 10 reps).
    private static func measure(_ kind: PRKind, _ entry: SetEntry) -> Double? {
        switch kind {
        case .weight: return entry.weight
        case .reps:   return Double(entry.reps)
        case .volume: return entry.weight * Double(entry.reps)
        case .e1RM:   return OneRepMax.estimate(weight: entry.weight, reps: entry.reps)
        }
    }

    /// The exercise's catalog name, so one exercise reads the same in every
    /// row, else the logged name of an exercise no longer in the catalog.
    static func exerciseName(_ entry: SetEntry) -> String {
        guard let logged = entry.sessionExercise else { return "" }
        return logged.exercise?.name ?? logged.displayName
    }

    /// Breaks a tie on the measure: more reps at the same weight, otherwise
    /// more weight.
    private static func tiebreak(_ kind: PRKind, _ entry: SetEntry) -> Double {
        kind == .weight ? Double(entry.reps) : entry.weight
    }

    private static func exerciseKey(_ entry: SetEntry) -> String {
        guard let logged = entry.sessionExercise else { return "" }
        return logged.exercise?.id.uuidString ?? "name:\(logged.displayName)"
    }

    private struct SetKey: Hashable {
        let exercise: String
        let weight: Double
        let reps: Int
    }
}

// MARK: - Placeholder destination for PR row tap

/// Placeholder destination type used by `ExercisePRsView` row taps.
/// v1 has no `CompletedSessionView` — the row pushes a stub `Text`
/// destination. Documented as a v2 follow-up entry point.
public enum PRsRouteDestination: Hashable, Sendable {
    case session(date: Date, setEntryID: UUID)
}

public extension View {
    /// Wires the v1 placeholder destination for ExercisePRsView row taps.
    /// Consumer views (ExercisePRsView, ProgressHomeView) attach this so
    /// the NavigationLink(value: PRsRouteDestination.session(...)) inside
    /// PR rows lands on a readable stub instead of failing silently.
    @ViewBuilder
    func placeholderPRsDestination() -> some View {
        self.navigationDestination(for: PRsRouteDestination.self) { dest in
            switch dest {
            case .session(let date, _):
                VStack(spacing: 0) {
                    BRUHeaderBar(center: "Session")
                    Text("Session of \(date.formatted(.dateTime.month().day().year()))")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(Color.bruPaper.ignoresSafeArea())
                .navigationBarHidden(true)
            }
        }
    }
}
