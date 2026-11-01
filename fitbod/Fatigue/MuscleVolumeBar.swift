//
//  MuscleVolumeBar.swift
//  fitbod
//
//  Phase 5.1-01 Task 2 — BRU reskin of the per-muscle weekly volume bar.
//
//  Layout per bru-screens/volume.jsx lines 63–122 + 05-UI-SPEC §MuscleVolumeBar:
//    (1) Header HStack: uppercase muscle name (labelSmall, left)
//        + tabular set-count displayMedium + "SETS" labelMicro (right)
//    (2) Tick label row: 8pt mono MEV, MAV and MRV labels (MRV in
//        bruSignalText) over their ticks, in a row of their own between
//        the header and the track, so they keep clear of the muscle name
//        and the set count (review item 22). A label centers on its tick
//        unless that would cross an end of the track, and it is left out
//        where it would collide with its neighbor. At accessibility text
//        sizes every label, and so the row, is left out; the footer
//        legend has the values.
//    (3) 16pt bar track: bruBg2 background + 1.5pt bruInk outline
//        + zone-color fill for totalSets; 2pt bruInk right-edge separator
//        on the fill; 1pt bruInk MEV + MAV ticks and a 1pt bruSignal MRV
//        tick, each running 3pt past the track. The track spans one axis
//        shared by every row, as in the reference: 25 sets, the largest RP
//        default MRV, or the largest MRV on screen if a user target runs
//        past that. MRV sits inside the track, so volume past MRV shows as
//        fill beyond the MRV tick.
//    (4) Footer HStack: BRUChip verb + 9pt mono bruMuted legend
//
//  Zone → bar fill color:
//    .belowMEV   → bruFaint
//    .productive → bruInk
//    .nearMRV    → bruSignal
//    .overMRV    → bruSignal (+ pulse)
//
//  Set count color: bruMuted for untrained and under-MEV rows, bruInk when
//  productive, bruSignalText near or over MRV. bruFaint is a fill color and
//  too light to read as text, so the count never takes the faint fill.
//
//  Chip label/color/fill per UI-SPEC §Copy overlay:
//    NOT TRAINED (total==0) → label "NOT TRAINED", color bruMuted, fill false
//                             (UI-SPEC said bruFaint plus row opacity 0.5,
//                             which left the row unreadable; the reference's
//                             own data gives this verb BRU.muted)
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
    /// Sets at the right end of the track. Rows in one list pass the same
    /// value so their bars compare.
    public var axisSets: Int = MuscleVolumeBar.minimumAxisSets
    public var onTap: (MuscleGroup) -> Void = { _ in }

    /// The reference's axis: 25 sets, the largest RP default MRV.
    public static let minimumAxisSets = 25

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale
    /// About the width of a three-letter tick label, for the collision check.
    @ScaledMetric(relativeTo: .caption2) private var tickLabelWidth: CGFloat = 16
    @State private var overMRVPulse: Bool = false

    public init(
        muscle: MuscleGroup,
        target: MuscleVolumeTarget,
        total: WeightedSetTotal,
        delta: WeekOverWeekDelta,
        isAdvisoryActive: Bool = false,
        axisSets: Int = MuscleVolumeBar.minimumAxisSets,
        onTap: @escaping (MuscleGroup) -> Void = { _ in }
    ) {
        self.muscle = muscle
        self.target = target
        self.total = total
        self.delta = delta
        self.isAdvisoryActive = isAdvisoryActive
        self.axisSets = axisSets
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
        if isNotTrained { return .bruMuted }
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

    /// Set count color. Untrained and under-MEV rows recede in muted text
    /// rather than their faint bar fill, which is too light to read.
    var countColor: Color {
        if isNotTrained { return .bruMuted }
        switch zone {
        case .belowMEV:          return .bruMuted
        case .productive:        return .bruInk
        case .nearMRV, .overMRV: return .bruSignalText
        }
    }

    /// The sets the track spans: the shared axis, stretched when this row's
    /// own MRV runs past it, so the MRV tick always lands on the track.
    var axisMax: Int {
        max(axisSets, target.mrv, 1)
    }

    /// How much of the track the fill covers, from 0 to 1.
    var fillFraction: Double {
        min(Double(total.totalSetsRounded) / Double(axisMax), 1)
    }

    /// The combined accessibility label — muscle name + set count + D-06 verbatim verb + delta.
    /// The chip label ("UNDER MEV", "ADD A SET", etc.) is NOT used here per
    /// UI-SPEC §Copy overlay: accessibility reads the full D-06 sentence.
    var accessibilityDescription: String {
        "\(muscle.displayName): \(BRUCountLabel.text(total.totalSetsRounded, "set")) this week, \(zone.verb). \(delta.deltaCopy)."
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
                        .foregroundStyle(countColor)
                    Text("SETS")
                        .font(BRUFont.labelMicro)
                        .tracking(1.0)
                        .foregroundStyle(Color.bruMuted)
                }
            }

            // (2) Tick labels, in their own row
            if showsTickLabels {
                tickLabelRow
                    .padding(.top, Self.tickLabelRowGap)
            }

            // (3) Bar track, its ticks clear of the tick labels
            barTrack
                .frame(height: 16)
                .padding(.top, showsTickLabels ? Self.tickOverhang + Self.tickLabelRowClearance : 6)

            // (4) Footer row
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
            let height = geo.size.height
            let fillWidth = snapped(CGFloat(fillFraction) * width)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.bruBg2)

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

                // Outline drawn over the fill, so it keeps its full width there
                Rectangle()
                    .stroke(Color.bruInk, lineWidth: 1.5)

                // `.position` keeps the ticks out of the layout: a tick
                // taller than the track would otherwise stretch it.
                ForEach(ticks(trackWidth: width), id: \.label) { tick in
                    Rectangle()
                        .fill(tick.color)
                        .frame(width: 1, height: height + Self.tickOverhang * 2)
                        .position(x: tick.x + 0.5, y: height / 2)
                }

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

    // MARK: - Ticks

    /// How far each tick runs past the track, above and below.
    private static let tickOverhang: CGFloat = 3
    /// The least space between two tick labels.
    private static let tickLabelGap: CGFloat = 4
    /// The space between the header and the tick labels' row.
    private static let tickLabelRowGap: CGFloat = 4
    /// The space between the tick labels' row and the tops of the ticks.
    private static let tickLabelRowClearance: CGFloat = 2
    private static let tickLabelFont: Font = .bru(.mono, size: 8)

    /// The labels show except at accessibility text sizes; see `ticks`.
    private var showsTickLabels: Bool {
        !dynamicTypeSize.isAccessibilitySize
    }

    /// One threshold line on the bar, and where its label goes.
    private struct Tick {
        let label: String
        let x: CGFloat               // leading edge of the 1pt line
        let color: Color
        let labelColor: Color
        var labelAlignment: HorizontalAlignment = .center
        var labelAnchorX: CGFloat = 0    // where the label's aligned edge sits
        var showsLabel = false
    }

    /// The MEV, MAV and MRV ticks on a track `trackWidth` wide.
    ///
    /// A label centers on its tick unless that would cross an end of the
    /// track; then it lines up with that end. A label that would run into
    /// the kept label to its right is left out, so MRV keeps its label
    /// first, then MAV. At accessibility text sizes every label is left
    /// out; the footer legend has the values.
    private func ticks(trackWidth width: CGFloat) -> [Tick] {
        func x(_ sets: Int) -> CGFloat {
            let fraction = min(Double(sets) / Double(axisMax), 1)
            return min(snapped(CGFloat(fraction) * width), width - 1)
        }
        var ticks = [
            Tick(label: "MEV", x: x(target.mev), color: .bruInk, labelColor: .bruMuted),
            Tick(label: "MAV", x: x(target.mav), color: .bruInk, labelColor: .bruMuted),
            Tick(label: "MRV", x: x(target.mrv), color: .bruSignal, labelColor: .bruSignalText),
        ]
        guard !dynamicTypeSize.isAccessibilitySize else { return ticks }

        let labelWidth = tickLabelWidth
        var nextLabelStart = CGFloat.infinity
        for i in ticks.indices.reversed() {
            let center = ticks[i].x + 0.5
            let start: CGFloat
            if center + labelWidth / 2 > width {
                ticks[i].labelAlignment = .trailing
                ticks[i].labelAnchorX = ticks[i].x + 1
                start = ticks[i].x + 1 - labelWidth
            } else if center - labelWidth / 2 < 0 {
                ticks[i].labelAlignment = .leading
                ticks[i].labelAnchorX = ticks[i].x
                start = ticks[i].x
            } else {
                ticks[i].labelAnchorX = center
                start = center - labelWidth / 2
            }
            if start + labelWidth + Self.tickLabelGap <= nextLabelStart {
                ticks[i].showsLabel = true
                nextLabelStart = start
            }
        }
        return ticks
    }

    /// The tick labels' row: one line of their font, as wide as the track
    /// under it, with each shown label over its tick.
    private var tickLabelRow: some View {
        Text("MRV")
            .font(Self.tickLabelFont)
            .hidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay {
                GeometryReader { geo in
                    ForEach(ticks(trackWidth: geo.size.width).filter(\.showsLabel), id: \.label) { tick in
                        tickLabel(tick, centerY: geo.size.height / 2)
                    }
                }
            }
    }

    /// A tick's label, centered in the labels' row at `centerY`.
    ///
    /// It hangs off a zero-size anchor so the text keeps its natural width;
    /// overlaid on the 1pt tick itself, it would be squeezed to that width.
    private func tickLabel(_ tick: Tick, centerY: CGFloat) -> some View {
        Color.clear
            .frame(width: 0, height: 0)
            .overlay(alignment: Alignment(horizontal: tick.labelAlignment, vertical: .center)) {
                Text(tick.label)
                    .font(Self.tickLabelFont)
                    .kerning(0.5)
                    .foregroundStyle(tick.labelColor)
                    .fixedSize()
            }
            .position(x: tick.labelAnchorX, y: centerY)
    }

    /// `value` rounded to the nearest device pixel, so 1pt lines stay sharp.
    private func snapped(_ value: CGFloat) -> CGFloat {
        let scale = max(displayScale, 1)
        return (value * scale).rounded() / scale
    }
}
