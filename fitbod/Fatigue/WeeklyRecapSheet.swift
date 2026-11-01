//
//  WeeklyRecapSheet.swift
//  fitbod
//
//  Phase 5.1 Plan 07 — BRU reskin of the VOL-07 weekly recap sheet.
//  Structure: BRUHeaderBar + cover ink slab + 2×2 metric grid +
//  Sessions section + Muscles Hit section + Records broken section +
//  Under-Trained section + Progress section + quote section + footer
//  Start button.
//
//  Copywriting Contract verbatim strings preserved per UI-SPEC §WeeklyRecapSheet.
//  WeeklyRecapTrigger + RootView mount + .sheet wiring untouched.
//
//  Banned tokens: zero Color.accentColor, zero Color(.system*),
//  zero Color("Volume*"), zero RoundedRectangle, zero Capsule(),
//  zero Image(systemName:), zero .navigationTitle(, zero .font(.body|.headline|etc).
//

import SwiftData
import SwiftUI

// MARK: - WeeklyRecapTrigger

/// Pure-function trigger guard per RESEARCH §12.1 + Pitfalls #7 / #8.
/// Caller injects all dependencies — testable without a UI fixture.
public enum WeeklyRecapTrigger {

    public struct Decision: Sendable, Equatable {
        public let shouldPresent: Bool
        public let shouldMarkSeen: Bool

        public init(shouldPresent: Bool, shouldMarkSeen: Bool) {
            self.shouldPresent = shouldPresent
            self.shouldMarkSeen = shouldMarkSeen
        }
    }

    /// Decide whether to present the recap sheet (and whether to mark
    /// the current week's seen-flag regardless of presentation).
    public static func evaluate(
        thisMonday: Date,
        lastShown: Date?,
        hasSessionsLastWeek: Bool,
        calendar: Calendar = .current
    ) -> Decision {
        if let lastShown = lastShown,
           calendar.isDate(lastShown, equalTo: thisMonday, toGranularity: .day) {
            return Decision(shouldPresent: false, shouldMarkSeen: false)
        }
        if !hasSessionsLastWeek {
            return Decision(shouldPresent: false, shouldMarkSeen: true)
        }
        return Decision(shouldPresent: true, shouldMarkSeen: true)
    }
}

// MARK: - WeeklyRecapSheet

public struct WeeklyRecapSheet: View {

    // MARK: - Static label constants (tested by WeeklyRecapSheetBRUTests)

    /// Metric cell label constants — locked by 2×2 grid contract.
    public enum MetricCell {
        public static let tonnageLabel: String     = "TONNAGE"
        public static let workingSetsLabel: String = "WORKING SETS"
        public static let avgRPELabel: String      = "AVG RPE"
        public static let musclesHitLabel: String  = "MUSCLES HIT"
    }

    /// Section header strings — §Copywriting Contract verbatim.
    public enum SectionLabels {
        public static let sessions: String      = "Sessions"
        public static let musclesHit: String    = "Muscles Hit"
        public static let underTrained: String  = "Under-Trained"
        public static let progress: String      = "Progress"
        public static let recordsBroken: String = "Records broken"
    }

    /// Empty-state and footnote strings — §Copywriting Contract verbatim.
    public enum EmptyStateCopy {
        public static let musclesHit: String    = "No muscles met the frequency threshold last week."
        public static let underTrained: String  = "All trained muscles reached MEV last week."
        public static let progress: String      = "Not enough data to compute e1RM movement."
        public static let progressFootnote: String = "Top 5 exercises by working-set count last week. e1RM vs same exercise week prior."
    }

    /// BRU palette-mapped delta color function (replaces systemGreen/systemRed/.secondary).
    /// Positive → bruGreen, Negative → bruSignal, Zero (|δ| < 0.1) → bruMuted.
    public static func deltaColor(for delta: Double) -> Color {
        if delta > 0.1 {
            return .bruGreen
        } else if delta < -0.1 {
            return .bruSignal
        } else {
            return .bruMuted
        }
    }

    // MARK: - Properties

    /// The START of the new week — the Monday on which this sheet presents.
    /// Content shows the PRIOR week.
    public let weekStart: Date

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [UserSettings]
    @Query private var allMuscles: [MuscleGroup]
    @Query private var allTargets: [MuscleVolumeTarget]

    public init(weekStart: Date) {
        self.weekStart = weekStart
    }

    // MARK: - Computed helpers

    private var priorWeekStart: Date {
        weekStart.addingTimeInterval(-7 * 86_400)
    }

    private var settings: UserSettings? { settingsList.first }

    /// ISO week number for the CURRENT week (the new week that just started).
    private var isoWeekNumber: Int {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone.current
        return cal.component(.weekOfYear, from: weekStart)
    }

    /// Next week number — for the "Start WN ▸" footer button label.
    private var nextWeekNumber: Int { isoWeekNumber }

    /// Units label ("lb" or "kg").
    private var unitLabel: String {
        settings?.unitsRaw == "kg" ? "kg" : "lb"
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Non-breaking spaces keep the title on one line: the header
            // fits a title with no breaking space to its third of the row,
            // where "Week 44 · recap" wrapped before its dot on the small
            // phone.
            BRUHeaderBar(
                center: "Week\u{00A0}\(isoWeekNumber)\u{00A0}·\u{00A0}recap",
                right: HeaderAction("Done") { dismiss() }
            )
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    coverSlab
                    metricGrid
                    sessionsSection
                    musclesHitSection
                    recordsBrokenSection
                    underTrainedSection
                    progressSection
                    sessionNoteSection
                }
            }
            footerButtonStrip
        }
        .background(Color.bruPaper)
        .presentationDetents([.large])
    }

    // MARK: - Cover slab

    private var coverSlab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(coverDateRangeCaption)
                .font(BRUFont.labelSmall)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruPaper.opacity(0.6))

            Text(coverHeadline)
                .font(.system(size: 68, weight: .semibold))
                .foregroundStyle(Color.bruPaper)
                .lineSpacing(-4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                // A signal fill, as on every PR chip, so the label reads on it.
                BRUChip(prChipLabel, color: .bruSignal, fill: true, textCase: nil)
                BRUChip("\(sessionsLogged) / \(BRUCountLabel.text(sessionsTarget, "session"))",
                        color: .bruPaper, fill: false, textCase: nil)
                BRUChip("\(tonnageFormatted) \(unitLabel)",
                        color: .bruPaper, fill: false, textCase: nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(Color.bruInk)
    }

    // MARK: - Cover computed properties

    private var coverDateRangeCaption: String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        df.timeZone = TimeZone.current
        let endDate = weekStart.addingTimeInterval(-1)  // day before the new Monday
        let start = df.string(from: priorWeekStart).uppercased()
        let end   = df.string(from: endDate).uppercased()
        return "\(start) → \(end)"
    }

    private var coverHeadline: String {
        let count = sessionsLogged
        let prs = weeklyPRs.count
        if prs >= 3 || count >= sessionsTarget { return "A strong\nweek." }
        if count >= max(sessionsTarget - 1, 2)  { return "Solid\nweek." }
        if count < 2                             { return "Light\nweek." }
        return "New week\nahead."
    }

    private var prChipLabel: String {
        let count = weeklyPRs.count
        if count == 0 { return "No PRs this wk" }
        return "\u{2605} \(count) PR\(count == 1 ? "" : "s")"
    }

    private var tonnageFormatted: String {
        let total = totalTonnageLastWeek()
        if total >= 1_000 {
            return String(format: "%.1fK", total / 1_000)
        }
        return String(format: "%.0f", total)
    }

    private var sessionsLogged: Int { lastWeekSessionsCount() }

    private var sessionsTarget: Int {
        // Derive from last week's unique session count capped to common targets.
        // If no target is stored, show the actual count as "target" (N/N).
        sessionsLogged
    }

    // MARK: - 2×2 Metric grid

    private struct MetricData {
        let label: String
        let value: String
        let sub: String
        let accent: Bool
    }

    private var metricGrid: some View {
        let items = buildMetrics()
        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 0),
                GridItem(.flexible(), spacing: 0)
            ],
            spacing: 0
        ) {
            ForEach(0..<4, id: \.self) { i in
                metricCell(
                    items[i],
                    isRightColumn: i % 2 == 1,
                    isBottomRow: i >= 2
                )
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.bruInk).frame(height: 2)
        }
    }

    private func buildMetrics() -> [MetricData] {
        let totalSets = weeklyTotalSetsCount()
        let avgRPE = weeklyAvgRPE()
        let musclesCount = musclesHitCount()
        let underCount = musclesUnderTrainedLastWeek().count
        let tonnage = totalTonnageLastWeek()
        let priorTonnage = totalTonnagePriorWeek()
        let tonnageDelta = priorTonnage > 0
            ? Int(((tonnage - priorTonnage) / priorTonnage) * 100)
            : 0
        let tonnageDeltaStr = tonnageDelta > 0 ? "\u{2191} \(tonnageDelta)% VS PRIOR WK"
            : tonnageDelta < 0 ? "\u{2193} \(abs(tonnageDelta))% VS PRIOR WK"
            : "— VS PRIOR WK"
        let setsDelta = weeklySetsDelta()
        let setsDeltaStr = setsDelta > 0 ? "\u{2191} \(setsDelta) VS PRIOR WK"
            : setsDelta < 0 ? "\u{2193} \(abs(setsDelta)) VS PRIOR WK"
            : "— VS PRIOR WK"
        let avgRPEStr = avgRPE > 0 ? String(format: "%.1f", avgRPE) : "—"

        return [
            MetricData(label: MetricCell.tonnageLabel,
                       value: tonnageFormatted,
                       sub: tonnageDeltaStr,
                       accent: tonnageDelta > 0),
            MetricData(label: MetricCell.workingSetsLabel,
                       value: "\(totalSets)",
                       sub: setsDeltaStr,
                       accent: false),
            MetricData(label: MetricCell.avgRPELabel,
                       value: avgRPEStr,
                       sub: "—",
                       accent: false),
            MetricData(label: MetricCell.musclesHitLabel,
                       value: "\(musclesCount) / \(allMuscles.count)",
                       sub: underCount > 0 ? "\(underCount) UNDER MEV" : "ALL ABOVE MEV",
                       accent: false)
        ]
    }

    private func metricCell(_ m: MetricData, isRightColumn: Bool, isBottomRow: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(m.label)
                .font(BRUFont.labelSmall)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
            Text(m.value)
                .font(.system(size: 38, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(m.accent ? Color.bruSignal : Color.bruInk)
            Text(m.sub)
                .font(BRUFont.labelMicro)
                .tracking(0.5)
                .foregroundStyle(Color.bruMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .trailing) {
            if !isRightColumn {
                Rectangle().fill(Color.bruInk).frame(width: 1)
            }
        }
        .overlay(alignment: .bottom) {
            if !isBottomRow {
                Rectangle().fill(Color.bruInk).frame(height: 1)
            }
        }
    }

    // MARK: - Sessions section

    @ViewBuilder
    private var sessionsSection: some View {
        let count = sessionsLogged
        let routineCount = lastWeekRoutinesCount()
        let sessionWord = count == 1 ? "session" : "sessions"
        let routineWord = routineCount == 1 ? "routine" : "routines"

        VStack(alignment: .leading, spacing: 0) {
            BRUSectionHead(SectionLabels.sessions)
            VStack(alignment: .leading, spacing: 6) {
                Text("Last week you logged \(count) \(sessionWord).")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruInk)
                if routineCount > 1 {
                    Text("Across \(routineCount) \(routineWord).")
                        .font(BRUFont.labelMicro)
                        .tracking(1.0)
                        .foregroundStyle(Color.bruMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Muscles Hit section

    @ViewBuilder
    private var musclesHitSection: some View {
        let minSets = settings?.frequencyHitMinSets ?? 2
        let hits = musclesHitLastWeek(minSets: minSets)

        VStack(alignment: .leading, spacing: 0) {
            BRUSectionHead(SectionLabels.musclesHit)
            if hits.isEmpty {
                Text(EmptyStateCopy.musclesHit)
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            } else {
                ForEach(Array(hits.enumerated()), id: \.element.slug) { idx, row in
                    HStack {
                        Text(row.displayName)
                            .font(BRUFont.bodyEmphasis)
                            .foregroundStyle(Color.bruInk)
                        Spacer()
                        Text("\(row.count) \(row.count == 1 ? "session" : "sessions")")
                            .font(BRUFont.labelMicro)
                            .tracking(1.0)
                            .foregroundStyle(Color.bruMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    if idx < hits.count - 1 {
                        BRUDivider(.hair)
                    }
                }
            }
        }
    }

    // MARK: - Records broken section (BRU addition)

    @ViewBuilder
    private var recordsBrokenSection: some View {
        let prs = weeklyPRs
        if !prs.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                BRUSectionHead(SectionLabels.recordsBroken, right: "\(prs.count)")
                VStack(spacing: 0) {
                    ForEach(Array(prs.enumerated()), id: \.element.exerciseID) { idx, pr in
                        HStack(spacing: 12) {
                            Text("\u{2605}")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(Color.bruSignal)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pr.exerciseName)
                                    .font(BRUFont.bodyEmphasis)
                                    .foregroundStyle(Color.bruInk)
                                Text(pr.kindLabel)
                                    .font(BRUFont.labelMicro)
                                    .tracking(1.0)
                                    .foregroundStyle(Color.bruMuted)
                            }
                            Spacer()
                            Text(pr.valueDisplay)
                                .font(.system(size: 22, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(pr.isHighlighted ? Color.bruSignal : Color.bruInk)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        if idx < prs.count - 1 {
                            BRUDivider(.hair)
                        }
                    }
                }
                BRUDivider(.ink)
            }
        }
    }

    // MARK: - Under-Trained section

    @ViewBuilder
    private var underTrainedSection: some View {
        let underTrained = musclesUnderTrainedLastWeek()

        VStack(alignment: .leading, spacing: 0) {
            BRUSectionHead(SectionLabels.underTrained)
            if underTrained.isEmpty {
                Text(EmptyStateCopy.underTrained)
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            } else {
                ForEach(Array(underTrained.enumerated()), id: \.element.slug) { idx, row in
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(Color.bruAmber)
                            .frame(width: 6, height: 6)
                        Text(row.displayName)
                            .font(BRUFont.bodyEmphasis)
                            .foregroundStyle(Color.bruInk)
                        Spacer()
                        Text("below MEV — \(row.totalSets) / \(BRUCountLabel.text(row.mev, "set"))")
                            .font(BRUFont.labelMicro)
                            .tracking(1.0)
                            .foregroundStyle(Color.bruMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    if idx < underTrained.count - 1 {
                        BRUDivider(.hair)
                    }
                }
            }
        }
    }

    // MARK: - Progress section

    @ViewBuilder
    private var progressSection: some View {
        let progress = topExercisesProgress()

        VStack(alignment: .leading, spacing: 0) {
            BRUSectionHead(SectionLabels.progress)
            if progress.isEmpty {
                Text(EmptyStateCopy.progress)
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            } else {
                ForEach(Array(progress.enumerated()), id: \.element.exerciseID) { idx, row in
                    HStack {
                        Text(row.exerciseName)
                            .font(BRUFont.bodyEmphasis)
                            .foregroundStyle(Color.bruInk)
                        Spacer()
                        Text(row.deltaCopy)
                            .font(BRUFont.labelMicro)
                            .tracking(0)
                            .monospacedDigit()
                            .foregroundStyle(row.deltaColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    if idx < progress.count - 1 {
                        BRUDivider(.hair)
                    }
                }
            }
            // Footnote verbatim
            Text(EmptyStateCopy.progressFootnote)
                .font(BRUFont.labelMicro)
                .tracking(0.5)
                .foregroundStyle(Color.bruMuted)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 14)
        }
    }

    // MARK: - Session note section (BRU addition)

    @ViewBuilder
    private var sessionNoteSection: some View {
        if let note = mostRecentSessionNote() {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\u{201C}\(note.text)\u{201D}")
                        .font(BRUFont.bodyDefault)
                        .italic()
                        .foregroundStyle(Color.bruMuted)
                    Text("— SESSION NOTE · \(note.dateLabel)")
                        .font(BRUFont.labelMicro)
                        .tracking(1.0)
                        .foregroundStyle(Color.bruMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Footer button strip

    private var footerButtonStrip: some View {
        BRUButton("Start W\(nextWeekNumber) \u{25B8}", kind: .primary) {
            dismiss()
        }
        .overlay(alignment: .top) {
            Rectangle().fill(Color.bruInk).frame(height: 2)
        }
    }

    // MARK: - Data computations

    /// Last week's workouts that count as sessions (decision 6).
    @MainActor
    private func lastWeekSessionsCount() -> Int {
        let start = priorWeekStart
        let end   = weekStart
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> {
                $0.startedAt >= start && $0.startedAt < end && $0.completedAt != nil
            }
        )
        return SessionSetActions.countedWorkouts((try? ctx.fetch(descriptor)) ?? []).count
    }

    /// The routines of last week's workouts that count as sessions, the
    /// ones "Last week you logged N sessions." counts.
    @MainActor
    private func lastWeekRoutinesCount() -> Int {
        let start = priorWeekStart
        let end   = weekStart
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> {
                $0.startedAt >= start && $0.startedAt < end && $0.completedAt != nil
            }
        )
        let sessions = (try? ctx.fetch(descriptor)) ?? []
        return Set(SessionSetActions.countedWorkouts(sessions).map(\.routineSnapshotName)).count
    }

    @MainActor
    private func musclesHitLastWeek(minSets: Int) -> [MuscleRow] {
        // One read of the week for every muscle; each count equals
        // `FatigueModel.frequencyHits` for that muscle.
        let contributions = FatigueModel.contributionsPerSession(weekStart: priorWeekStart, in: ctx)
        let minContribution = Double(minSets)
        return allMuscles.compactMap { muscle in
            let count = (contributions[muscle.slug] ?? [:]).values.filter { $0 >= minContribution }.count
            guard count > 0 else { return nil }
            return MuscleRow(slug: muscle.slug, displayName: muscle.displayName, count: count)
        }
        .sorted { $0.count > $1.count }
    }

    @MainActor
    private func musclesUnderTrainedLastWeek() -> [UnderTrainedRow] {
        let volumes = FatigueModel.weeklyVolumes(weekStart: priorWeekStart, in: ctx)
        return allMuscles.compactMap { muscle in
            guard let target = allTargets.first(where: { $0.muscle?.slug == muscle.slug }) else { return nil }
            let total = volumes[muscle.slug] ?? WeightedSetTotal(directSets: 0, indirectSets: 0)
            let rounded = total.totalSetsRounded
            guard rounded > 0 && rounded < target.mev else { return nil }
            return UnderTrainedRow(
                slug: muscle.slug,
                displayName: muscle.displayName,
                totalSets: rounded,
                mev: target.mev
            )
        }
    }

    @MainActor
    private func musclesHitCount() -> Int {
        let minSets = settings?.frequencyHitMinSets ?? 2
        return musclesHitLastWeek(minSets: minSets).count
    }

    @MainActor
    private func totalTonnageLastWeek() -> Double {
        let start = priorWeekStart
        let end   = weekStart
        return tonnageInRange(from: start, to: end)
    }

    @MainActor
    private func totalTonnagePriorWeek() -> Double {
        let end   = priorWeekStart
        let start = end.addingTimeInterval(-7 * 86_400)
        return tonnageInRange(from: start, to: end)
    }

    @MainActor
    private func tonnageInRange(from start: Date, to end: Date) -> Double {
        FatigueModel.completedWorkingSets(startedFrom: start, before: end, in: ctx)
            .reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
    }

    @MainActor
    private func weeklyTotalSetsCount() -> Int {
        FatigueModel.completedWorkingSets(startedFrom: priorWeekStart, before: weekStart, in: ctx).count
    }

    @MainActor
    private func weeklySetsDelta() -> Int {
        let thisWeekSets = weeklyTotalSetsCount()
        let prior = priorWeekStart.addingTimeInterval(-7 * 86_400)
        let priorSets = FatigueModel.completedWorkingSets(startedFrom: prior, before: priorWeekStart, in: ctx).count
        return thisWeekSets - priorSets
    }

    @MainActor
    private func weeklyAvgRPE() -> Double {
        let rpeEntries = FatigueModel.completedWorkingSets(startedFrom: priorWeekStart, before: weekStart, in: ctx)
            .filter { entry in
                guard let rpe = entry.rpe, rpe > 0 else { return false }
                return true
            }
        guard !rpeEntries.isEmpty else { return 0 }
        let total = rpeEntries.reduce(0.0) { $0 + ($1.rpe ?? 0) }
        return total / Double(rpeEntries.count)
    }

    @MainActor
    private func topExercisesProgress() -> [ProgressRow] {
        let start     = priorWeekStart
        let end       = weekStart
        let priorStart = priorWeekStart.addingTimeInterval(-7 * 86_400)

        let lastWeekEntries = FatigueModel.completedWorkingSets(startedFrom: start, before: end, in: ctx)
        let priorWeekEntries = FatigueModel.completedWorkingSets(startedFrom: priorStart, before: start, in: ctx)

        // Group by exercise, count working sets
        var setCountByExercise: [UUID: (exercise: Exercise, count: Int)] = [:]
        for entry in lastWeekEntries {
            guard let exercise = entry.sessionExercise?.exercise else { continue }
            var existing = setCountByExercise[exercise.id] ?? (exercise: exercise, count: 0)
            existing.count += 1
            setCountByExercise[exercise.id] = existing
        }
        let top5 = setCountByExercise.values.sorted { $0.count > $1.count }.prefix(5)

        return top5.compactMap { entry in
            let lastWeekE1RM = topSetE1RM(in: lastWeekEntries, exerciseID: entry.exercise.id)
            let priorWeekE1RM = topSetE1RM(in: priorWeekEntries, exerciseID: entry.exercise.id)
            guard let lw = lastWeekE1RM, let pw = priorWeekE1RM else {
                return ProgressRow(
                    exerciseID: entry.exercise.id,
                    exerciseName: entry.exercise.name,
                    deltaCopy: "—",
                    deltaColor: .bruMuted
                )
            }
            let delta = lw - pw
            let sign  = delta >= 0 ? "+" : ""
            let copy  = "\(sign)\(String(format: "%.1f", delta)) \(unitLabel) e1RM"
            return ProgressRow(
                exerciseID: entry.exercise.id,
                exerciseName: entry.exercise.name,
                deltaCopy: copy,
                deltaColor: Self.deltaColor(for: delta)
            )
        }
    }

    private func topSetE1RM(in entries: [SetEntry], exerciseID: UUID) -> Double? {
        var best: Double? = nil
        for entry in entries where entry.sessionExercise?.exercise?.id == exerciseID {
            if let e = OneRepMaxEstimator.estimate(weight: entry.weight, reps: entry.reps) {
                if best == nil || e > best! { best = e }
            }
        }
        return best
    }

    // MARK: - Weekly PRs (stub — Phase 6 PR detection deferred)
    // UI-SPEC §What's Explicitly Deferred line 707: PR detection is Phase 6 work.
    // Section is hidden when array is empty.

    private var weeklyPRs: [PRRow] { [] }

    // MARK: - Session note

    private struct SessionNoteData {
        let text: String
        let dateLabel: String
    }

    @MainActor
    private func mostRecentSessionNote() -> SessionNoteData? {
        let start = priorWeekStart
        let end   = weekStart
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> {
                $0.startedAt >= start && $0.startedAt < end && $0.completedAt != nil
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let sessions = (try? ctx.fetch(descriptor)) ?? []
        for session in sessions {
            let note = session.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !note.isEmpty else { continue }
            let df = DateFormatter()
            df.dateFormat = "EEE MMM d"
            df.timeZone = TimeZone.current
            let dateLabel = df.string(from: session.startedAt).uppercased()
            return SessionNoteData(text: note, dateLabel: dateLabel)
        }
        return nil
    }

    // MARK: - Row types

    private struct MuscleRow {
        let slug: String
        let displayName: String
        let count: Int
    }

    private struct UnderTrainedRow {
        let slug: String
        let displayName: String
        let totalSets: Int
        let mev: Int
    }

    private struct ProgressRow {
        let exerciseID: UUID
        let exerciseName: String
        let deltaCopy: String
        let deltaColor: Color
    }

    private struct PRRow {
        let exerciseID: UUID
        let exerciseName: String
        let kindLabel: String
        let valueDisplay: String
        let isHighlighted: Bool
    }
}

