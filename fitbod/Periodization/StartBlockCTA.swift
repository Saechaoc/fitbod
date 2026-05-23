//
//  StartBlockCTA.swift
//  fitbod
//
//  Today empty-state call-to-action when no block is active.
//

import SwiftUI

public struct StartBlockCTA: View {
    public let onStart: () -> Void

    public init(onStart: @escaping () -> Void) {
        self.onStart = onStart
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No active block.")
                .font(.headline)
            Text("Define a training block to see your phase, week, and deloads here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            Button("Start a Block", action: onStart)
                .foregroundStyle(Color.accentColor)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
