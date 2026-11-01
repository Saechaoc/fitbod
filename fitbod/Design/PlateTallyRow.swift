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
//   Column 1 — 90pt wide at default text: plate icon (16×28pt bruInk Rectangle) + weight
//              number, whose 68pt share grows with its type (T19)
//   Column 2 — flexible:  4 equal-width tally boxes, 20pt tall
//   Column 3 — 80pt wide: "×{count}" or "NONE" right-aligned
// At accessibility sizes (T107) the boxes move to a line of their own under
// the weight and the count, where each is far wider than 44pt: beside them at
// AX3 each box was about 20pt wide on the small phone.
//
// TALLY INTERACTION (03-UI-SPEC line 442):
//   Tapping box at index i:
//     if count == i + 1  → clear back to i  (count.wrappedValue = i)
//     else               → fill up to i + 1 (count.wrappedValue = i + 1)
//   This implements the "cycles 0→1→2→3→4→0" spec with more precision.
//   Each box takes taps in a 44pt band, 12pt above and below the drawn box
//   (T107). Beside the weight the band reaches into the row's padding without
//   moving anything; on its own line it is the line's height.
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

    /// The weight number's 68pt share of the 90pt column, scaled like its
    /// 20pt type, so a weight such as "1.25" stays on one line at
    /// accessibility sizes.
    @ScaledMetric(relativeTo: .title3) private var weightWidth: CGFloat = 68

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: Init

    public init(weight: Double, count: Binding<Int>, unitLabel: String) {
        self.weight = weight
        self._count = count
        self.unitLabel = unitLabel
    }

    // MARK: Body

    public var body: some View {
        columns
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

    /// The three columns side by side, or at accessibility sizes the weight
    /// and the count over the tally boxes, which take the row's whole width.
    @ViewBuilder
    private var columns: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    plateIconColumn
                    Spacer(minLength: 0)
                    countColumn
                        .fixedSize()
                }

                tallyColumn
            }
        } else {
            HStack(spacing: 10) {
                // Column 1 — 90pt at default text: plate icon + weight number
                plateIconColumn

                // Column 2 — flexible: 4-box tally marks
                tallyColumn
                    .frame(maxWidth: .infinity)

                // Column 3 — 80pt: "×{count}" or "NONE"
                countColumn
                    .frame(width: 80, alignment: .trailing)
            }
        }
    }

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
                .fixedSize()
                .frame(width: weightWidth, alignment: .leading)
        }
    }

    /// Column 2: 4 tally-mark boxes.
    private var tallyColumn: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                TallyBox(
                    index: index,
                    count: count,
                    bandInLayout: dynamicTypeSize.isAccessibilitySize,
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
/// It takes taps in a 44pt band around the 20pt box (T107).
private struct TallyBox: View {
    let index: Int
    let count: Int
    /// True when the band is the box's height in the layout, on the boxes'
    /// own line at accessibility sizes. Otherwise it reaches into the row's
    /// padding and the box keeps its 20pt height.
    let bandInLayout: Bool
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
            .padding(.vertical, 12)
            .contentShape(Rectangle()) // make the whole 44pt band tappable
            .padding(.vertical, bandInLayout ? 0 : -12)
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
