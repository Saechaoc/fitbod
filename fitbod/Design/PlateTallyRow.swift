// PlateTallyRow.swift
// fitbod/Design
//
// BRU primitive — tally-mark inventory row for plate counts.
// The tally-mark boxes ARE the input affordance — no Stepper inside this component.
// Consumed by: PlateInventoryEditor (03.2-06), PlateCalculatorSheet (03.2-07).
//
// Visual reference: bru-screens/plate-calc.jsx lines 101-128
// Spec: 03-UI-SPEC.md lines 49, 270, 442, 503
//
// COLUMN LAYOUT (3-column HStack):
//   Column 1 — 90pt wide: plate icon (16×28pt bruInk Rectangle) + weight number
//   Column 2 — flexible:  4 equal-width tally boxes, 20pt tall
//   Column 3 — 80pt wide: "×{count}" or "NONE" right-aligned
//
// TALLY INTERACTION (03-UI-SPEC line 442):
//   Tapping box at index i:
//     if count == i + 1  → clear back to i  (count.wrappedValue = i)
//     else               → fill up to i + 1 (count.wrappedValue = i + 1)
//   This implements the "cycles 0→1→2→3→4→0" spec with more precision.
//
// ZERO RoundedRectangle — every shape is a plain Rectangle (BRU design language).
// ZERO Capsule — BRU has no rounded shapes.
// Tally-box unfilled border uses .overlay { Rectangle().stroke(...) }
// NOT .border() — Swift 6 prefers .overlay for stroke application.

import SwiftUI

// MARK: - PlateTallyRow

/// One plate-inventory row in the tally-mark style.
///
/// Shows the plate weight + a 4-box tally-mark counter + a text count readout.
/// The tally boxes ARE the input — tapping fills/clears the count.
///
/// Usage:
/// ```swift
/// @State private var count = 4
/// PlateTallyRow(weight: 45, count: $count, unitLabel: "lb")
/// ```
public struct PlateTallyRow: View {

    // MARK: Properties

    public let weight: Double
    @Binding public var count: Int
    public let unitLabel: String

    // MARK: Init

    public init(weight: Double, count: Binding<Int>, unitLabel: String) {
        self.weight = weight
        self._count = count
        self.unitLabel = unitLabel
    }

    // MARK: Body

    public var body: some View {
        HStack(spacing: 10) {
            // Column 1 — 90pt: plate icon + weight number
            plateIconColumn
                .frame(width: 90, alignment: .leading)

            // Column 2 — flexible: 4-box tally marks
            tallyColumn
                .frame(maxWidth: .infinity)

            // Column 3 — 80pt: "×{count}" or "NONE"
            countColumn
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 44) // 44pt touch target per 03-UI-SPEC line 73 + line 442
        .opacity(count == 0 ? 0.4 : 1.0) // muted when zero per plate-calc.jsx line 107
        .overlay(alignment: .bottom) {
            // 1pt bruHair bottom divider per plate-calc.jsx line 106
            Rectangle()
                .fill(Color.bruHair)
                .frame(height: 1)
        }
        // MARK: Accessibility (03-UI-SPEC line 503)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(formatted(weight)) \(unitLabel) plate")
        .accessibilityValue("\(count) per side")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                count = min(count + 1, 4)
            case .decrement:
                count = max(count - 1, 0)
            default:
                break
            }
        }
    }

    // MARK: Subviews

    /// Column 1: 16×28pt bruInk plate icon + BRUDisplay-style weight number.
    private var plateIconColumn: some View {
        HStack(spacing: 6) {
            // Plate glyph — a 16×28 bruInk rectangle (per plate-calc.jsx line 110)
            Rectangle()
                .fill(Color.bruInk)
                .frame(width: 16, height: 28)

            // Weight number in displayMedium 20pt per 03-UI-SPEC line 49
            // (BRUDisplay size=20 per the spec table)
            Text(formatted(weight))
                .font(.bru(.grotesk, size: 20))
                .foregroundStyle(Color.bruInk)
        }
    }

    /// Column 2: 4 tally-mark boxes.
    private var tallyColumn: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                TallyBox(
                    index: index,
                    count: count,
                    onTap: {
                        // Spec: tapping filled box (index == count-1) clears back to index;
                        // tapping unfilled box fills up to index+1.
                        if count == index + 1 {
                            count = index
                        } else {
                            count = index + 1
                        }
                    }
                )
            }
        }
    }

    /// Column 3: "×{count}" or "NONE" count label.
    private var countColumn: some View {
        Text(count > 0 ? "×\(count)" : "NONE")
            .font(BRUFont.bodyDefault)
            .fontWeight(.semibold)
            .foregroundStyle(count > 0 ? Color.bruInk : Color.bruMuted)
            .multilineTextAlignment(.trailing)
    }

    // MARK: Helpers

    /// Format a plate weight, stripping unnecessary trailing zeros.
    private func formatted(_ d: Double) -> String {
        String(format: "%g", d)
    }
}

// MARK: - TallyBox

/// A single tally-mark box within the 4-box row.
///
/// Filled (index < count) → bruInk fill.
/// Unfilled (index >= count) → transparent fill + 1.5pt bruInk border overlay.
private struct TallyBox: View {
    let index: Int
    let count: Int
    let onTap: () -> Void

    var isFilled: Bool { index < count }

    var body: some View {
        Rectangle()
            .fill(isFilled ? Color.bruInk : Color.clear)
            .frame(height: 20)
            .overlay {
                // Always render the border — unfilled shows it as the visible edge;
                // filled overlays it on ink (bruBg2 would be invisible, bruInk border
                // on ink fill is also invisible — net effect is clean solid fill).
                if !isFilled {
                    Rectangle()
                        .stroke(Color.bruInk, lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle()) // make the whole area tappable
            .onTapGesture {
                onTap()
            }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Count = 3 (full)") {
    @Previewable @State var count = 3
    VStack(spacing: 0) {
        PlateTallyRow(weight: 45, count: $count, unitLabel: "lb")
        PlateTallyRow(weight: 25, count: $count, unitLabel: "lb")
        PlateTallyRow(weight: 10, count: .constant(4), unitLabel: "lb")
        PlateTallyRow(weight: 5, count: .constant(2), unitLabel: "lb")
    }
    .background(Color.bruPaper)
}

#Preview("Count = 0 (muted-opacity state)") {
    PlateTallyRow(weight: 35, count: .constant(0), unitLabel: "lb")
        .background(Color.bruPaper)
}
#endif
