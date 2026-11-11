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
//    (1) Summary ink slab   — full-bleed bruInk, WORKING SETS / VS LAST WK,
//                             counting the sets logged (RM-038)
//    (2) Legend strip       — UNDER MEV / MEV→MAV / MRV swatches + labels,
//                             stacked at accessibility sizes
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
//  text styles; .swiftlint.yml enforces it.
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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

    /// This week's and last week's volume for every muscle. `body` reads
    /// them once and hands them to every section: each read fetches a week
    /// of sets, and reading per muscle in each section repeated that about
    /// two hundred times per render.
    private struct WeekVolumes {
        let thisWeek: [String: WeightedSetTotal]
        let lastWeek: [String: WeightedSetTotal]
        /// The working sets logged this week and last, each set once.
        let thisWeekSets: Int
        let lastWeekSets: Int

        /// Equals `FatigueModel.weeklyVolume` for the muscle.
        func total(_ slug: String) -> WeightedSetTotal {
            thisWeek[slug] ?? WeightedSetTotal(directSets: 0, indirectSets: 0)
        }

        /// Equals `FatigueModel.weekOverWeekDelta` for the muscle.
        func delta(_ slug: String) -> WeekOverWeekDelta {
            WeekOverWeekDelta(
                currentWeekTotal: total(slug).totalSets,
                previousWeekTotal: (lastWeek[slug] ?? WeightedSetTotal(directSets: 0, indirectSets: 0)).totalSets
            )
        }
    }

    private func readWeekVolumes() -> WeekVolumes {
        let start = weekStart
        let previous = FatigueModel.date(byAddingWeeks: -1, to: start)
        return WeekVolumes(
            thisWeek: FatigueModel.weeklyVolumes(weekStart: start, in: ctx),
            lastWeek: FatigueModel.weeklyVolumes(weekStart: previous, in: ctx),
            thisWeekSets: FatigueModel.workingSetCount(weekStart: start, in: ctx),
            lastWeekSets: FatigueModel.workingSetCount(weekStart: previous, in: ctx)
        )
    }

    /// Muscles with non-zero weekly volume OR a non-zero MEV target.
    /// Sorted alphabetically by displayName for stable ordering.
    private func visibleMuscles(_ volumes: WeekVolumes) -> [MuscleGroup] {
        let withVolume = allMuscles.filter { muscle in
            if volumes.total(muscle.slug).totalSetsRounded >= 1 { return true }
            if let row = allTargets.first(where: { $0.muscle?.slug == muscle.slug }), row.mev > 0 {
                return true
            }
            return false
        }
        return withVolume.sorted { $0.displayName < $1.displayName }
    }

    /// Net delta copy per bru-screens/volume.jsx line 32: `+N`, `-N`, or `±0`.
    private func deltaCopy(_ volumes: WeekVolumes) -> String {
        let net = volumes.thisWeekSets - volumes.lastWeekSets
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
    private func zoneMap(_ volumes: WeekVolumes) -> [String: VolumeZone] {
        var result: [String: VolumeZone] = [:]
        // An untrained muscle gets no zone, so its tile reads NOT TRAINED like its bar.
        for muscle in allMuscles where volumes.total(muscle.slug).totalSetsRounded > 0 {
            let target = targetFor(muscle)
            let total = volumes.total(muscle.slug)
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
        let volumes = readWeekVolumes()
        let muscles = visibleMuscles(volumes)
        VStack(spacing: 0) {
            summarySlab(volumes)
            if !muscles.isEmpty {
                // The legend explains the bars, so it shows only with them.
                legendStrip
                volumeSection(muscles, volumes)
                heatmapSection(volumes)
            } else {
                emptyState
            }
        }
    }

    // MARK: - (1) Summary ink slab

    /// Full-bleed bruSlab slab (dark in both appearances, FT-15) per bru-screens/volume.jsx lines 22–35.
    /// It counts the sets logged, as the user chose (RM-038); the reference's
    /// "STIMULUS-WEIGHTED" caption went with the weighted sum it named.
    private func summarySlab(_ volumes: WeekVolumes) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                // The reference says "7 DAYS", but the total runs from the
                // start of the calendar week, so name the week instead.
                Text("WORKING SETS · THIS WEEK")
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruOnSlab.opacity(0.6))
                BRUDisplay("\(volumes.thisWeekSets)", size: .hero, color: .bruOnSlab)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("VS LAST WK")
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruOnSlab.opacity(0.6))
                BRUDisplay(deltaCopy(volumes), size: .large, color: .bruSignal)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bruSlab)
    }

    // MARK: - (2) Legend strip

    /// Four-swatch legend after bru-screens/volume.jsx lines 38–52, with
    /// the empty state named, so zero sets, under target and in range tell
    /// apart in dark mode too (FT-18). One row while it fits; a column at
    /// larger text sizes, where a row would wrap the labels mid-word.
    private var legendStrip: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { legendCells }
            VStack(alignment: .leading, spacing: 4) { legendCells }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        // Left-aligned like the reference. Its 2pt rule comes from the
        // section head right below, so the legend draws none of its own.
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var legendCells: some View {
        legendCell(
            fill: Color.bruBg2,
            strokeColor: Color.bruInk,
            showStroke: true,
            label: "NOT TRAINED"
        )
        legendCell(
            fill: Color.bruAmber,
            strokeColor: Color.clear,
            showStroke: false,
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

    private func volumeSection(_ muscles: [MuscleGroup], _ volumes: WeekVolumes) -> some View {
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
                    MuscleVolumeBar(
                        muscle: muscle,
                        target: target,
                        total: volumes.total(muscle.slug),
                        delta: volumes.delta(muscle.slug),
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

    private func heatmapSection(_ volumes: WeekVolumes) -> some View {
        let zones = zoneMap(volumes)
        let names = nameMap
        return VStack(alignment: .leading, spacing: 0) {
            BRUSectionHead("Muscle Heatmap", right: weekLabel)
            // Each tile opens its muscle's detail; say so once (FT-17).
            // VoiceOver skips it: every tile carries the hint itself.
            Text("Tap a muscle for its detail")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .accessibilityHidden(true)
            // Each figure says its own name, "Front" or "Back", as VoiceOver
            // enters it, so VoiceOver skips the labels above them (T81).
            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 8) {
                    Text("FRONT")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruInk)
                        .accessibilityHidden(true)
                    BodySilhouetteView(
                        side: .front,
                        zoneByMuscleSlug: zones,
                        muscleDisplayNames: names,
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
                        .accessibilityHidden(true)
                    BodySilhouetteView(
                        side: .back,
                        zoneByMuscleSlug: zones,
                        muscleDisplayNames: names,
                        onTap: { slug in
                            navigationPath.append(MuscleSlugRoute.detail(slug))
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
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

    private func targetFor(_ muscle: MuscleGroup) -> RPVolumeLandmarks.Landmark {
        allTargets.first { $0.muscle?.slug == muscle.slug }
            .map(RPVolumeLandmarks.Landmark.init) ?? RPVolumeLandmarks.landmark(for: muscle.slug)
    }
}
