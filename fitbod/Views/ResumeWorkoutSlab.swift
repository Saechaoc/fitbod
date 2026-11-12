// ResumeWorkoutSlab.swift
// fitbod — Phase 2.1 Plan 04
//
// "RESUME · {routine} · {elapsed} · Resume ▸ | Discard" ink slab.
// Replaces BlackSlabCTA when an active Session (completedAt == nil) exists.
// Reference: UI-SPEC line 298 + 538
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
// NO .font(.body/.headline/.title*/.caption)

import SwiftUI
import SwiftData

// MARK: - ResumeWorkoutSlab

/// Full-bleed bruSlab slab shown when a session is in-progress (completedAt == nil).
/// The slab stays dark in dark mode (FT-14); its text and outlines use bruOnSlab.
///
/// Layout (top to bottom, 18pt v / 16pt h padding):
/// ```
/// ┌──────────────────────────────────────────────┐  ← bruSlab (dark in both appearances)
/// │  RESUME                                       │  10pt caps 0.6 opacity
/// │                                               │  6pt gap
/// │  Push A                                       │  56pt hero bruOnSlab
/// │                                               │  12pt gap
/// │  14:32  ·  9 SETS LOGGED                      │  10pt caps 0.6 opacity (ticks every second)
/// │                                               │  16pt gap
/// │  [  RESUME ▸  ] [  DISCARD  ]                 │  two equal-width buttons
/// └──────────────────────────────────────────────┘
/// ```
///
/// Once only cardio bouts are logged, the meta strip shows the time alone,
/// since set counts leave bouts out (RM-062).
///
/// At accessibility sizes RESUME ▸ spans the slab with DISCARD under it,
/// since half the slab is too narrow to keep "RESUME ▸" on one line.
///
/// DISCARD is `DiscardWorkoutButton` in BRUButton's `.ghostOnSlab` kind:
/// bruOnSlab text and outline, since the plain ghost draws ink for paper.
public struct ResumeWorkoutSlab: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Properties

    let session: Session
    let onResume: @MainActor () -> Void

    // MARK: - Computed

    private var routineDisplayName: String {
        guard !session.routineSnapshotName.isEmpty else { return "Workout" }
        return session.routineSnapshotName
    }

    /// Elapsed time: "m:ss" below an hour, "h:mm" from an hour on.
    private func elapsedString(at now: Date) -> String {
        NumberText.elapsed(max(0, Int(now.timeIntervalSince(session.startedAt))))
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Micro-leading "RESUME"
            Text("RESUME")
                .font(BRUFont.labelSmall)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruOnSlab.opacity(0.6))

            // 6pt gap then hero routine name
            Spacer().frame(height: 6)

            BRUDisplay(routineDisplayName, size: .hero, color: .bruOnSlab)

            // 12pt gap then meta strip
            Spacer().frame(height: 12)

            // TimelineView re-renders the elapsed clock once a second.
            TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
            HStack(spacing: 0) {
                Text(elapsedString(at: context.date))
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruOnSlab.opacity(0.6))

                if let logged = Self.loggedCaption(for: session) {
                    Text("  ·  ")
                        .font(BRUFont.labelSmall)
                        .foregroundStyle(Color.bruOnSlab.opacity(0.3))

                    Text(logged)
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruOnSlab.opacity(0.6))
                }
            }
            }

            // 16pt gap then two equal-width action buttons
            Spacer().frame(height: 16)

            actionLayout {
                // Primary — signal fill (Resume ▸)
                BRUPillButton("Resume ▸", action: onResume)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("resumeSlab.resume")

                // Secondary: the ghost on the dark slab, bruOnSlab text and
                // outline. It asks first only when sets are logged, as
                // Program's banner does, and deletes in one save.
                DiscardWorkoutButton(session: session, kind: .ghostOnSlab)
                    .accessibilityIdentifier("resumeSlab.discard")
            }
            .bruButtonsShareHeight()
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(Color.bruSlab)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "3 sets logged"; nil once only cardio bouts are logged, which show
    /// no set count (RM-062).
    static func loggedCaption(for session: Session) -> String? {
        SessionHistoryFormat.inProgressSetCount(of: session).map { "\(BRUCountLabel.text($0, "set")) logged" }
    }

    /// RESUME ▸ beside DISCARD, or above it at accessibility sizes.
    private var actionLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
    }
}

// MARK: - Preview

#if DEBUG
private struct ResumeWorkoutSlabPreviewContainer: View {
    let container: ModelContainer
    let session: Session

    var body: some View {
        ResumeWorkoutSlab(session: session, onResume: {})
            .modelContainer(container)
    }

    static func make() -> ResumeWorkoutSlabPreviewContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Session.self, configurations: config)
        let session = Session()
        session.routineSnapshotName = "Push A"
        session.startedAt = Date.now.addingTimeInterval(-875)  // ~14.5 min ago
        container.mainContext.insert(session)
        return ResumeWorkoutSlabPreviewContainer(container: container, session: session)
    }
}

#Preview("ResumeWorkoutSlab") {
    ResumeWorkoutSlabPreviewContainer.make()
}
#endif
