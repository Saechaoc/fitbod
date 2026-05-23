//
//  ConsiderDeloadBanner.swift
//  fitbod
//
//  Advisory deload banner scaffold. The Phase 4 default advisory returns
//  false, so this view stays hidden until Phase 5 supplies a real signal.
//

import SwiftUI

public struct ConsiderDeloadBanner: View {
    public let advisory: any FatigueAdvisory
    @State private var dismissed = false

    public init(advisory: any FatigueAdvisory = StubFatigueAdvisory()) {
        self.advisory = advisory
    }

    public var body: some View {
        let sessionContext = SessionContext()
        if dismissed || !advisory.shouldSuggest(context: sessionContext) {
            EmptyView()
        } else {
            let suggestion = advisory.suggestion(context: sessionContext)
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Color.yellow)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Consider a deload this week.")
                        .font(.body)
                    Text(suggestion.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Adjust block") {
                    // Phase 5 wires the real advisory action.
                }
                .foregroundStyle(Color.accentColor)
                Button {
                    dismissed = true
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Dismiss deload advisory")
            }
            .padding(16)
            .background(Color(.systemYellow).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Advisory: consider a deload this week. \(suggestion.reason).")
            .accessibilityHint("Tap to adjust your block, or swipe right to dismiss.")
        }
    }
}
