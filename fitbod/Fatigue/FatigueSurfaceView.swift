//
//  FatigueSurfaceView.swift
//  fitbod
//
//  Phase 5 — Today-tab host for the per-muscle volume bars (VOL-04) and
//  (later, plan 05) the body silhouette heatmap (VOL-05). @Query-driven
//  per FOUND-06 (MV-VM-lite — no parallel view model wraps the @Query
//  per Pitfall #8 corollary).
//
//  FatigueModel.weeklyVolume is called inline in body — D-04 on-demand
//  reads, NO snapshot entity. At v1 scale (~17 muscles × ~4500
//  SetEntry rows = ~76K traversals per render) this is well under the
//  Pitfall #6 perf ceiling. RESEARCH §10 Pitfall #2 explicitly advises
//  against premature memoization at this scale.
//
//  Defaults: if the user hasn't yet seeded their MuscleVolumeTarget
//  rows (plan 06's MuscleVolumeTargetSeeder runs there), the bars
//  still render against RPVolumeLandmarks fallback values so the
//  experience isn't blocked on the seeder. The plan 06 seeder
//  overwrites these transient defaults with persistent rows.
//

import SwiftData
import SwiftUI

public struct FatigueSurfaceView: View {
    @Environment(\.modelContext) private var ctx

    @Query private var allMuscles: [MuscleGroup]
    @Query private var allTargets: [MuscleVolumeTarget]

    public init() {}

    private var weekStart: Date {
        Date.now.mondayAtMidnight(weekStartsMonday: true)
    }

    /// Filter to muscles that have either non-zero weekly volume OR a
    /// non-zero MEV target (i.e., the user expects to train them).
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
            heatmapPlaceholder
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
                            delta: delta
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var heatmapPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Muscle Heatmap")
                .font(.headline)
            Text("Heatmap renders in plan 05")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    /// Find the persisted MuscleVolumeTarget for `muscle`, or fall
    /// back to a transient (non-inserted) MuscleVolumeTarget seeded
    /// with the RPVolumeLandmarks values. This keeps the surface
    /// rendering before plan 06's seeder runs.
    private func targetFor(_ muscle: MuscleGroup) -> MuscleVolumeTarget {
        if let persisted = allTargets.first(where: { $0.muscle?.slug == muscle.slug }) {
            return persisted
        }
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

// MARK: - Monday-at-midnight Date helper (RESEARCH §10 Pitfall #4)

extension Date {
    /// Returns the Monday-anchored midnight start of the current
    /// week. Uses `Calendar.current` with `firstWeekday = 2` per
    /// Pitfall #4 (no raw date math).
    fileprivate func mondayAtMidnight(
        weekStartsMonday: Bool,
        calendar: Calendar = .current
    ) -> Date {
        var cal = calendar
        if weekStartsMonday {
            cal.firstWeekday = 2
        }
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return cal.date(from: components) ?? self
    }
}
