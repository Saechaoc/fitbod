// ResumeWorkoutBanner.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 08 (Wave 4, UI-REVIEW item 45).
// UI-SPEC v2 § Session logger line 583.
//
// Slim resume banner that appears whenever an active (completedAt == nil)
// Session exists. Mounted at the top of the Routines tab (RoutinesListView).
//
// NOTE: This is DISTINCT from Plan 02.1-04's ResumeWorkoutSlab which lives in
// fitbod/Views/. This banner (Sessions/) is the slim variant used in the
// session logger context.
//
// UI-SPEC verbatim copy:
//   Leading label:  "RESUME"              (labelSmall bruMuted)
//   Routine name:   routineSnapshotName   (bodyEmphasis bruInk)
//   Meta:           "{elapsed} · 1 set" / "{elapsed} · {n} sets" (labelSmall bruMuted)
//   CTA:            BRUPillButton("Resume ▸")
//
// Style: 2pt bruInk-bordered Rectangle slim band per UI-SPEC line 583.
//
// The banner uses its own @Query<Session> filtered by completedAt == nil so
// it is reactive — when the active session finishes elsewhere the banner
// disappears without any explicit dismiss call from the parent.
//
// When no active session exists the view body is EmptyView().
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
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Session> { $0.completedAt == nil })
    private var activeSessions: [Session]

    public let onResume: @MainActor (Session) -> Void
    public let onDiscard: @MainActor (Session) -> Void

    @State private var discardConfirm = false

    public init(
        onResume: @escaping @MainActor (Session) -> Void,
        onDiscard: @escaping @MainActor (Session) -> Void
    ) {
        self.onResume = onResume
        self.onDiscard = onDiscard
    }

    public var body: some View {
        if let active = activeSessions.first {
            bannerBody(active: active)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func bannerBody(active: Session) -> some View {
        HStack(spacing: 12) {
            // Left: stacked labels
            VStack(alignment: .leading, spacing: 4) {
                Text("RESUME")                                                      // UI-SPEC verbatim
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)

                Text(active.routineSnapshotName)
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)

                TimelineView(.periodic(from: active.startedAt, by: 1)) { _ in
                    Text("\(elapsedLabel(for: active)) · \(BRUCountLabel.text(active.loggedSetCount, "set"))")
                        .font(BRUFont.labelSmall)
                        .tracking(0.5)
                        .foregroundStyle(Color.bruMuted)
                }
            }

            Spacer()

            // Right: Resume CTA
            BRUPillButton("Resume ▸") {                                            // UI-SPEC verbatim
                onResume(active)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.bruPaper)
        .overlay(
            Rectangle()
                .stroke(Color.bruInk, lineWidth: 2)                               // 2pt bruInk border per UI-SPEC line 583
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        // Discard is exposed via swipe / contextMenu per plan spec — alert confirmation retained
        .contextMenu {
            Button("Discard", role: .destructive) {
                discardConfirm = true
            }
        }
        .alert(
            "Discard active workout?",
            isPresented: $discardConfirm
        ) {
            Button("Discard", role: .destructive) {
                RestTimerEngine.clearPersisted(sessionID: active.id)
                onDiscard(active)
                discardConfirm = false
            }
            Button("Cancel", role: .cancel) {
                discardConfirm = false
            }
        }
    }

    /// Formats elapsed time since session start as "HH:MM" or "MM:SS".
    private func elapsedLabel(for session: Session) -> String {
        let elapsed = Int(Date().timeIntervalSince(session.startedAt))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return String(format: "%d:%02d", hours, mins)
        }
        return String(format: "%d:%02d", minutes, seconds)
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
    return List {
        ResumeWorkoutBanner(
            onResume: { _ in },
            onDiscard: { _ in }
        )
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
    .modelContainer(container)
}

#Preview("no active session") {
    List {
        ResumeWorkoutBanner(
            onResume: { _ in },
            onDiscard: { _ in }
        )
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
    .modelContainer(PreviewModelContainer.make())
}
#endif
