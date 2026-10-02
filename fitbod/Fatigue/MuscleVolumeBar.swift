//
//  MuscleVolumeBar.swift
//  fitbod
//
//  Phase 5.1-01 Task 2 — BRU reskin of the per-muscle weekly volume bar.
//
//  Layout per bru-screens/volume.jsx lines 63–122 + 05-UI-SPEC §MuscleVolumeBar:
//    (1) Header HStack: uppercase muscle name (labelSmall, left)
//        + tabular set-count displayMedium + "SETS" labelMicro (right)
//    (2) 16pt bar track: bruBg2 background + 1.5pt bruInk outline
//        + zone-color fill clipped to totalSets/mrv%; 2pt bruInk right-edge
//        separator on the fill; 1pt bruInk MEV + MAV ticks; 1pt bruSignal
//        MRV tick; 8pt mono bruMuted tick labels floating above.
//    (3) Footer HStack: BRUChip verb + 9pt mono bruMuted legend
//
//  Zone → bar fill color:
//    .belowMEV   → bruFaint
//    .productive → bruInk
//    .nearMRV    → bruSignal
//    .overMRV    → bruSignal (+ pulse)
//
//  Chip label/color/fill per UI-SPEC §Copy overlay:
//    NOT TRAINED (total==0) → label "NOT TRAINED", color bruFaint, fill false, row opacity 0.5
//    .belowMEV              → "UNDER MEV", bruAmber, fill true
//    .productive + headroom ≥ 2 → "ADD A SET", bruGreen, fill false
//    .productive            → "HOLD", bruInk, fill false
//    .nearMRV               → "NEAR MRV — DELOAD", bruSignal, fill true
//    .overMRV               → "OVER MRV", bruSignal, fill true
//
//  Accessibility: combined-element label reads D-06 verbatim zone.verb sentence.
//  Pulse: .overMRV opacity 1.0↔0.7, 1.2s easeInOut, reduce-motion gated.
//  Advisory ring: Rectangle() stroke bruAmber.opacity(0.6) 2pt (NOT RoundedRectangle).
//
//  BRU contract — ZERO banned tokens:
//    No Color.accentColor, Color(.system*), RoundedRectangle(cornerRadius:),
//    .font(.body|.headline|.caption|.subheadline|.footnote), Image(systemName:), Capsule()
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

    // MARK: - Internal computed properties (exposed for testability)

    /// True when the muscle has logged zero sets this week.
    var isNotTrained: Bool {
        total.totalSetsRounded == 0
    }

    /// The volume zone, bypassed to .belowMEV for untrained muscles.
    var zone: VolumeZone {
        FatigueModel.volumeZone(
            currentSets: total.totalSetsRounded,
            mev: target.mev,
            mav: target.mav,
            mrv: target.mrv
        )
    }

    /// BRU chip label per UI-SPEC §Copy overlay table.
    var chipLabel: String {
        if isNotTrained { return "NOT TRAINED" }
        switch zone {
        case .belowMEV:
            return "UNDER MEV"
        case .productive:
            let headroom = target.mav - total.totalSetsRounded
            return headroom >= 2 ? "ADD A SET" : "HOLD"
        case .nearMRV:
            return "NEAR MRV — DELOAD"
        case .overMRV:
            return "OVER MRV"
        }
    }

    /// BRU chip color per UI-SPEC §Copy overlay table.
    var chipColor: Color {
        if isNotTrained { return .bruFaint }
        switch zone {
        case .belowMEV:   return .bruAmber
        case .productive:
            let headroom = target.mav - total.totalSetsRounded
            return headroom >= 2 ? .bruGreen : .bruInk
        case .nearMRV:    return .bruSignal
        case .overMRV:    return .bruSignal
        }
    }

    /// Whether the chip should render filled (background) vs outline.
    var chipShouldFill: Bool {
        if isNotTrained { return false }
        switch zone {
        case .belowMEV:   return true
        case .productive: return false
        case .nearMRV:    return true
        case .overMRV:    return true
        }
    }

    /// Bar fill color per zone.
    var barFillColor: Color {
        if isNotTrained { return .bruFaint }
        switch zone {
        case .belowMEV:   return .bruFaint
        case .productive: return .bruInk
        case .nearMRV:    return .bruSignal
        case .overMRV:    return .bruSignal
        }
    }

    /// The combined accessibility label — muscle name + set count + D-06 verbatim verb + delta.
    /// The chip label ("UNDER MEV", "ADD A SET", etc.) is NOT used here per
    /// UI-SPEC §Copy overlay: accessibility reads the full D-06 sentence.
    var accessibilityDescription: String {
        "\(muscle.displayName): \(total.totalSetsRounded) sets this week, \(zone.verb). \(delta.deltaCopy)."
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // (1) Header row
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(muscle.displayName.uppercased())
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .foregroundStyle(Color.bruInk)
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(total.totalSetsRounded)")
                        .font(.bru(.grotesk, size: 24))
                        .foregroundStyle(barFillColor)
                    Text("SETS")
                        .font(BRUFont.labelMicro)
                        .tracking(1.0)
                        .foregroundStyle(Color.bruMuted)
                }
            }

            // (2) Bar track
            barTrack
                .frame(height: 16)
                .padding(.top, 6)

            // (3) Footer row
            HStack(alignment: .center) {
                BRUChip(chipLabel, color: chipColor, fill: chipShouldFill)
                Spacer()
                Text("MEV \(target.mev) · MAV \(target.mav) · MRV \(target.mrv)")
                    .font(.bru(.mono, size: 9))
                    .kerning(0.5)
                    .foregroundStyle(Color.bruMuted)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.bruHair)
                .frame(height: 1)
        }
        .opacity(isNotTrained ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture { onTap(muscle) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Tap to see details.")
        .accessibilityAddTraits(.isButton)
        .onAppear {
            overMRVPulse = (zone == .overMRV && !reduceMotion)
        }
        .onChange(of: zone) { _, newZone in
            overMRVPulse = (newZone == .overMRV && !reduceMotion)
        }
    }

    // MARK: - Bar track

    @ViewBuilder
    private var barTrack: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let mrvD = max(Double(target.mrv), 1.0)
            let fillWidth = CGFloat(min(Double(total.totalSetsRounded) / mrvD, 1.0)) * width
            let mevX = CGFloat(min(Double(target.mev) / mrvD, 1.0)) * width
            let mavX = CGFloat(min(Double(target.mav) / mrvD, 1.0)) * width
            // MRV tick sits at the right edge of the track (x = 1.0)
            let mrvX = width

            ZStack(alignment: .leading) {
                // Track background + outline
                Rectangle()
                    .fill(Color.bruBg2)
                    .overlay(
                        Rectangle()
                            .stroke(Color.bruInk, lineWidth: 1.5)
                    )

                // Zone-color fill with 2pt bruInk right-edge separator
                if fillWidth > 0 {
                    Rectangle()
                        .fill(barFillColor)
                        .frame(width: fillWidth)
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(Color.bruInk)
                                .frame(width: 2)
                        }
                }

                // MEV tick (1pt bruInk) + floating label
                tickMark(at: mevX, in: geo.size.height, color: .bruInk, label: "MEV")

                // MAV tick (1pt bruInk) + floating label
                tickMark(at: mavX, in: geo.size.height, color: .bruInk, label: "MAV")

                // MRV tick (1pt bruSignal) + floating signal label
                tickMark(at: mrvX - 1, in: geo.size.height, color: .bruSignal, label: "MRV")

                // Advisory amber ring (Rectangle, NOT RoundedRectangle — sharp corner BRU rule)
                if isAdvisoryActive {
                    Rectangle()
                        .stroke(Color.bruAmber.opacity(0.6), lineWidth: 2)
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

    /// Renders a vertical tick at the given x offset with a floating label above.
    @ViewBuilder
    private func tickMark(at x: CGFloat, in height: CGFloat, color: Color, label: String) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: 1, height: height + 6)
            .offset(x: x, y: -3)
            .overlay(alignment: .top) {
                Text(label)
                    .font(.bru(.mono, size: 8))
                    .kerning(0.5)
                    .foregroundStyle(color == .bruSignal ? Color.bruSignal : Color.bruMuted)
                    .offset(x: x - 10, y: -14)
            }
    }
}
