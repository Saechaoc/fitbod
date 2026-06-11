//
//  LiveEditBanner.swift
//  fitbod
//
//  Phase 09-01 — reusable live-edit warning banner.
//  Shown when a Routine (Split) sits on an active Block; also shown in
//  RoutineBuilderView when the SessionTemplate is reachable via an active block.
//
//  Anatomy per UI-SPEC §7:
//    HStack(spacing: 0):
//      4pt bruSignal left stripe
//      VStack: "ACTIVE BLOCK" label + body text
//      Spacer
//  .frame(minHeight: 44)
//  .background(Color.bruBg2)
//  .overlay(alignment: .bottom) { BRUDivider(.ink) }
//
//  BRU contract: NO Capsule / NO RoundedRectangle / NO Image(systemName:) /
//    NO .font(.body/.headline/.title*)
//
//  Copy (verbatim from UI-SPEC Copywriting Contract):
//    Label:  "ACTIVE BLOCK"
//    Body:   "Part of active block — edits apply to upcoming workouts."
//

import SwiftUI

// MARK: - LiveEditBanner

/// Non-blocking warning banner displayed when a routine or session template
/// is reachable via an active block.
///
/// Positioned immediately below `BRUHeaderBar`, above the scroll content.
/// No dismiss button — presence is reactive (disappears if block ends between edits).
///
/// Usage:
/// ```swift
/// if liveActiveBlock != nil {
///     LiveEditBanner()
/// }
/// ```
public struct LiveEditBanner: View {

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Left accent stripe — 4pt bruSignal (UI-SPEC §7)
            Rectangle()
                .fill(Color.bruSignal)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                // "ACTIVE BLOCK" label — labelSmall UPPERCASE tracking 1.2 bruSignal
                Text("ACTIVE BLOCK")
                    .font(BRUFont.labelSmall)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.bruSignal)

                // Body — bodyDefault bruMuted
                Text("Part of active block — edits apply to upcoming workouts.")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Spacer()
        }
        .frame(minHeight: 44)
        .background(Color.bruBg2)
        .overlay(alignment: .bottom) {
            BRUDivider(.ink)
        }
        // Accessibility: combine children so VoiceOver reads as a single element
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Active block warning: Part of active block — edits apply to upcoming workouts.")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("LiveEditBanner") {
    VStack(spacing: 0) {
        LiveEditBanner()
        Spacer()
    }
    .background(Color.bruPaper)
}
#endif
