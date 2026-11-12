// ResumeWorkoutBanner.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 08 (Wave 4, UI-REVIEW item 45).
// UI-SPEC v2 § Session logger line 583.
//
// Slim resume banner for the workout in progress, mounted at the top of
// the Program tab (ProgramView), which owns the query for it.
//
// NOTE: This is DISTINCT from Plan 02.1-04's ResumeWorkoutSlab which lives in
// fitbod/Views/ and shows on Today.
//
// UI-SPEC verbatim copy:
//   Leading label:  "RESUME"              (labelSmall bruMuted)
//   Routine name:   routineSnapshotName   (bodyEmphasis bruInk)
//   Meta:           "{elapsed} · 1 set" / "{elapsed} · {n} sets" (labelSmall bruMuted);
//                   "{elapsed}" alone once only cardio bouts are logged (RM-062)
//   CTA:            BRUPillButton("Resume ▸") beside a ghost "Discard" (RM-012)
//
// Style: 2pt bruInk-bordered Rectangle slim band per UI-SPEC line 583.
//
// RESUME ▸ is the page's one signal (RM-012). DISCARD is a visible ghost
// button with Today's rule (DiscardWorkoutButton): it asks first only when
// sets are logged. The two share a row under the labels, or stack at
// accessibility sizes.
//
// BRU contract:
//   NO rounded-rectangle shape — removed per plan spec
//   NO accent color — removed per UI-SPEC line 214
//   NO arrow.uturn SF symbol — removed
//   NO capsule shape / NO .font(.body/.headline/.title/.caption)
//   NO Color(.system*)

import SwiftUI
import SwiftData

public struct ResumeWorkoutBanner: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let session: Session
    let onResume: @MainActor () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("RESUME")                                                      // UI-SPEC verbatim
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)

                Text(session.displayName)
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)

                TimelineView(.periodic(from: session.startedAt, by: 1)) { _ in
                    Text(Self.caption(for: session, elapsed: elapsedLabel))
                        .font(BRUFont.labelSmall)
                        .tracking(0.5)
                        .foregroundStyle(Color.bruMuted)
                }
            }

            actionLayout {
                BRUPillButton("Resume ▸") {                                        // UI-SPEC verbatim
                    onResume()
                }
                .accessibilityIdentifier("resumeBanner.resume")

                DiscardWorkoutButton(session: session, kind: .ghost)
                    .accessibilityIdentifier("resumeBanner.discard")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bruPaper)
        .overlay(
            Rectangle()
                .stroke(Color.bruInk, lineWidth: 2)                               // 2pt bruInk border per UI-SPEC line 583
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// RESUME ▸ beside DISCARD, or above it at accessibility sizes, where
    /// half the banner breaks "RESUME ▸" mid-word.
    private var actionLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
    }

    /// Elapsed time since session start: "m:ss" below an hour, "h:mm" from
    /// an hour on.
    private var elapsedLabel: String {
        NumberText.elapsed(max(0, Int(Date().timeIntervalSince(session.startedAt))))
    }

    /// "12:34 · 3 sets", or the time alone once only cardio bouts are
    /// logged (RM-062).
    static func caption(for session: Session, elapsed: String) -> String {
        guard let sets = SessionHistoryFormat.inProgressSetCount(of: session) else { return elapsed }
        return "\(elapsed) · \(BRUCountLabel.text(sets, "set"))"
    }
}

#if DEBUG
#Preview("active session") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let session = Session()
    session.startedAt = .now
    session.completedAt = nil
    session.routineSnapshotName = "Push Day A"
    ctx.insert(session)
    try? ctx.save()
    return ResumeWorkoutBanner(session: session, onResume: {})
        .background(Color.bruPaper)
        .modelContainer(container)
}
#endif
