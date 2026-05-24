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
//  Tap: .contentShape(Rectangle()); regions < 44pt wrapped in
//       .frame(minWidth: 44, minHeight: 44) per UI-SPEC §Spacing.
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

            // Per-region block overlays
            ForEach(Array(regions.enumerated()), id: \.offset) { _, region in
                let r = region.rect(cell: cell)
                let fillColor = bruColor(for: zoneByMuscleSlug[region.slug])
                let isDarkFill = fillColor == Color.bruInk || fillColor == Color.bruSignal
                let textColor: Color = isDarkFill ? .bruPaper : .bruInk

                ZStack {
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
                .frame(width: r.width, height: r.height)
                .frame(
                    minWidth: needsHitPadding(region: region) ? 44 : 0,
                    minHeight: needsHitPadding(region: region) ? 44 : 0
                )
                .contentShape(Rectangle())
                .offset(x: r.minX, y: r.minY)
                .onTapGesture {
                    guard !region.slug.hasSuffix("-decorative") else { return }
                    onTap(region.slug)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(for: region))
                .accessibilityHint("Tap to see details.")
                .accessibilityAddTraits(.isButton)
            }
        }
        .frame(width: containerW, height: containerH)
        .overlay(
            Rectangle()
                .stroke(Color.bruInk, lineWidth: 2)
        )
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

    /// Accessibility label for a region — D-06 verbatim verb per
    /// UI-SPEC §Accessibility Contract. Decorative regions return only
    /// their display label.
    private func accessibilityLabel(for region: GridRegion) -> String {
        guard !region.slug.hasSuffix("-decorative") else {
            return region.displayLabel
        }
        let zone = zoneByMuscleSlug[region.slug]
        let displayName = muscleDisplayNames[region.slug]
            ?? MuscleRegionMap.displayName(for: region.slug)
        let verb = zone?.verb ?? "Not trained"
        return "\(displayName): \(verb)."
    }

    /// Returns true when the region's rendered rect is smaller than
    /// 44pt in either dimension — these require an expanded hit area.
    private func needsHitPadding(region: GridRegion) -> Bool {
        let r = region.rect()
        return r.width < 44 || r.height < 44
    }
}
