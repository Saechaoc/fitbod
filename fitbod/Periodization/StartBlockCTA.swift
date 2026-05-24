//
//  StartBlockCTA.swift
//  fitbod
//
//  Today empty-state call-to-action when no block is active.
//  BRU reskin: full-bleed paper slab, display headline, muted body,
//  signal-fill BRUPillButton CTA. No Apple HIG defaults.
//

import SwiftUI

public struct StartBlockCTA: View {
    public let onStart: () -> Void

    public init(onStart: @escaping () -> Void) {
        self.onStart = onStart
    }

    public var body: some View {
        VStack(spacing: 12) {
            Text("No active block")
                .font(BRUFont.displayLarge)
                .foregroundStyle(Color.bruInk)
                .multilineTextAlignment(.center)

            Text("Define a training block to see your phase, week, and deloads here.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .multilineTextAlignment(.center)

            BRUPillButton("Start a block ▸", action: onStart)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
        .background(Color.bruPaper)
    }
}

#if DEBUG
#Preview("StartBlockCTA") {
    StartBlockCTA(onStart: {})
        .background(Color.bruPaper)
}
#endif
