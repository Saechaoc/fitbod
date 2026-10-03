// BRUSegmentedControl.swift
// fitbod
//
// Hard-edged segmented choice: [ LB | KG ]. Replaces the system segmented
// Picker, which BRU surfaces do not use. The selected segment is filled
// ink with paper text; the rest are paper with ink text. Each segment is a
// 36pt-high button whose hit area grows to 44pt without moving the layout.
// VoiceOver reads each segment as a button and marks the selected one.

import SwiftUI

public struct BRUSegmentedControl<Option: Hashable>: View {
    private let title: String
    private let options: [Option]
    @Binding private var selection: Option
    private let label: (Option) -> String

    /// - Parameters:
    ///   - title: What the control chooses ("Units"). Used for VoiceOver only.
    ///   - options: The segments, in display order.
    ///   - selection: The selected option.
    ///   - label: The text for one option, in normal case. It is shown uppercase.
    public init(
        _ title: String,
        options: [Option],
        selection: Binding<Option>,
        label: @escaping (Option) -> String
    ) {
        self.title = title
        self.options = options
        self._selection = selection
        self.label = label
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                if index > 0 {
                    Rectangle()
                        .fill(Color.bruInk)
                        .frame(width: 2)
                }
                segment(option)
            }
        }
        .fixedSize()
        .overlay(Rectangle().strokeBorder(Color.bruInk, lineWidth: 2))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func segment(_ option: Option) -> some View {
        let isSelected = option == selection
        return Button {
            selection = option
        } label: {
            Text(label(option))
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(isSelected ? Color.bruPaper : Color.bruInk)
                .padding(.horizontal, 14)
                .frame(minWidth: 52, minHeight: 36)
                .background(isSelected ? Color.bruInk : Color.bruPaper)
                .bruHitArea(4)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
#Preview("BRUSegmentedControl") {
    @Previewable @State var unit = "lb"
    @Previewable @State var filter = "All"
    VStack(alignment: .leading, spacing: 20) {
        HStack {
            Text("Units")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
            Spacer()
            BRUSegmentedControl("Units", options: ["lb", "kg"], selection: $unit) { $0 }
        }
        BRUSegmentedControl("History filter", options: ["All", "Strength", "Hypertrophy"], selection: $filter) { $0 }
    }
    .padding(16)
    .background(Color.bruPaper)
}
#endif
