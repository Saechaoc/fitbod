// DiscardWorkoutButton.swift
// fitbod
//
// DISCARD for a workout in progress, shared by Today's resume slab and
// Program's resume banner so both follow one rule (RM-012,
// docs/design-system/interaction.md#confirmation): with sets or bouts
// logged it asks "Discard workout?" and names them; with nothing logged
// nothing is lost, so it discards at once.
//
// The delete is one throwing save that rolls back when it fails
// (SessionSetActions.deleteWorkout), so a failed discard keeps the workout,
// its rest timer and Live Activity, and says so. The timer is cleared only
// once the delete is saved.
//
// DEBUG: `-fitbod-fail-discard-once` fails the first discard's save, for
// UI tests.

import SwiftUI
import SwiftData

struct DiscardWorkoutButton: View {
    let session: Session
    /// `.ghostOnSlab` on Today's dark slab, `.ghost` on Program's paper banner.
    let kind: BRUButton.Kind

    @Environment(\.modelContext) private var context
    @State private var confirming = false
    @State private var failed = false

    #if DEBUG
    @MainActor private static var failNextDiscard = ProcessInfo.processInfo.arguments.contains("-fitbod-fail-discard-once")
    #endif

    var body: some View {
        BRUButton("Discard", kind: kind, size: .sm) {
            if session.loggedSetCount > 0 {
                confirming = true
            } else {
                discard()
            }
        }
        .alert("Discard workout?", isPresented: $confirming) {
            Button("Discard", role: .destructive, action: discard)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(SessionHistoryFormat.discardWarning(for: session) ?? "No data will be saved.")
        }
        .alert("Couldn't discard workout", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The workout wasn't discarded. Try again.")
        }
    }

    /// Deletes the workout, then clears its persisted rest timer (and the
    /// timer's alert and Live Activity).
    private func discard() {
        let id = session.id
        do {
            #if DEBUG
            if Self.failNextDiscard {
                Self.failNextDiscard = false
                // What a failed save does: the delete is rolled back, then thrown.
                context.delete(session)
                SessionSetActions.rollBack(context)
                throw CocoaError(.fileWriteUnknown)
            }
            #endif
            try SessionSetActions.deleteWorkout(session, context: context)
        } catch {
            failed = true
            return
        }
        RestTimerEngine.clearPersisted(sessionID: id)
    }
}
