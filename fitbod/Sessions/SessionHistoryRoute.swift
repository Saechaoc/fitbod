// SessionHistoryRoute.swift
// fitbod
//
// Routes into workout history. Today and Progress each register
// `.sessionHistoryDestinations()` on their NavigationStack, so the history
// list and a past workout's summary push on whichever tab opened them.
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor /
//               NO Image(systemName:) / NO Color(.system*) /
//               NO .font(.body/.headline/.title*/caption)

import SwiftUI
import SwiftData

public enum SessionHistoryRoute: Hashable, Sendable {
    /// Every finished workout, newest first.
    case list
    /// One finished workout's summary.
    case summary(sessionID: UUID)
}

extension View {
    /// Registers the `SessionHistoryRoute` destinations on the enclosing
    /// NavigationStack.
    func sessionHistoryDestinations() -> some View {
        navigationDestination(for: SessionHistoryRoute.self) { route in
            switch route {
            case .list:
                SessionHistoryView()
            case .summary(let sessionID):
                SessionSummaryDestination(sessionID: sessionID)
            }
        }
    }
}

/// Looks the session up by id when the summary is pushed. If it was
/// deleted while the route sat on the stack, says so instead of showing
/// an empty screen.
private struct SessionSummaryDestination: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var matches: [Session]

    init(sessionID: UUID) {
        _matches = Query(filter: #Predicate<Session> { $0.id == sessionID })
    }

    var body: some View {
        if let session = matches.first {
            SessionDetailView(session: session)
        } else {
            VStack(spacing: 8) {
                Text("Workout not found")
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruInk)
                Text("It may have been deleted.")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.bruPaper.ignoresSafeArea())
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top, spacing: 0) {
                BRUHeaderBar(left: HeaderAction("‹ Back") { dismiss() }, center: "Summary")
            }
        }
    }
}
