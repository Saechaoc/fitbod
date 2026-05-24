//
//  DeloadAdvisoryBanner.swift
//  fitbod
//
//  Phase 5.1 Plan 03 — BRU reskin of the Today-tab top advisory banner.
//
//  Design Pivot line 35: "Full-bleed slab — not an iOS card."
//  Design Pivot lines 84-85: "Plateau banner is a full-bleed Signal slab,
//  not an iOS card."
//
//  Layout:
//    HStack(alignment: .top, spacing: 12)
//      Button (body tap → onTap):
//        VStack(alignment: .leading, spacing: 6)
//          "▲ CONSIDER DELOAD"  — labelSmall, kerning 1.5, bruPaper.opacity(0.7)
//          advisory.bannerCopy  — bodyDefault, bruPaper
//      Button(✕) → onDismiss, .frame(minWidth: 44, minHeight: 44)
//    .padding(.horizontal, 16).padding(.vertical, 14)
//    .background(Color.bruSignal)
//    .overlay top + bottom: 2pt bruInk rules
//
//  Accessibility:
//    Banner root: .accessibilityLabel("Deload advisory: \(advisory.bannerCopy)")
//                 + .isButton trait
//    Dismiss: .accessibilityLabel("Dismiss deload advisory")
//
//  Copy contract (D-16 verbatim, baked into DeloadAdvisory.bannerCopy):
//    Single: "Consider deload — {desc} over last 3 sessions. Tap to see signals."
//    Multi:  "Consider deload — {N} fatigue signals tripped over last 3 sessions. Tap to see signals."
//
//  Public init UNCHANGED (RootView call site preserved):
//    (advisory: DeloadAdvisory, onDismiss: () -> Void, onTapBody: () -> Void)
//
//  BRU contract — ZERO banned tokens:
//    No Color.accentColor, Color(.system*), Color("Volume*"),
//    RoundedRectangle(cornerRadius:), Capsule(),
//    .font(.body|.headline|.caption|.subheadline|.footnote),
//    Image(systemName:), .navigationTitle(
//

import SwiftUI

public struct DeloadAdvisoryBanner: View {
    public let advisory: DeloadAdvisory
    public let onDismiss: () -> Void
    public let onTapBody: () -> Void

    public init(
        advisory: DeloadAdvisory,
        onDismiss: @escaping () -> Void,
        onTapBody: @escaping () -> Void
    ) {
        self.advisory = advisory
        self.onDismiss = onDismiss
        self.onTapBody = onTapBody
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Body tap region — opens DeloadSignalDetailSheet
            Button(action: onTapBody) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("▲ CONSIDER DELOAD")
                        .font(BRUFont.labelSmall)
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruPaper.opacity(0.7))
                    Text(advisory.bannerCopy)
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruPaper)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            // Dismiss button — 44pt minimum hit area (UI-SPEC §Tap targets)
            Button(action: onDismiss) {
                Text("✕")
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruPaper)
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Dismiss deload advisory")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bruSignal)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Deload advisory: \(advisory.bannerCopy)")
        .accessibilityAddTraits(.isButton)
    }
}
