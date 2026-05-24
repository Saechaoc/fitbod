// WorkoutHeaderToolbar.swift
// fitbod
//
// NEW — Phase 2.1 Plan 08 (Wave 4, UI-REVIEW item 47).
// UI-SPEC v2 § Session logger line 363-366 + 584.
//
// Extracted 3-line principal toolbar block per UI-SPEC line 363-366 + 584.
// Used by SessionLoggerView's .safeAreaInset(edge: .top) BELOW the BRUHeaderBar.
//
// Layout:
//   Line 1 (HStack): routineSnapshotName (displayMedium bruInk) | elapsedLabel (bodyEmphasis muted right)
//   Line 2:          IntentChip(intent: session.intent)
//
// NOTE: SessionLoggerView wraps this in a TimelineView(.periodic(from:by:1)) for
// live elapsed updates. This struct is stateless — it receives the pre-computed
// elapsedLabel string rather than computing it internally.
//
// BRU contract:
//   NO .navigationTitle / NO .toolbar with system chrome
//   NO Capsule() / NO RoundedRectangle / NO accentColor
//   NO Image(systemName:) / NO .font(.body/.headline/.title/.caption)
//   NO Color(.system*)

import SwiftUI
import SwiftData

// MARK: - WorkoutHeaderToolbar

/// Extracted 3-line principal toolbar block for the active workout session surface.
///
/// Mount inside a `TimelineView` for live elapsed updates:
/// ```swift
/// TimelineView(.periodic(from: elapsedStart, by: 1)) { _ in
///     WorkoutHeaderToolbar(session: session, elapsedLabel: elapsedLabel)
/// }
/// ```
public struct WorkoutHeaderToolbar: View {

    // MARK: Properties

    public let session: Session
    public let elapsedLabel: String

    // MARK: Init

    public init(session: Session, elapsedLabel: String) {
        self.session = session
        self.elapsedLabel = elapsedLabel
    }

    // MARK: Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Line 1: routine name + elapsed timer
            HStack {
                Text(session.routineSnapshotName)                                  // UI-SPEC line 362
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruInk)

                Spacer()

                Text(elapsedLabel)                                                 // "32:14" per UI-SPEC
                    .font(BRUFont.bodyEmphasis)
                    .monospacedDigit()
                    .foregroundStyle(Color.bruMuted)
            }

            // Line 2: intent chip
            IntentChip(intent: session.intent)                                     // UI-SPEC line 363
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.bruPaper)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("workout header toolbar — strength") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let session = Session()
    session.startedAt = .now
    session.routineSnapshotName = "Push Day A"
    session.intentRaw = Intent.strength.rawValue
    ctx.insert(session)
    try? ctx.save()
    return VStack(spacing: 0) {
        WorkoutHeaderToolbar(session: session, elapsedLabel: "32:14")
        Color.bruBg
    }
    .modelContainer(container)
}

#Preview("workout header toolbar — hypertrophy") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let session = Session()
    session.startedAt = .now
    session.routineSnapshotName = "Pull Day B — Week 3"
    session.intentRaw = Intent.hypertrophy.rawValue
    ctx.insert(session)
    try? ctx.save()
    return VStack(spacing: 0) {
        WorkoutHeaderToolbar(session: session, elapsedLabel: "1:04:22")
        Color.bruBg
    }
    .modelContainer(container)
}
#endif
