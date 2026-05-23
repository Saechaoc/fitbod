//
//  DeloadWeekBanner.swift
//  fitbod
//
//  Non-dismissible scheduled deload banner for Today.
//

import SwiftUI

public struct DeloadWeekBanner: View {
    public let currentPhaseKind: BlockPhaseKind

    public init(currentPhaseKind: BlockPhaseKind) {
        self.currentPhaseKind = currentPhaseKind
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Deload week — recover, don't load.")
                .font(.headline)
            Text("Working sets cut by ~50%. Weights held to phase intensity.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(BlockPhaseColors.tint(for: .deload))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Deload week active. Working sets are cut by approximately fifty percent. Weights are held at deload phase intensity.")
    }
}
