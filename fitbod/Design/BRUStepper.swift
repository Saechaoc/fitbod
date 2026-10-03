// BRUStepper.swift
// fitbod
//
// Labelled numeric stepper: [ − ] VALUE [ + ] with 44pt square buttons,
// replacing the system Stepper inside BRU screens (routine prescription,
// plateau settings). The value reads in mono so digits do not jump as
// they change. VoiceOver exposes it as an adjustable element (swipe up /
// down) with the formatted value. At accessibility text sizes the label
// moves above the control so neither has to truncate.

import SwiftUI

public struct BRUStepper<Value: Strideable>: View where Value.Stride: SignedNumeric {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let label: String
    @Binding private var value: Value
    private let range: ClosedRange<Value>
    private let step: Value.Stride
    private let format: (Value) -> String

    public init(
        _ label: String,
        value: Binding<Value>,
        in range: ClosedRange<Value>,
        step: Value.Stride,
        format: @escaping (Value) -> String
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.format = format
    }

    private var canDecrement: Bool { value.advanced(by: -step) >= range.lowerBound }
    private var canIncrement: Bool { value.advanced(by: step) <= range.upperBound }

    public var body: some View {
        layout {
            Text(label)
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 0) {
                stepButton("−", enabled: canDecrement) { value = value.advanced(by: -step) }
                Text(format(value))
                    .font(BRUFont.bodyEmphasis)
                    .monospacedDigit()
                    .foregroundStyle(Color.bruInk)
                    .padding(.horizontal, 8)
                    .frame(minWidth: 64, minHeight: 44)
                    .overlay(alignment: .top) { Rectangle().fill(Color.bruInk).frame(height: 2) }
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.bruInk).frame(height: 2) }
                stepButton("+", enabled: canIncrement) { value = value.advanced(by: step) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if canIncrement { value = value.advanced(by: step) }
            case .decrement: if canDecrement { value = value.advanced(by: -step) }
            @unknown default: break
            }
        }
    }

    /// Side by side normally; stacked at accessibility text sizes.
    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    private func stepButton(_ glyph: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(BRUFont.condensedLabel)
                .foregroundStyle(enabled ? Color.bruPaper : Color.bruMuted)
                .frame(width: 44, height: 44)
                .background(enabled ? Color.bruInk : Color.bruFaint)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

#if DEBUG
#Preview("BRUStepper") {
    @Previewable @State var sets = 3
    @Previewable @State var rest = 120
    VStack(spacing: 12) {
        BRUStepper("Sets", value: $sets, in: 1...10, step: 1) { "\($0)" }
        BRUStepper("Rest", value: $rest, in: 30...600, step: 15) { "\($0 / 60):\(String(format: "%02d", $0 % 60))" }
    }
    .padding(16)
    .background(Color.bruPaper)
}

#Preview("BRUStepper at accessibility size") {
    @Previewable @State var increment = 2.5
    BRUStepper("Default increment", value: $increment, in: 0.25...10, step: 0.25) {
        String(format: "%g kg", $0)
    }
    .padding(16)
    .background(Color.bruPaper)
    .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
