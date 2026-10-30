//
//  BodySilhouetteView.swift
//  fitbod
//
//  Phase 5.1 plan 04 — Single-side 10×12 block-anatomy grid renderer.
//  Replaces the GeometryReader + .aspectRatio(0.4) anatomical silhouette
//  with a fixed 140pt × 168pt (10 cols × 12 rows at 14pt cell pitch)
//  axis-aligned block grid per bru-screens/heatmap.jsx lines 77–96.
//
//  Layout:
//    - bruBg2 background, 2pt bruInk outer border
//    - 1pt bruHair grid lines drawn via Canvas overlay
//    - Per-region Rectangle with 1pt bruInk border + zone fill color
//    - Label: uppercase short name, 7pt bold, kerning 0.4, centered
//    - Foreground: bruInk on light fills (bruBg2/bruFaint),
//                  bruPaper on dark fills (bruInk/bruSignal)
//
//  Zone → fill mapping (UI-SPEC line 53 BRU override):
//    .belowMEV   → bruFaint
//    .productive → bruInk
//    .nearMRV    → bruSignal
//    .overMRV    → bruSignal
//    absent      → bruBg2 (not trained)
//
//  Tap: each block is placed by the center of its exact rect, and its
//       tap area is that rect, with no 44pt padding (T14): the blocks
//       tile the grid, so padding would only steal a neighbour's taps.
//       The volume list on the same screen is the large-target path.
//
//  VoiceOver: one element per muscle, on its leftmost block, and on
//       FRONT when both sides draw it. The label is the muscle's name
//       and the value is its zone. NECK is decorative and hidden.
//
//  BodySide enum preserved verbatim from Phase 5. Front/Back segmented
//  control is REMOVED — FatigueSurfaceView (Plan 05.1-05) renders both
//  sides side-by-side instead.
//
//  Banned tokens (zero matches required):
//    Color.accentColor, Color(.system*), Color("Volume*"),
//    RoundedRectangle(cornerRadius:), Capsule(), Image(systemName:),
//    .font(.body|.headline|.caption|.subheadline|.footnote),
//    .aspectRatio(0.4, ...)
//

import SwiftUI

// MARK: - BodySide

/// Selects which body side the block-anatomy grid renders.
/// Front/Back segmented control has been removed — both sides render
/// side-by-side in FatigueSurfaceView (Plan 05.1-05).
public enum BodySide: String, Sendable, Equatable, Hashable, CaseIterable {
    case front, back
}

// MARK: - BodySilhouetteView

public struct BodySilhouetteView: View {

    // MARK: Constants

    /// Grid cell pitch in points — matches heatmap.jsx `cell = 14`.
    static let cell: CGFloat = 14
    static let cols: Int = 10
    static let rows: Int = 12

    // MARK: Stored properties

    public let side: BodySide
    public let zoneByMuscleSlug: [String: VolumeZone]
    public let muscleDisplayNames: [String: String]
    public let onTap: (String) -> Void

    private let regions: [GridRegion]

    // MARK: Init

    public init(
        side: BodySide,
        zoneByMuscleSlug: [String: VolumeZone],
        muscleDisplayNames: [String: String],
        onTap: @escaping (String) -> Void
    ) {
        self.side = side
        self.zoneByMuscleSlug = zoneByMuscleSlug
        self.muscleDisplayNames = muscleDisplayNames
        self.onTap = onTap
        self.regions = MuscleRegionPaths.regions(for: side)
    }

    // MARK: Body

    public var body: some View {
        let cell = Self.cell
        let cols = Self.cols
        let rows = Self.rows
        let containerW = CGFloat(cols) * cell
        let containerH = CGFloat(rows) * cell

        ZStack(alignment: .topLeading) {
            // Background fill
            Rectangle()
                .fill(Color.bruBg2)

            // 1pt bruHair grid lines
            Canvas { context, size in
                let strokeColor = Color.bruHair
                // Vertical lines
                for col in 0...cols {
                    let x = CGFloat(col) * cell
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(p, with: .color(strokeColor), lineWidth: 1)
                }
                // Horizontal lines
                for row in 0...rows {
                    let y = CGFloat(row) * cell
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(p, with: .color(strokeColor), lineWidth: 1)
                }
            }

            // Per-region blocks, each placed by the center of its exact
            // grid rect, with its tap area exactly that rect.
            ForEach(Array(regions.enumerated()), id: \.offset) { _, region in
                let r = region.rect(cell: cell)
                regionBlock(region, size: r.size)
                    .position(x: r.midX, y: r.midY)
            }
        }
        .frame(width: containerW, height: containerH)
        .overlay(
            Rectangle()
                .stroke(Color.bruInk, lineWidth: 2)
        )
    }

    // MARK: - Region block

    /// One block: zone fill, 1pt bruInk border and centered label. NECK is
    /// decorative: it opens nothing and VoiceOver skips it. A muscle block
    /// opens the muscle's detail screen, and VoiceOver reads only the
    /// block that speaks for the muscle.
    @ViewBuilder
    private func regionBlock(_ region: GridRegion, size: CGSize) -> some View {
        let fillColor = bruColor(for: zoneByMuscleSlug[region.slug])
        let isDarkFill = fillColor == Color.bruInk || fillColor == Color.bruSignal
        let textColor: Color = isDarkFill ? .bruPaper : .bruInk
        let block = ZStack {
            Rectangle()
                .fill(fillColor)
            Rectangle()
                .stroke(Color.bruInk, lineWidth: 1)
            Text(region.displayLabel)
                .font(.system(size: 7, weight: .bold, design: .default))
                .kerning(0.4)
                .foregroundStyle(textColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .multilineTextAlignment(.center)
        }
        .frame(width: size.width, height: size.height)

        if isDecorative(region) {
            // NECK takes its own taps and does nothing with them, so touch
            // fuzzing never hands them to a neighbouring block.
            block
                .contentShape(Rectangle())
                .onTapGesture {}
                .accessibilityHidden(true)
        } else {
            block
                .contentShape(Rectangle())
                .onTapGesture { onTap(region.slug) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(for: region))
                .accessibilityValue(accessibilityValue(for: region))
                .accessibilityHint("Tap to see details.")
                .accessibilityAddTraits(.isButton)
                .accessibilityHidden(!speaksForMuscle(region))
        }
    }

    // MARK: - Helpers (internal for test visibility)

    /// Maps a `VolumeZone` to the BRU palette fill per UI-SPEC line 53.
    internal func bruColor(for zone: VolumeZone?) -> Color {
        guard let z = zone else { return .bruBg2 }
        switch z {
        case .belowMEV:           return .bruFaint
        case .productive:         return .bruInk
        case .nearMRV, .overMRV:  return .bruSignal
        }
    }

    /// VoiceOver label for a muscle block: the muscle's display name,
    /// such as "Chest".
    private func accessibilityLabel(for region: GridRegion) -> String {
        muscleDisplayNames[region.slug]
            ?? MuscleRegionMap.displayName(for: region.slug)
    }

    /// VoiceOver value for a muscle block: the zone's D-06 verbatim verb
    /// per UI-SPEC §Accessibility Contract, as a sentence.
    private func accessibilityValue(for region: GridRegion) -> String {
        let verb = zoneByMuscleSlug[region.slug]?.verb ?? "Not trained"
        return verb.hasSuffix(".") ? verb : "\(verb)."
    }

    /// VoiceOver reads each muscle once, on its leftmost block, and on
    /// FRONT when both sides draw the muscle. The muscle's other blocks
    /// stay tappable but are hidden from VoiceOver.
    private func speaksForMuscle(_ region: GridRegion) -> Bool {
        if side == .back, MuscleRegionPaths.front.contains(where: { $0.slug == region.slug }) {
            return false
        }
        return !regions.contains { $0.slug == region.slug && $0.gridX < region.gridX }
    }

    private func isDecorative(_ region: GridRegion) -> Bool {
        region.slug.hasSuffix("-decorative")
    }
}
