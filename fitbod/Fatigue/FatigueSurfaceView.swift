//
//  FatigueSurfaceView.swift
//  fitbod
//
//  Phase 5 — Today-tab host for the per-muscle volume bars (VOL-04) and
//  the body silhouette heatmap (VOL-05; Wave 4 plan 05). @Query-driven
//  per FOUND-06 (MV-VM-lite — no parallel view model wraps the @Query
//  per Pitfall #8 corollary).
//
//  FatigueModel.weeklyVolume is called inline in body — D-04 on-demand
//  reads, NO snapshot entity.
//
//  Navigation: parent passes a `Binding<NavigationPath>` so heatmap
//  region taps + volume bar taps both append `MuscleSlugRoute.detail`
//  onto the same Today-tab NavigationStack — single drilldown
//  destination per VOL-05.
//

import SwiftData
import SwiftUI

/// Navigation route surfaced to the parent NavigationStack. Hashable
/// + Sendable so SwiftUI's `.navigationDestination(for:)` resolves.
public enum MuscleSlugRoute: Hashable, Sendable {
    case detail(String)
}

public struct FatigueSurfaceView: View {
    @Environment(\.modelContext) private var ctx

    @Query private var allMuscles: [MuscleGroup]
    @Query private var allTargets: [MuscleVolumeTarget]
    @Query private var settingsList: [UserSettings]

    /// Phase 5 plan 04 — flips the per-bar amber ring overlay on when
    /// `DeloadAdvisor.evaluate` returns non-nil.
    public var isAdvisoryActive: Bool = false

    /// Phase 5 plan 05 — parent's NavigationPath so heatmap + bar
    /// taps push onto the same stack. Default `.constant(...)` lets
    /// previews + lightweight call sites compile without wiring.
    @Binding public var navigationPath: NavigationPath

    @State private var selectedSide: BodySide = .front

    public init(
        isAdvisoryActive: Bool = false,
        navigationPath: Binding<NavigationPath> = .constant(NavigationPath())
    ) {
        self.isAdvisoryActive = isAdvisoryActive
        self._navigationPath = navigationPath
    }

    private var weekStart: Date {
        let weekStartsMonday = settingsList.first?.weekStartsMonday ?? true
        return Date.now.mondayAtMidnightForToday(weekStartsMonday: weekStartsMonday)
    }

    /// Muscles with non-zero weekly volume OR a non-zero MEV target.
    /// Sorted alphabetically by displayName for stable ordering.
    private var visibleMuscles: [MuscleGroup] {
        let withVolume = allMuscles.filter { muscle in
            let total = FatigueModel.weeklyVolume(muscleSlug: muscle.slug, weekStart: weekStart, in: ctx)
            if total.totalSetsRounded >= 1 { return true }
            if let row = allTargets.first(where: { $0.muscle?.slug == muscle.slug }), row.mev > 0 {
                return true
            }
            return false
        }
        return withVolume.sorted { $0.displayName < $1.displayName }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            volumeSection
            heatmapSection
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Volume This Week")
                .font(.headline)

            if visibleMuscles.isEmpty {
                VStack(spacing: 8) {
                    Text("No sets logged this week")
                        .font(.headline)
                    Text("Log a workout to see your weekly volume.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(visibleMuscles, id: \.persistentModelID) { muscle in
                        let target = targetFor(muscle)
                        let total = FatigueModel.weeklyVolume(
                            muscleSlug: muscle.slug,
                            weekStart: weekStart,
                            in: ctx
                        )
                        let delta = FatigueModel.weekOverWeekDelta(
                            muscleSlug: muscle.slug,
                            weekStart: weekStart,
                            in: ctx
                        )
                        MuscleVolumeBar(
                            muscle: muscle,
                            target: target,
                            total: total,
                            delta: delta,
                            isAdvisoryActive: isAdvisoryActive,
                            onTap: { tappedMuscle in
                                navigationPath.append(MuscleSlugRoute.detail(tappedMuscle.slug))
                            }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Muscle Heatmap")
                .font(.headline)

            Picker("Heatmap view", selection: $selectedSide) {
                Text("Front").tag(BodySide.front)
                Text("Back").tag(BodySide.back)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Heatmap view: \(selectedSide.rawValue)")
            .accessibilityHint("Toggles between front and back muscle view.")

            BodySilhouetteView(
                side: selectedSide,
                zoneByMuscleSlug: computeZoneByMuscleSlug(),
                muscleDisplayNames: muscleDisplayNames(),
                onTap: { slug in
                    navigationPath.append(MuscleSlugRoute.detail(slug))
                }
            )
        }
    }

    /// Per-muscle zone classification at render time. At v1 scale
    /// (~17 muscles × ~4500 SetEntry rows) this fits the Pitfall #6
    /// perf ceiling without memoization (RESEARCH §10 Pitfall #2).
    @MainActor
    private func computeZoneByMuscleSlug() -> [String: VolumeZone] {
        var result: [String: VolumeZone] = [:]
        for muscle in allMuscles {
            let target = allTargets.first { $0.muscle?.slug == muscle.slug } ?? transientTarget(for: muscle)
            let total = FatigueModel.weeklyVolume(muscleSlug: muscle.slug, weekStart: weekStart, in: ctx)
            let zone = FatigueModel.volumeZone(
                currentSets: total.totalSetsRounded,
                mev: target.mev,
                mav: target.mav,
                mrv: target.mrv
            )
            result[muscle.slug] = zone
        }
        return result
    }

    private func muscleDisplayNames() -> [String: String] {
        Dictionary(uniqueKeysWithValues: allMuscles.map { ($0.slug, $0.displayName) })
    }

    /// Find the persisted MuscleVolumeTarget for `muscle`, or fall
    /// back to a transient (non-inserted) MuscleVolumeTarget seeded
    /// from RPVolumeLandmarks.
    private func targetFor(_ muscle: MuscleGroup) -> MuscleVolumeTarget {
        if let persisted = allTargets.first(where: { $0.muscle?.slug == muscle.slug }) {
            return persisted
        }
        return transientTarget(for: muscle)
    }

    private func transientTarget(for muscle: MuscleGroup) -> MuscleVolumeTarget {
        let fallback = MuscleVolumeTarget()
        let landmark = RPVolumeLandmarks.landmark(for: muscle.slug)
        fallback.mv = landmark.mv
        fallback.mev = landmark.mev
        fallback.mav = landmark.mav
        fallback.mrv = landmark.mrv
        fallback.muscle = muscle
        return fallback
    }
}
