//
//  DeloadWeekBanner.swift
//  fitbod
//
//  Non-dismissible scheduled deload banner for Today.
//  Phase 04.1 (BRU re-skin) — see 04.1-PATTERNS.md File #9
//

import SwiftUI

public struct DeloadWeekBanner: View {
    public let currentPhaseKind: BlockPhaseKind

    public init(currentPhaseKind: BlockPhaseKind) {
        self.currentPhaseKind = currentPhaseKind
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("▲ DELOAD WEEK")
                .font(BRUFont.labelSmall)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(Color.bruSignal)
            Text("Deload week — recover, don't load.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
            Text("Working sets cut by ~50%. Weights held to phase intensity.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Deload week active. Working sets are cut by approximately fifty percent. Weights are held at deload phase intensity.")
    }
}
