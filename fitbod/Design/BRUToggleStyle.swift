// BRUToggleStyle.swift
// fitbod
//
// Square, hard-edged switch replacing the system's green capsule toggle.
// Off: paper track, ink knob. On: signal track, paper knob. The whole row
// (label + switch) is the tap target, and VoiceOver keeps the native
// toggle semantics because the style wraps `configuration.isOn`.

import SwiftUI

public struct BRUToggleStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                configuration.label
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                track(isOn: configuration.isOn)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }

    private func track(isOn: Bool) -> some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Rectangle()
                .fill(isOn ? Color.bruSignal : Color.bruPaper)
                .frame(width: 52, height: 28)
                .overlay(Rectangle().strokeBorder(isOn ? Color.bruSignal : Color.bruInk, lineWidth: 2))
            Rectangle()
                .fill(isOn ? Color.bruOnSignal : Color.bruInk)
                .frame(width: 20, height: 20)
                .padding(4)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isOn)
    }
}

public extension ToggleStyle where Self == BRUToggleStyle {
    /// `.toggleStyle(.bru)`
    static var bru: BRUToggleStyle { BRUToggleStyle() }
}

#if DEBUG
#Preview("BRUToggleStyle") {
    @Previewable @State var on = true
    @Previewable @State var off = false
    VStack(spacing: 0) {
        Toggle("Auto warm-up", isOn: $on).toggleStyle(.bru)
        BRUDivider(.hair)
        Toggle("Track tempo", isOn: $off).toggleStyle(.bru)
    }
    .padding(16)
    .background(Color.bruPaper)
}
#endif
