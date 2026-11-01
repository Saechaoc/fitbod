// PlateStackViz.swift
// fitbod/Design
//
// BRU primitive — horizontal plate-stack visualization.
// Canvas-adjacent (uses SwiftUI views with fixed sizing, not raw Canvas API).
// Consumed by: PlateStackDisclosure (03.2-04), PlateCalculatorSheet (03.2-07),
//              WarmupRampRows mini-viz (03.2-03).
//
// Visual reference: bru-screens/plate-calc.jsx lines 45-82
// Spec: 03-UI-SPEC.md lines 47-48, 73-74, 141, 450-462, 505
// Threat model: T-03.2-01 (token typos → compile errors via public Color extensions)
//               T-03.2-02 (rotated labels decorative — combined a11y label covers them)
//
// PLATE RECTANGLE SIZING (load-bearing, 03-UI-SPEC lines 73-74):
//   width  = max(8pt, plateWeight × 0.4pt) × heightScale
//   height = (40pt + plateWeight × 0.8pt) × heightScale
//
// ALL plates are Color.bruInk — no color-coded weight tiers (deprecated v1 scheme).
// Per 03-UI-SPEC line 141 and plate-calc.jsx line 63: `background: BRU.ink` for ALL plates.
//
// T107: a smaller plate drew over part of a larger plate's label: with a 137.5 lb
// target the 1.25 covered part of the 45's "45". A label sat in its plate's ZStack,
// which took the label's unrotated width, so the plate's fill stretched over its
// neighbor; and a rotated label is as wide as its digits are tall, wider than the
// 8pt plates and, at AX3, than a 45 lb plate. Labels now overlay their plates, and
// `Geometry` shows one only where its ink fits inside its own plate; the legend names
// every plate.

import CoreText
import SwiftUI

// MARK: - PlateStackViz

/// Canvas-style horizontal plate-stack visualization.
///
/// Renders a side-on view of a barbell with proportionally sized plates:
/// - Sleeve segment (bruMuted, 30×16pt base)
/// - Per-plate rectangles (bruInk fill, bruBg2 1pt inter-plate border)
/// - Rotated weight labels in bruPaper, on the plates they fit inside
///   (none when heightScale < 0.5)
/// - End cap (bruMuted, 8×60pt base)
/// - Optional legend dots row below the stack
///
/// Usage:
/// ```swift
/// PlateStackViz(
///     platesPerSide: [(45, 2), (25, 1), (10, 1)],
///     barLabel: "45 lb"
/// )
/// ```
public struct PlateStackViz: View {

    // MARK: Types

    /// One plate denomination and how many of that plate are on each side.
    public typealias PlateDenomination = (weight: Double, count: Int)

    // MARK: Properties

    /// Plates per side, heaviest-first.
    public let platesPerSide: [PlateDenomination]
    /// Bar weight text, used in the accessibility label (e.g. "45 lb").
    public let barLabel: String
    /// Uniform scale applied to all height/width dimensions. Use 1.0 for full-size,
    /// 0.3 for the mini-viz inside WarmupRampRows.
    public let heightScale: CGFloat
    /// Whether to show the legend dots row below the stack.
    public let showLegend: Bool

    /// The plate labels' point size at the current text size: 12pt grows
    /// like `.caption`, as their font does.
    @ScaledMetric(relativeTo: .caption) private var labelPointSize: CGFloat = Geometry.labelSize

    // MARK: Init

    public init(
        platesPerSide: [PlateDenomination],
        barLabel: String,
        heightScale: CGFloat = 1.0,
        showLegend: Bool = true
    ) {
        self.platesPerSide = platesPerSide
        self.barLabel = barLabel
        self.heightScale = max(0.1, heightScale) // guard against zero/negative
        self.showLegend = showLegend
    }

    // MARK: Computed

    /// Whether we are in mini-viz mode (suppress labels and legend).
    private var isMini: Bool { heightScale < 0.5 }

    // MARK: Body

    public var body: some View {
        VStack(spacing: 8) {
            // Stack row
            HStack(alignment: .center, spacing: 2) {
                sleevePart
                platesRow
                endCapPart
            }

            // Legend dots (hidden in mini-viz mode)
            if showLegend && !isMini {
                legendRow
            }
        }
        // MARK: Accessibility (03-UI-SPEC lines 502, 505)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
    }

    // MARK: Subviews

    /// Bar sleeve — left side of the plate stack.
    private var sleevePart: some View {
        Rectangle()
            .fill(Color.bruMuted)
            .frame(
                width: 30 * heightScale,
                height: 16 * heightScale
            )
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color.bruInk)
                    .frame(width: 2 * heightScale)
            }
    }

    /// End cap — right side of the plate stack.
    private var endCapPart: some View {
        Rectangle()
            .fill(Color.bruMuted)
            .frame(
                width: 8 * heightScale,
                height: 60 * heightScale
            )
            .overlay {
                Rectangle()
                    .stroke(Color.bruInk, lineWidth: 2 * heightScale)
            }
            .padding(.leading, 4 * heightScale)
    }

    /// All plates rendered as a row, heaviest (leftmost) first.
    private var platesRow: some View {
        // The labels' size at the current text size. Mini-viz draws none.
        let geometry = Geometry(
            platesPerSide: platesPerSide,
            heightScale: heightScale,
            labelPointSize: isMini ? nil : labelPointSize
        )

        return HStack(alignment: .center, spacing: 0) {
            ForEach(Array(geometry.plates.enumerated()), id: \.offset) { _, plate in
                plateView(plate)
            }
        }
    }

    /// A single plate rectangle, sized by `Geometry`. The separator and the
    /// label overlay the plate, so neither can widen it: as a ZStack's
    /// child, a label wider than its plate stretched the plate's fill over
    /// its neighbor (T107).
    private func plateView(_ plate: Geometry.Plate) -> some View {
        // Plate fill — bruInk for ALL plates (no color tiers, 03-UI-SPEC line 141)
        Rectangle()
            .fill(Color.bruInk)
            .frame(width: plate.frame.width, height: plate.frame.height)
            // 1pt inter-plate separator shows bruBg2 (matches plate-calc.jsx line 61:
            // `border: 1px solid ${BRU.bg2}`)
            .overlay {
                Rectangle()
                    .stroke(Color.bruBg2, lineWidth: 1)
            }
            // Rotated weight label, where `Geometry` finds it fits inside the plate
            .overlay {
                if plate.label != nil {
                    rotatedLabel(weight: plate.weight)
                }
            }
    }

    /// Rotated −90deg weight label inside a plate rectangle.
    /// Uses a raw 12pt SpaceGrotesk-Bold font (the public BRUFont.displayMedium enum
    /// vends 18pt which is too tall for narrow plates; 12pt is the load-bearing size
    /// per 03-UI-SPEC line 456 and plate-calc.jsx line 64-66).
    /// `Geometry.rotatedInk(of:pointSize:)` measures the same font and turn.
    ///
    /// - Note: Local 12pt SpaceGrotesk-Bold for rotated plate labels per
    ///         03-UI-SPEC line 456 / plate-calc.jsx line 64; BRUFont enum stays the
    ///         public type system but raw 12pt sizing is load-bearing for plate
    ///         width × −90deg rotation legibility.
    private func rotatedLabel(weight: Double) -> some View {
        Text(formatted(weight))
            .font(.bru(.grotesk, size: Geometry.labelSize, relativeTo: .caption))
            .foregroundStyle(Color.bruPaper)
            .rotationEffect(.degrees(-90))
            .fixedSize()
            .allowsHitTesting(false)
    }

    /// Legend dots row — one 8pt ink square + weight text per unique denomination.
    private var legendRow: some View {
        HStack(spacing: 12) {
            ForEach(Array(platesPerSide.enumerated()), id: \.offset) { _, denomination in
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.bruInk)
                        .frame(width: 8, height: 8)

                    Text(formatted(denomination.weight))
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruInk)
                }
            }
        }
    }

    // MARK: Helpers

    /// Format a plate weight number, stripping unnecessary trailing zeros.
    private func formatted(_ d: Double) -> String {
        String(format: "%g", d)
    }

    /// Combined accessibility label for the entire stack.
    private var accessibilityLabelText: String {
        guard !platesPerSide.isEmpty else {
            return "Bar: \(barLabel). No plates loaded."
        }
        let plateList = platesPerSide.map { denomination in
            let countWord = denomination.count == 1 ? "one" : "\(denomination.count)"
            return "\(countWord) \(formatted(denomination.weight))"
        }.joined(separator: ", ")

        let totalPlates = platesPerSide.reduce(0.0) { $0 + $1.weight * Double($1.count) }
        let totalFormatted = formatted(totalPlates * 2) // both sides

        return "Bar: \(barLabel). Plates each side: \(plateList). Total: \(totalFormatted)."
    }
}

// MARK: - Geometry

extension PlateStackViz {
    /// The stack's plates left to right: each plate's rectangle and, when
    /// the plate shows its rotated label, that label's drawn ink.
    ///
    /// Frames are in points, from the first plate's leading edge, centered
    /// on the bar's line at y = 0.
    struct Geometry {
        /// The labels' point size at the default text size.
        static let labelSize: CGFloat = 12

        /// How far a label keeps inside its plate's edges: each neighbor's
        /// 1pt separator draws its outer half over them.
        static let separatorInset: CGFloat = 0.5

        struct Plate {
            let weight: Double
            let frame: CGRect
            /// The label's ink, turned −90° about the plate's center, or nil
            /// when the plate shows no label.
            let label: CGRect?
        }

        let plates: [Plate]

        /// - Parameter labelPointSize: the labels' point size at the current
        ///   text size, or nil to show no labels, as the mini-viz does.
        init(platesPerSide: [PlateDenomination], heightScale: CGFloat, labelPointSize: CGFloat?) {
            // Expand the (weight, count) tuples into individual plate
            // instances, preserving heaviest-first ordering.
            let weights = platesPerSide.flatMap { Array(repeating: $0.weight, count: $0.count) }
            var x: CGFloat = 0
            var plates: [Plate] = []
            for weight in weights {
                let size = Self.plateSize(weight: weight, heightScale: heightScale)
                let frame = CGRect(x: x, y: -size.height / 2, width: size.width, height: size.height)
                let label = labelPointSize
                    .flatMap { Self.rotatedInk(of: String(format: "%g", weight), pointSize: $0) }?
                    .offsetBy(dx: frame.midX, dy: frame.midY)
                // A label that would spill past its plate's separators draws
                // over its neighbors, or a later plate draws over it, so it
                // shows only where it fits; the legend names every plate.
                let inside = frame.insetBy(dx: Self.separatorInset, dy: Self.separatorInset)
                plates.append(Plate(
                    weight: weight,
                    frame: frame,
                    label: label.flatMap { inside.contains($0) ? $0 : nil }
                ))
                x += size.width
            }
            self.plates = plates
        }

        /// Proportional sizing per 03-UI-SPEC lines 73-74 / plate-calc.jsx lines 56-57:
        ///   width  = max(8pt, plateWeight × 0.4pt) × heightScale
        ///   height = (40pt + plateWeight × 0.8pt) × heightScale
        /// The legacy min(32, weight) clamp from the old PlateStackDisclosure.swift
        /// is NOT applied here — per 03-UI-REVIEW.md it capped heavy plates too low.
        static func plateSize(weight: Double, heightScale: CGFloat) -> CGSize {
            CGSize(width: max(8, weight * 0.4) * heightScale, height: (40 + weight * 0.8) * heightScale)
        }

        /// The ink of `text` in the label font at `pointSize`, turned −90°
        /// about the center of its line, as `rotatedLabel` draws it, relative
        /// to that center. Nil when the font is missing.
        static func rotatedInk(of text: String, pointSize: CGFloat) -> CGRect? {
            guard let font = UIFont(name: BRUFace.grotesk.rawValue, size: pointSize) else { return nil }
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
            // The ink and the line's center, from the baseline's start, y up.
            let ink = CTLineGetImageBounds(line, nil)
            let center = CGPoint(x: width / 2, y: (ascent - descent) / 2)
            // Turned −90°, the label reads bottom to top: up from the
            // baseline becomes left on screen, and along the text becomes up.
            return CGRect(x: center.y - ink.maxY, y: center.x - ink.maxX, width: ink.height, height: ink.width)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Full-size — 205 lb stack") {
    ScrollView(.horizontal) {
        PlateStackViz(
            platesPerSide: [
                (weight: 45, count: 2),
                (weight: 25, count: 1),
                (weight: 10, count: 1)
            ],
            barLabel: "45 lb"
        )
        .padding(16)
    }
    .background(Color.bruBg2)
}

#Preview("Mini-viz — heightScale 0.3 (WarmupRampRows)") {
    HStack {
        PlateStackViz(
            platesPerSide: [
                (weight: 45, count: 1),
                (weight: 25, count: 1)
            ],
            barLabel: "45 lb",
            heightScale: 0.3
        )
        Spacer()
    }
    .padding(16)
    .background(Color.bruPaper)
}
#endif
