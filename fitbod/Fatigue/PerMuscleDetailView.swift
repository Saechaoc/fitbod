//
//  PerMuscleDetailView.swift
//  fitbod
//
//  Phase 5 VOL-05 + VOL-06 + SET-05 inline entry point — per-muscle
//  drill-down from heatmap tap OR volume-bar tap on Today tab.
//
//  Four sections per CONTEXT Claude's Discretion + UI-SPEC §
//  Copywriting Contract verbatim:
//    1. This Week — total sets + zone badge + delta line
//    2. Contributing Exercises — DESC by weighted-set count this week
//    3. Frequency This Week — sessions hitting ≥frequencyHitMinSets
//    4. Adjust Targets — DisclosureGroup wrapping MuscleVolumeTargetStepper
//

import SwiftData
import SwiftUI

public struct PerMuscleDetailView: View {
    public let muscleSlug: String

    @Environment(\.modelContext) private var ctx
    @Query private var allMuscles: [MuscleGroup]
    @Query private var allTargets: [MuscleVolumeTarget]
    @Query private var settingsList: [UserSettings]
    @State private var adjustTargetsExpanded: Bool = false
    @State private var fallbackTarget: MuscleVolumeTarget? = nil

    public init(muscleSlug: String) {
        self.muscleSlug = muscleSlug
    }

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

    public var body: some View {
        List {
            if let muscle = muscle {
                thisWeekSection(muscle: muscle)
                contributingExercisesSection(muscle: muscle)
                frequencyThisWeekSection(muscle: muscle)
                adjustTargetsSection(muscle: muscle)
            } else {
                Text("Muscle '\(muscleSlug)' not found.")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(muscle?.displayName ?? muscleSlug.capitalized)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - This Week

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

        Section("This Week") {
            HStack {
                Text("\(total.totalSetsRounded) sets")
                    .font(.body)
                Spacer()
                Text(zoneAbbreviation(zone))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(zoneColor(zone).opacity(0.15))
                    .foregroundStyle(zoneColor(zone))
                    .clipShape(Capsule())
            }
            Text(delta.deltaCopy)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Contributing Exercises

    @ViewBuilder
    private func contributingExercisesSection(muscle: MuscleGroup) -> some View {
        let contributions = computeContributingExercises()

        Section("Contributing Exercises") {
            if contributions.isEmpty {
                Text("No exercises contributed to \(muscle.displayName) this week.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(contributions, id: \.exerciseID) { contribution in
                    HStack {
                        Text(contribution.exerciseName.capitalized)
                            .font(.body)
                        Spacer()
                        Text(contribution.trailingCopy)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Frequency This Week

    @ViewBuilder
    private func frequencyThisWeekSection(muscle: MuscleGroup) -> some View {
        let minSets = settingsList.first?.frequencyHitMinSets ?? 2
        let hits = FatigueModel.frequencyHits(
            muscleSlug: muscleSlug,
            weekStart: weekStart,
            minContribution: Double(minSets),
            in: ctx
        )

        Section("Frequency This Week") {
            Text(frequencyCopy(hits: hits, minSets: minSets))
                .font(.body)
        }
    }

    // MARK: - Adjust Targets

    @ViewBuilder
    private func adjustTargetsSection(muscle: MuscleGroup) -> some View {
        Section("Adjust Targets") {
            DisclosureGroup(
                isExpanded: $adjustTargetsExpanded,
                content: {
                    if let target = persistedTarget {
                        MuscleVolumeTargetStepper(target: target)
                            .padding(.vertical, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No persisted target — using RP defaults.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Create target row") {
                                createPersistentTarget(for: muscle)
                            }
                            .foregroundStyle(Color.accentColor)
                        }
                    }
                },
                label: {
                    Text("Adjust targets")
                        .foregroundStyle(Color.accentColor)
                }
            )
        }
    }

    // MARK: - Helpers

    private func zoneAbbreviation(_ zone: VolumeZone) -> String {
        switch zone {
        case .belowMEV:   return "Below MEV"
        case .productive: return "Productive"
        case .nearMRV:    return "Near MRV"
        case .overMRV:    return "Over MRV"
        }
    }

    private func zoneColor(_ z: VolumeZone) -> Color {
        switch z {
        case .belowMEV:   return Color("VolumeBelowMEVGray")
        case .productive: return Color("VolumeProductiveGreen")
        case .nearMRV:    return Color("VolumeNearMRVAmber")
        case .overMRV:    return Color("VolumeOverMRVRed")
        }
    }

    private func frequencyCopy(hits: Int, minSets: Int) -> String {
        let sessionsWord = hits == 1 ? "session" : "sessions"
        return "\(hits) \(sessionsWord) with ≥\(minSets) sets"
    }

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
        let workingKinds: Set<String> = ["working", "drop", "failure", "rest_pause"]
        let weekEnd = weekStart.addingTimeInterval(7 * 86_400)
        let targetSlug = muscleSlug

        // Pitfall #1 + #3: keep predicate gates simple, run multi-hop
        // traversal + setTypeRaw containment in Swift.
        let descriptor = FetchDescriptor<SetEntry>(
            predicate: #Predicate<SetEntry> { entry in
                entry.isComplete == true && entry.isWarmup == false
            }
        )
        let rows = (try? ctx.fetch(descriptor)) ?? []
        let filtered = rows.filter { entry in
            guard workingKinds.contains(entry.setTypeRaw) else { return false }
            guard let started = entry.sessionExercise?.session?.startedAt else { return false }
            return started >= weekStart && started < weekEnd
        }

        var contribByExercise: [UUID: (name: String, direct: Double, indirect: Double)] = [:]
        for entry in filtered {
            guard let exercise = entry.sessionExercise?.exercise else { continue }
            let exID = exercise.id
            let stimuli = exercise.muscleStimuli ?? []
            for stim in stimuli where stim.muscle?.slug == targetSlug {
                var existing = contribByExercise[exID] ?? (name: exercise.canonicalName, direct: 0, indirect: 0)
                switch stim.role {
                case "primary":   existing.direct += stim.weight
                case "secondary": existing.indirect += stim.weight
                default:          break
                }
                contribByExercise[exID] = existing
            }
        }

        return contribByExercise.map { id, value in
            let totalSets = Int((value.direct + value.indirect).rounded())
            let directSets = Int(value.direct.rounded())
            let trailing: String
            if value.indirect > 0 {
                trailing = "\(totalSets) sets (\(directSets) direct)"
            } else {
                trailing = "\(totalSets) sets"
            }
            return ContributingExercise(
                exerciseID: id,
                exerciseName: value.name,
                totalWeightedSets: value.direct + value.indirect,
                trailingCopy: trailing
            )
        }
        .sorted { $0.totalWeightedSets > $1.totalWeightedSets }
    }
}

/// One row in the "Contributing Exercises" section.
private struct ContributingExercise: Hashable {
    let exerciseID: UUID
    let exerciseName: String
    let totalWeightedSets: Double
    let trailingCopy: String
}
