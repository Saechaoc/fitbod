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

/// Full-bleed bruInk slab shown when a session is in-progress (completedAt == nil).
///
/// Layout (top to bottom, 18pt v / 16pt h padding):
/// ```
/// ┌──────────────────────────────────────────────┐  ← bruInk
/// │  RESUME                                       │  10pt caps 0.6 opacity
/// │                                               │  6pt gap
/// │  Push A                                       │  56pt hero bruPaper
/// │                                               │  12pt gap
/// │  14:32  ·  9 SETS LOGGED                      │  10pt caps 0.6 opacity (ticks every second)
/// │                                               │  16pt gap
/// │  [  RESUME ▸  ] [  DISCARD  ]                 │  two equal-width buttons
/// └──────────────────────────────────────────────┘
/// ```
///
/// At accessibility sizes RESUME ▸ spans the slab with DISCARD under it,
/// since half the slab is too narrow to keep "RESUME ▸" on one line.
///
/// Note: The ghost variant's "Discard" button uses bruPaper text + bruPaper outline
/// because the slab background is bruInk — this inverts BRUButton.ghost's defaults
/// (which assume a paper background). A comment in the code documents this inversion.
public struct ResumeWorkoutSlab: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Properties

    let session: Session
    let onResume: @MainActor () -> Void
    let onDiscard: @MainActor () -> Void

    /// Discard confirmation, shown only when completed sets would be lost.
    @State private var confirmingDiscard = false

    // MARK: - Computed

    private var routineDisplayName: String {
        guard !session.routineSnapshotName.isEmpty else { return "Workout" }
        return session.routineSnapshotName
    }

    /// Elapsed time string: "mm:ss" for < 60 min, "h:mm" for >= 60 min
    private func elapsedString(at now: Date) -> String {
        let elapsed = now.timeIntervalSince(session.startedAt)
        let totalSeconds = max(0, Int(elapsed))
        if totalSeconds < 3600 {
            let m = totalSeconds / 60
            let s = totalSeconds % 60
            return String(format: "%d:%02d", m, s)
        } else {
            let h = totalSeconds / 3600
            let m = (totalSeconds % 3600) / 60
            return String(format: "%d:%02d", h, m)
        }
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Micro-leading "RESUME"
            Text("RESUME")
                .font(BRUFont.labelSmall)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruPaper.opacity(0.6))

            // 6pt gap then hero routine name
            Spacer().frame(height: 6)

            BRUDisplay(routineDisplayName, size: .hero, color: .bruPaper)

            // 12pt gap then meta strip
            Spacer().frame(height: 12)

            // TimelineView re-renders the elapsed clock once a second.
            TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
            HStack(spacing: 0) {
                Text(elapsedString(at: context.date))
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruPaper.opacity(0.6))

                Text("  ·  ")
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruPaper.opacity(0.3))

                Text("\(BRUCountLabel.text(session.loggedSetCount, "set")) logged")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruPaper.opacity(0.6))
            }
            }

            // 16pt gap then two equal-width action buttons
            Spacer().frame(height: 16)

            actionLayout {
                // Primary — signal fill (Resume ▸)
                BRUPillButton("Resume ▸", action: onResume)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("resumeSlab.resume")

                // Secondary — ghost but on bruInk slab, so we invert:
                // BRUButton.ghost defaults to bruInk text + bruInk outline on a paper bg.
                // On this bruInk slab background we need bruPaper text + bruPaper outline.
                // We implement this directly rather than through BRUButton to avoid coupling
                // BRUButton to caller context. See threat model T-02.1-04-01 note.
                Button {
                    if session.loggedSetCount > 0 {
                        confirmingDiscard = true
                    } else {
                        discard()
                    }
                } label: {
                    Text("Discard")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        // bruPaper text on bruInk slab — inverted ghost (slab-context inversion)
                        .foregroundStyle(Color.bruPaper)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay(
                            Rectangle()
                                .stroke(Color.bruPaper, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("resumeSlab.discard")
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(Color.bruInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert("Discard workout?", isPresented: $confirmingDiscard) {
            Button("Discard", role: .destructive) { discard() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(BRUCountLabel.text(session.loggedSetCount, "logged set")) will be deleted.")
        }
    }

    /// Clears any persisted rest timer (and its alert + Live Activity)
    /// for this session, then hands off to the caller's delete.
    private func discard() {
        RestTimerEngine.clearPersisted(sessionID: session.id)
        onDiscard()
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
        ResumeWorkoutSlab(session: session, onResume: {}, onDiscard: {})
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
