//
//  FatigueSurfaceView.swift
//  fitbod
//
//  Phase 5.1 plan 05 — BRU reskin of the Today-tab host for the per-muscle
//  volume bars + body heatmap. Composes Wave 1 outputs:
//    - MuscleVolumeBar rows (Plan 05.1-01)
//    - Twin BodySilhouetteView instances (Plan 05.1-04) side-by-side
//
//  Layout top-to-bottom per bru-screens/volume.jsx + bru-screens/heatmap.jsx:
//    (1) Summary ink slab   — full-bleed bruInk, WORKING SETS / VS LAST WK
//    (2) Legend strip       — UNDER MEV / MEV→MAV / MRV swatches + labels
//    (3) Volume This Week   — BRUSectionHead + LazyVStack of MuscleVolumeBar rows
//    (4) Muscle Heatmap     — BRUSectionHead + side-by-side FRONT + BACK grids
//
//  Empty-state: the legend, volume section and heatmap section are replaced
//  by the verbatim UI-SPEC §Copywriting Contract empty-state copy.
//
//  Front/Back segmented Picker REMOVED per UI-SPEC line 268 — both sides
//  render simultaneously via twin BodySilhouetteView instances.
//
//  Data layer PRESERVED: @Query<MuscleGroup> + @Query<MuscleVolumeTarget> +
//  inline FatigueModel calls + transient RPVolumeLandmarks fallback +
//  isAdvisoryActive @State + DeloadAdvisor refresh task.
//
//  BRU contract: no system accent or system colors, no rounded or capsule
//  shapes, no SF Symbols, no segmented Front/Back picker, and no system
//  text styles. FatigueSurfaceViewBRUTests greps this whole file, so this
//  comment must not spell those APIs out.
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

    public init(
        isAdvisoryActive: Bool = false,
        navigationPath: Binding<NavigationPath> = .constant(NavigationPath())
    ) {
        self.isAdvisoryActive = isAdvisoryActive
        self._navigationPath = navigationPath
    }

    // MARK: - Computed helpers

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

    /// True when there is any volume data or configured MEV target to display.
    private var hasVolumeData: Bool {
        !visibleMuscles.isEmpty
    }

    /// Sum of `totalSetsRounded` across all visible muscles — displayed in the summary slab.
    private var weeklyTotalRounded: Int {
        visibleMuscles.reduce(0) { acc, muscle in
            acc + FatigueModel.weeklyVolume(muscleSlug: muscle.slug, weekStart: weekStart, in: ctx).totalSetsRounded
        }
    }

    /// Net delta copy per bru-screens/volume.jsx line 32: `+N`, `-N`, or `±0`.
    /// Rounded to whole sets like `WeekOverWeekDelta.deltaCopy`; the
    /// stimulus-weighted sum is fractional and read "+29.0" unrounded.
    private var deltaCopy: String {
        let sum = visibleMuscles.reduce(0.0) { acc, muscle in
            let d = FatigueModel.weekOverWeekDelta(muscleSlug: muscle.slug, weekStart: weekStart, in: ctx)
            return acc + d.delta
        }
        let net = Int(sum.rounded())
        if net > 0 { return "+\(net)" }
        if net < 0 { return "\(net)" }
        return "±0"
    }

    /// ISO week label e.g. "W3 / 5" matching heatmap.jsx header right slot.
    private var weekLabel: String {
        let cal = Calendar(identifier: .iso8601)
        let week = cal.component(.weekOfYear, from: Date.now)
        let weeksInYear = cal.range(of: .weekOfYear, in: .yearForWeekOfYear, for: Date.now)?.count ?? 52
        return "W\(week) / \(weeksInYear)"
    }

    /// Zone map for BodySilhouetteView — all muscles, not just visibleMuscles,
    /// so the heatmap can show context for untrained muscles.
    private var zoneMap: [String: VolumeZone] {
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

    /// Display name map for BodySilhouetteView accessibility.
    private var nameMap: [String: String] {
        Dictionary(uniqueKeysWithValues: allMuscles.map { ($0.slug, $0.displayName) })
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            summarySlab
            if hasVolumeData {
                // The legend explains the bars, so it shows only with them.
                legendStrip
                volumeSection
                heatmapSection
            } else {
                emptyState
            }
        }
    }

    // MARK: - (1) Summary ink slab

    /// Full-bleed bruInk slab per bru-screens/volume.jsx lines 22–35.
    private var summarySlab: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                // The reference says "7 DAYS", but the total runs from the
                // start of the calendar week, so name the week instead.
                Text("WORKING SETS · THIS WEEK")
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruPaper.opacity(0.6))
                BRUDisplay("\(weeklyTotalRounded)", size: .hero, color: .bruPaper)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("VS LAST WK")
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruPaper.opacity(0.6))
                BRUDisplay(deltaCopy, size: .large, color: .bruSignal)
                Text("STIMULUS-WEIGHTED")
                    .font(BRUFont.labelMicro)
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruPaper.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bruInk)
    }

    // MARK: - (2) Legend strip

    /// Three-swatch legend per bru-screens/volume.jsx lines 38–52.
    private var legendStrip: some View {
        HStack(spacing: 16) {
            legendCell(
                fill: Color.bruBg2,
                strokeColor: Color.bruInk,
                showStroke: true,
                label: "UNDER MEV"
            )
            legendCell(
                fill: Color.bruInk,
                strokeColor: Color.clear,
                showStroke: false,
                label: "MEV → MAV"
            )
            legendCell(
                fill: Color.bruSignal,
                strokeColor: Color.clear,
                showStroke: false,
                label: "MRV"
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        // Left-aligned like the reference. Its 2pt rule comes from the
        // section head right below, so the legend draws none of its own.
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendCell(
        fill: Color,
        strokeColor: Color,
        showStroke: Bool,
        label: String
    ) -> some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(fill)
                .frame(width: 12, height: 8)
                .overlay(
                    showStroke
                        ? Rectangle().stroke(strokeColor, lineWidth: 1)
                        : nil
                )
            Text(label)
                .font(BRUFont.labelMicro)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruInk)
        }
    }

    // MARK: - (3) Volume section

    private var volumeSection: some View {
        let muscles = visibleMuscles
        // One axis for every bar so the rows compare: the reference's 25
        // sets, or the largest MRV on screen if a target runs past it.
        let axisSets = muscles
            .map { targetFor($0).mrv }
            .reduce(MuscleVolumeBar.minimumAxisSets, max)
        return VStack(alignment: .leading, spacing: 0) {
            BRUSectionHead("Volume This Week")
            LazyVStack(spacing: 0) {
                ForEach(muscles, id: \.persistentModelID) { muscle in
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
                        axisSets: axisSets,
                        onTap: { tappedMuscle in
                            navigationPath.append(MuscleSlugRoute.detail(tappedMuscle.slug))
                        }
                    )
                }
            }
        }
    }

    // MARK: - (4) Heatmap section

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            BRUSectionHead("Muscle Heatmap", right: weekLabel)
            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 8) {
                    Text("FRONT")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruInk)
                    BodySilhouetteView(
                        side: .front,
                        zoneByMuscleSlug: zoneMap,
                        muscleDisplayNames: nameMap,
                        onTap: { slug in
                            navigationPath.append(MuscleSlugRoute.detail(slug))
                        }
                    )
                }
                VStack(spacing: 8) {
                    Text("BACK")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruInk)
                    BodySilhouetteView(
                        side: .back,
                        zoneByMuscleSlug: zoneMap,
                        muscleDisplayNames: nameMap,
                        onTap: { slug in
                            navigationPath.append(MuscleSlugRoute.detail(slug))
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.bruInk)
                    .frame(height: 2)
            }
        }
    }

    // MARK: - Empty state

    /// Verbatim copy per UI-SPEC §Copywriting Contract.
    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No sets logged this week")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
            Text("Log a workout to see your weekly volume.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data helpers (PRESERVED from Phase 5 baseline)

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
