//
//  DeloadAdvisoryBanner.swift
//  fitbod
//
//  Phase 5 PROG-06 — dismissible Today-tab top banner. Mounted via
//  `.safeAreaInset(edge: .top)` on TodayView, ABOVE the BlockCard +
//  ResumeWorkoutBanner per UI-SPEC §Phase 4 ↔ Phase 5 Boundary
//  Reminders.
//
//  Layout (UI-SPEC §Layout & Spacing §DeloadAdvisoryBanner): HStack
//  with leading copy + Spacer + trailing xmark dismiss button (44pt
//  hit area). Background: `Color("VolumeNearMRVAmber").opacity(0.15)`
//  (Asset Catalog entry from plan 01). Padding 16h / 12v.
//
//  Tap routes:
//    Banner body → onTapBody (RootView opens DeloadSignalDetailSheet)
//    xmark       → onDismiss  (RootView writes
//                  settings.deloadAdvisoryDismissedWeekStart =
//                  advisory.weekStart, per D-17)
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
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(advisory.bannerCopy)
                    .font(.body)
            }
            .contentShape(Rectangle())
            .onTapGesture { onTapBody() }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Deload advisory: \(advisory.bannerCopy)")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Tap to see signals.")

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel("Dismiss deload advisory")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color("VolumeNearMRVAmber").opacity(0.15))
    }
}
