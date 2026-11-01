//
//  PerMuscleDetailView.swift
//  fitbod
//
//  Phase 5.1-06 — BRU reskin of the per-muscle drill-down.
//  Replaces the List(.insetGrouped) host with BRUHeaderBar +
//  ScrollView + LazyVStack per UI-SPEC v2 and 05-UI-SPEC
//  §Copywriting Contract verbatim copy.
//
//  Four sections (UI-SPEC §PerMuscleDetailView):
//    1. This Week — total sets + BRUChip zone badge + delta line
//    2. Contributing Exercises — DESC by weighted-set count, ties by name
//    3. Frequency This Week — sessions ≥ frequencyHitMinSets
//    4. Adjust Targets — "Edit volume targets" row (▾/▴) → MuscleVolumeTargetStepper inline
//
//  BRU contract — ZERO banned tokens:
//    No Color.accentColor, Color(.system*), RoundedRectangle(cornerRadius:),
//    Capsule(), .navigationTitle(, List(.insetGrouped), Image(systemName:)
//    No .font(.body|.headline|.caption|.subheadline|.footnote|.title)
//
//  Data layer UNCHANGED from Phase 5 baseline:
//    @Query<MuscleGroup>(filter: #Predicate { $0.slug == muscleSlug })
//    @Query<MuscleVolumeTarget>
//    @Environment(\.modelContext)
//

import SwiftData
import SwiftUI

public struct PerMuscleDetailView: View {
    public let muscleSlug: String

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query private var allMuscles: [MuscleGroup]
    @Query private var allTargets: [MuscleVolumeTarget]
    @Query private var settingsList: [UserSettings]
    @State private var adjustTargetsExpanded: Bool = false

    public init(muscleSlug: String) {
        self.muscleSlug = muscleSlug
    }

    // MARK: - Data layer computed properties (PRESERVED verbatim)

    private var muscle: MuscleGroup? {
        allMuscles.first { $0.slug == muscleSlug }
    }

    private var persistedTarget: MuscleVolumeTarget? {
        allTargets.first { $0.muscle?.slug == muscleSlug }
    }

    private var weekStart: Date {
        let weekStartsMonday = settingsList.first?.weekStartsMonday ?? true
        return Date.now.mondayAtMidnightForToday(weekStartsMonday: weekStartsMonday)
    }

    // MARK: - Zone chip helpers (inline — mirrors MuscleVolumeBar mapping)

    private func zoneChipLabel(for zone: VolumeZone, totalSets: Int, mav: Int) -> String {
        switch zone {
        case .belowMEV:
            return "UNDER MEV"
        case .productive:
            let headroom = mav - totalSets
            return headroom >= 2 ? "ADD A SET" : "HOLD"
        case .nearMRV:
            return "NEAR MRV — DELOAD"
        case .overMRV:
            return "OVER MRV"
        }
    }

    private func zoneChipColor(for zone: VolumeZone, totalSets: Int, mav: Int) -> Color {
        switch zone {
        case .belowMEV:
            return .bruAmber
        case .productive:
            let headroom = mav - totalSets
            return headroom >= 2 ? .bruGreen : .bruInk
        case .nearMRV:
            return .bruSignal
        case .overMRV:
            return .bruSignal
        }
    }

    private func zoneChipFill(for zone: VolumeZone) -> Bool {
        switch zone {
        case .belowMEV:   return true
        case .productive: return false
        case .nearMRV:    return true
        case .overMRV:    return true
        }
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            BRUHeaderBar(
                left: HeaderAction("‹ Back") { dismiss() },
                center: muscle?.displayName ?? muscleSlug.capitalized,
                right: nil
            )

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let muscle = muscle {
                        thisWeekSection(muscle: muscle)
                        BRUDivider(.ink)
                        contributingExercisesSection(muscle: muscle)
                        BRUDivider(.ink)
                        frequencySection(muscle: muscle)
                        BRUDivider(.ink)
                        adjustTargetsSection(muscle: muscle)
                    } else {
                        Text("Muscle '\(muscleSlug)' not found.")
                            .font(BRUFont.bodyDefault)
                            .foregroundStyle(Color.bruMuted)
                            .padding(16)
                    }
                }
            }
        }
        .background(Color.bruPaper)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Section 1: This Week

    @ViewBuilder
    private func thisWeekSection(muscle: MuscleGroup) -> some View {
        let total = FatigueModel.weeklyVolume(muscleSlug: muscleSlug, weekStart: weekStart, in: ctx)
        let delta = FatigueModel.weekOverWeekDelta(muscleSlug: muscleSlug, weekStart: weekStart, in: ctx)
        let effectiveTarget = persistedTarget ?? transientTarget(for: muscle)
        let zone = FatigueModel.volumeZone(
            currentSets: total.totalSetsRounded,
            mev: effectiveTarget.mev,
            mav: effectiveTarget.mav,
            mrv: effectiveTarget.mrv
        )
        let chipLabel = zoneChipLabel(for: zone, totalSets: total.totalSetsRounded, mav: effectiveTarget.mav)
        let chipColor = zoneChipColor(for: zone, totalSets: total.totalSetsRounded, mav: effectiveTarget.mav)
        let chipFill = zoneChipFill(for: zone)

        VStack(alignment: .leading, spacing: 0) {
            BRUSectionHead("This Week")
            HStack {
                Text(BRUCountLabel.text(total.totalSetsRounded, "set"))
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruInk)
                Spacer()
                BRUChip(chipLabel, color: chipColor, fill: chipFill)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Text(delta.deltaCopy)
                .font(BRUFont.labelMicro)
                .tracking(1.0)
                .foregroundStyle(Color.bruMuted)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
    }

    // MARK: - Section 2: Contributing Exercises

    @ViewBuilder
    private func contributingExercisesSection(muscle: MuscleGroup) -> some View {
        let contributors = computeContributingExercises()

        VStack(alignment: .leading, spacing: 0) {
            BRUSectionHead("Contributing Exercises")
            if contributors.isEmpty {
                Text("No exercises contributed to \(muscle.displayName) this week.")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .padding(16)
            } else {
                ForEach(contributors, id: \.exerciseID) { row in
                    HStack {
                        Text(row.exerciseName)
                            .font(BRUFont.bodyEmphasis)
                            .foregroundStyle(Color.bruInk)
                        Spacer()
                        Text(row.trailingCopy)
                            .font(BRUFont.labelMicro)
                            .tracking(1.0)
                            .foregroundStyle(Color.bruMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    BRUDivider(.hair)
                }
            }
        }
    }

    // MARK: - Section 3: Frequency This Week

    @ViewBuilder
    private func frequencySection(muscle: MuscleGroup) -> some View {
        let minSets = settingsList.first?.frequencyHitMinSets ?? 2
        let hits = FatigueModel.frequencyHits(
            muscleSlug: muscleSlug,
            weekStart: weekStart,
            minContribution: Double(minSets),
            in: ctx
        )
        let frequencyCopy = "\(BRUCountLabel.text(hits, "session")) with ≥\(BRUCountLabel.text(minSets, "set"))"

        VStack(alignment: .leading, spacing: 0) {
            BRUSectionHead("Frequency This Week")
            Text(frequencyCopy)
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruInk)
                .padding(16)
        }
    }

    // MARK: - Section 4: Adjust Targets

    @ViewBuilder
    private func adjustTargetsSection(muscle: MuscleGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            BRUSectionHead("Adjust Targets")
            if let target = persistedTarget {
                // Opens the targets in place, so it carries the expand
                // marker, not a navigation "›".
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        adjustTargetsExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Edit volume targets")
                            .font(BRUFont.bodyEmphasis)
                            .foregroundStyle(Color.bruInk)
                        Spacer(minLength: 8)
                        Text(adjustTargetsExpanded ? "▴" : "▾")
                            .font(BRUFont.labelSmall)
                            .foregroundStyle(Color.bruMuted)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(adjustTargetsExpanded ? "Expanded" : "Collapsed")

                if adjustTargetsExpanded {
                    MuscleVolumeTargetStepper(target: target, showsResetButton: true)
                        .padding(.horizontal, 32)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                }
            } else {
                BRUButton("CREATE TARGET ROW", kind: .primary) {
                    createPersistentTarget(for: muscle)
                }
                .padding(16)
            }
        }
    }

    // MARK: - Helpers (PRESERVED verbatim from Phase 5 baseline)

    private func transientTarget(for muscle: MuscleGroup) -> MuscleVolumeTarget {
        let landmark = RPVolumeLandmarks.landmark(for: muscle.slug)
        let t = MuscleVolumeTarget()
        t.muscle = muscle
        t.mv = landmark.mv
        t.mev = landmark.mev
        t.mav = landmark.mav
        t.mrv = landmark.mrv
        return t
    }

    @MainActor
    private func createPersistentTarget(for muscle: MuscleGroup) {
        let landmark = RPVolumeLandmarks.landmark(for: muscle.slug)
        let t = MuscleVolumeTarget()
        t.muscle = muscle
        t.mv = landmark.mv
        t.mev = landmark.mev
        t.mav = landmark.mav
        t.mrv = landmark.mrv
        t.userEdited = false
        ctx.insert(t)
        try? ctx.save()
    }

    @MainActor
    private func computeContributingExercises() -> [ContributingExercise] {
        let weekEnd = weekStart.addingTimeInterval(7 * 86_400)
        let targetSlug = muscleSlug

        let filtered = FatigueModel.completedWorkingSets(startedFrom: weekStart, before: weekEnd, in: ctx)

        var contribByExercise: [UUID: (name: String, direct: Double, indirect: Double)] = [:]
        for entry in filtered {
            guard let exercise = entry.sessionExercise?.exercise else { continue }
            let exID = exercise.id
            let stimuli = exercise.muscleStimuli ?? []
            for stim in stimuli where stim.muscle?.slug == targetSlug {
                var existing = contribByExercise[exID] ?? (name: exercise.name, direct: 0, indirect: 0)
                switch stim.role {
                case "primary":   existing.direct += stim.weight
                case "secondary": existing.indirect += stim.weight
                default:          break
                }
                contribByExercise[exID] = existing
            }
        }

        return contribByExercise.map { id, value in
            ContributingExercise(exerciseID: id, exerciseName: value.name, direct: value.direct, indirect: value.indirect)
        }
        .sorted(by: ContributingExercise.precedes)
    }
}

/// One row in the "Contributing Exercises" section. Internal so
/// ContributingExercisesOrderTests can build rows and order them.
struct ContributingExercise: Hashable {
    let exerciseID: UUID
    let exerciseName: String
    let totalWeightedSets: Double
    let trailingCopy: String

    /// A row from an exercise's direct and indirect weighted sets this
    /// week: "3 sets", or "3 sets (2 direct)" when some are indirect.
    init(exerciseID: UUID, exerciseName: String, direct: Double, indirect: Double) {
        let totalSets = Int((direct + indirect).rounded())
        let directSets = Int(direct.rounded())
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        totalWeightedSets = direct + indirect
        if indirect > 0 {
            trailingCopy = "\(BRUCountLabel.text(totalSets, "set")) (\(directSets) direct)"
        } else {
            trailingCopy = BRUCountLabel.text(totalSets, "set")
        }
    }

    /// Most weighted sets first. The rows come from a dictionary, whose
    /// order can change from one render to the next, so rows with exactly
    /// the same weighted sets go by name, then by id (T109). Rows that only
    /// read the same count, such as 3 and 2.5 weighted sets, keep their
    /// weighted order (tradeoffs.md "Contributing exercises order").
    static func precedes(_ lhs: Self, _ rhs: Self) -> Bool {
        if lhs.totalWeightedSets != rhs.totalWeightedSets {
            return lhs.totalWeightedSets > rhs.totalWeightedSets
        }
        switch lhs.exerciseName.localizedStandardCompare(rhs.exerciseName) {
        case .orderedAscending: return true
        case .orderedDescending: return false
        case .orderedSame: return lhs.exerciseID.uuidString < rhs.exerciseID.uuidString
        }
    }
}
