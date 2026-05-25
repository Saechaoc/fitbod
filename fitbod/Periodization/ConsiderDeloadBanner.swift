//
//  ConsiderDeloadBanner.swift
//  fitbod
//
//  Advisory deload banner scaffold. The Phase 4 default advisory returns
//  false, so this view stays hidden until Phase 5 supplies a real signal.
//  Phase 04.1 (BRU re-skin + D-16 remove Adjust block + D-17 BRUChip DISMISS) — see 04.1-PATTERNS.md File #10
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("▲ FATIGUE ADVISORY")
                        .font(BRUFont.labelSmall)
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .foregroundStyle(Color.bruSignal)
                    Text(suggestion.reason)
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruInk)
                }
                Spacer()
                BRUChip("DISMISS")
                    .frame(minWidth: 44, minHeight: 44)
                    .onTapGesture { dismissed = true }
                    .accessibilityLabel("Dismiss deload advisory")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.bruBg2)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.bruInk)
                    .frame(height: 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Advisory: consider a deload this week. \(suggestion.reason).")
            .accessibilityHint("Tap DISMISS to clear this advisory.")
        }
    }
}
