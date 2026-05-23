//
//  MuscleVolumeBar.swift
//  fitbod
//
//  Phase 5 — VOL-04 single muscle bar row.
//
//  Renders one muscle's weekly volume on the Today-tab fatigue surface:
//    - Top HStack: `muscle.displayName` (`.body`) + trailing
//      `"{totalSetsRounded} / {target.mrv}"` (`.caption .monospacedDigit
//      .secondary`).
//    - GeometryReader ZStack — track + indirect fill (opacity 0.40) +
//      direct fill (opacity 1.0) per D-07 two-tone treatment.
//    - MEV / MAV tick marks drawn on top (1pt vertical lines).
//    - D-06 verbatim verb label.
//    - D-08 verbatim "+N vs last week" / "-N vs last week" / "no change
//      vs last week" copy.
//
//  Reduce-motion gated overMRV pulse per UI-SPEC §Interaction & Motion.
//  When advisory is active, an amber ring overlay tints the bar
//  (Color("VolumeNearMRVAmber").opacity(0.6)) — plan 06 wires the
//  `isAdvisoryActive` source.
//
//  Asset Catalog colors only (NEVER `Color.red` / `Color.green`
//  literals). Per UI-SPEC §Asset Contract.
//

import SwiftUI

public struct MuscleVolumeBar: View {
    public let muscle: MuscleGroup
    public let target: MuscleVolumeTarget
    public let total: WeightedSetTotal
    public let delta: WeekOverWeekDelta
    public var isAdvisoryActive: Bool = false
    public var onTap: (MuscleGroup) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var overMRVPulse: Bool = false

    public init(
        muscle: MuscleGroup,
        target: MuscleVolumeTarget,
        total: WeightedSetTotal,
        delta: WeekOverWeekDelta,
        isAdvisoryActive: Bool = false,
        onTap: @escaping (MuscleGroup) -> Void = { _ in }
    ) {
        self.muscle = muscle
        self.target = target
        self.total = total
        self.delta = delta
        self.isAdvisoryActive = isAdvisoryActive
        self.onTap = onTap
    }

    private var zone: VolumeZone {
        FatigueModel.volumeZone(
            currentSets: total.totalSetsRounded,
            mev: target.mev,
            mav: target.mav,
            mrv: target.mrv
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(muscle.displayName)
                    .font(.body)
                Spacer()
                Text("\(total.totalSetsRounded) / \(target.mrv)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            barTrack
                .frame(height: 16)

            Text(zone.verb)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(delta.deltaCopy)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap(muscle) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(muscle.displayName): \(total.totalSetsRounded) sets this week, \(zone.verb). \(delta.deltaCopy).")
        .accessibilityHint("Tap to see details.")
        .accessibilityAddTraits(.isButton)
        .onAppear {
            overMRVPulse = (zone == .overMRV && !reduceMotion)
        }
        .onChange(of: zone) { _, newZone in
            overMRVPulse = (newZone == .overMRV && !reduceMotion)
        }
    }

    @ViewBuilder
    private var barTrack: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let mrvD = max(Double(target.mrv), 1.0)  // guard div-by-zero
            let directWidth = CGFloat(min(total.directSets / mrvD, 1.0)) * width
            let totalWidth  = CGFloat(min(total.totalSets / mrvD, 1.0)) * width
            let mevX = CGFloat(min(Double(target.mev) / mrvD, 1.0)) * width
            let mavX = CGFloat(min(Double(target.mav) / mrvD, 1.0)) * width

            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                // Indirect fill (lighter, opacity 0.40 per D-07)
                RoundedRectangle(cornerRadius: 4)
                    .fill(zoneColor(zone).opacity(0.40))
                    .frame(width: totalWidth)
                // Direct fill (full opacity, overpaints the leading
                // portion so the visible indirect strip is trailing).
                RoundedRectangle(cornerRadius: 4)
                    .fill(zoneColor(zone))
                    .frame(width: directWidth)
                // MEV tick
                Rectangle()
                    .fill(Color.primary.opacity(0.35))
                    .frame(width: 1, height: 16)
                    .offset(x: mevX)
                // MAV tick
                Rectangle()
                    .fill(Color.primary.opacity(0.35))
                    .frame(width: 1, height: 16)
                    .offset(x: mavX)
                // Advisory ring overlay (amber)
                if isAdvisoryActive {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color("VolumeNearMRVAmber").opacity(0.6), lineWidth: 2)
                }
            }
            .opacity(overMRVPulse ? 0.7 : 1.0)
            .animation(
                (zone == .overMRV && !reduceMotion)
                    ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                    : .default,
                value: overMRVPulse
            )
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
}
