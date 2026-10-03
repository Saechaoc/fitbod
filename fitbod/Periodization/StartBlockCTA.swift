//
//  StartBlockCTA.swift
//  fitbod
//
//  Today empty-state call-to-action when no block is active.
//  BRU reskin: paper background, displayLarge heading, muted body,
//  signal-text inline button (NOT a filled button). No rounded corners.
//  Phase 04.1 (BRU re-skin) — see 04.1-PATTERNS.md File #11
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
                .font(BRUFont.displayLarge)
                .foregroundStyle(Color.bruInk)

            Text("Define a training block to see your phase, week, and deloads here.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)

            Button(action: onStart) {
                // Mixed-case source string, uppercased for display, so
                // VoiceOver reads words instead of spelling letters.
                Text("Start a block")
                    .font(BRUFont.labelSmall)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.bruSignal)
                    .bruHitArea()
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.bruPaper)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#if DEBUG
#Preview("StartBlockCTA") {
    StartBlockCTA(onStart: {})
        .background(Color.bruPaper)
}
#endif
