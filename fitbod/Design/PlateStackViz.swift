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

import SwiftUI

// MARK: - PlateStackViz

/// Canvas-style horizontal plate-stack visualization.
///
/// Renders a side-on view of a barbell with proportionally sized plates:
/// - Sleeve segment (bruMuted, 30×16pt base)
/// - Per-plate rectangles (bruInk fill, bruBg2 1pt inter-plate border)
/// - Rotated weight labels in bruPaper (hidden when heightScale < 0.5)
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
        // Expand the (weight, count) tuples into individual plate instances,
        // preserving heaviest-first ordering.
        let plates: [Double] = platesPerSide.flatMap { denomination in
            Array(repeating: denomination.weight, count: denomination.count)
        }

        return HStack(alignment: .center, spacing: 0) {
            ForEach(Array(plates.enumerated()), id: \.offset) { _, weight in
                plateView(weight: weight)
            }
        }
    }

    /// A single plate rectangle.
    private func plateView(weight: Double) -> some View {
        // Proportional sizing per 03-UI-SPEC lines 73-74 / plate-calc.jsx lines 56-57:
        //   width  = max(8pt, plateWeight × 0.4pt) × heightScale
        //   height = (40pt + plateWeight × 0.8pt) × heightScale
        // The legacy min(32, weight) clamp from the old PlateStackDisclosure.swift
        // is NOT applied here — per 03-UI-REVIEW.md it capped heavy plates too low.
        let plateWidth  = max(8, weight * 0.4) * heightScale
        let plateHeight = (40 + weight * 0.8) * heightScale

        return ZStack {
            // Plate fill — bruInk for ALL plates (no color tiers, 03-UI-SPEC line 141)
            Rectangle()
                .fill(Color.bruInk)

            // 1pt inter-plate separator shows bruBg2 (matches plate-calc.jsx line 61:
            // `border: 1px solid ${BRU.bg2}`)
            Rectangle()
                .stroke(Color.bruBg2, lineWidth: 1)

            // Rotated weight label — hidden in mini-viz to avoid overflow at 9pt heights
            if !isMini {
                rotatedLabel(weight: weight)
            }
        }
        .frame(width: plateWidth, height: plateHeight)
    }

    /// Rotated −90deg weight label inside a plate rectangle.
    /// Uses a raw 12pt SpaceGrotesk-Bold font (the public BRUFont.displayMedium enum
    /// vends 18pt which is too tall for narrow plates; 12pt is the load-bearing size
    /// per 03-UI-SPEC line 456 and plate-calc.jsx line 64-66).
    ///
    /// - Note: Local 12pt SpaceGrotesk-Bold for rotated plate labels per
    ///         03-UI-SPEC line 456 / plate-calc.jsx line 64; BRUFont enum stays the
    ///         public type system but raw 12pt sizing is load-bearing for plate
    ///         width × −90deg rotation legibility.
    private func rotatedLabel(weight: Double) -> some View {
        Text(formatted(weight))
            .font(.custom("SpaceGrotesk-Bold", size: 12))
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
