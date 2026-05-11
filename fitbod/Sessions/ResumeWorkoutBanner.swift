//
//  ResumeWorkoutBanner.swift
//  fitbod
//
//  Top-of-tab banner that appears whenever an active (`completedAt == nil`)
//  `Session` exists. Mounted at the top of:
//
//    - The Routines tab (`RoutinesListView`) — plan 03-01.
//    - The Today tab — plan 03-01 (interim placeholder host).
//    - Future: the Session logger root when reopened (plan 04-01).
//
//  Renders the UI-SPEC verbatim copy:
//
//    "Resume Workout: {routineSnapshotName}"   — primary line
//    "Resume" (accent text)                    — primary CTA
//    "Discard" (destructive text)              — secondary CTA
//
//  The banner uses its own `@Query<Session>` filtered by
//  `completedAt == nil` so it is reactive — when the active session
//  finishes elsewhere (e.g. Finish Workout in the logger), the banner
//  disappears without any explicit dismiss call from the parent.
//
//  When no active session exists the view body is `EmptyView()` — no
//  spacer, no padding. This is load-bearing for `RoutinesListView`'s
//  empty-state path: mounting the banner unconditionally at the top of
//  the list MUST NOT push the empty-state heading off-screen when there
//  is no active session.
//
//  ## Mounting inside a `List`
//
//  Per plan 03-01's "Anti-Patterns to Avoid" list, this banner is mounted
//  as the first row of the routines `List` using `.listRowInsets(EdgeInsets())`
//  + `.listRowBackground(Color.clear)` so it visually floats above the
//  sectioned content. Mounting it as a separate view above the
//  `NavigationStack`'s content would break the sectioned-list shape (the
//  banner would push the search bar / section headers down).
//
//  ## Resume / Discard side effects
//
//  - "Resume" tap → fires `onResume(activeSession)`. Plan 04-01 wires this
//    to push `SessionLoggerView(session: activeSession)` via the parent's
//    `NavigationPath`. Plan 03-01 stubs the closure as a no-op pending
//    that wiring.
//
//  - "Discard" tap → opens an `.alert` confirmation ("Discard active
//    workout?") because deleting an active session is destructive (the
//    user loses any logged sets). On confirm, fires
//    `onDiscard(activeSession)` which the parent uses to delete the
//    session via `ctx.delete(...)` + `ctx.save()`.
//

import SwiftUI
import SwiftData

public struct ResumeWorkoutBanner: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Session> { $0.completedAt == nil })
    private var activeSessions: [Session]

    public let onResume: (Session) -> Void
    public let onDiscard: (Session) -> Void

    @State private var discardConfirm = false

    public init(
        onResume: @escaping (Session) -> Void,
        onDiscard: @escaping (Session) -> Void
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
            Image(systemName: "arrow.uturn.backward.circle")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading) {
                Text("Resume Workout: \(active.routineSnapshotName)")
                    .font(.headline)
            }
            Spacer()
            Button("Resume") { onResume(active) }
                .foregroundStyle(Color.accentColor)
            Button("Discard", role: .destructive) {
                discardConfirm = true
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .alert(
            "Discard active workout?",
            isPresented: $discardConfirm
        ) {
            Button("Discard", role: .destructive) {
                onDiscard(active)
                discardConfirm = false
            }
            Button("Cancel", role: .cancel) {
                discardConfirm = false
            }
        }
    }
}

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
