//
//  ArchivedRoutinesView.swift
//  fitbod
//
//  Ticket T20 - the archived routines (code `Split` with `isArchived`),
//  pushed from Program's "Archived routines" entry, which Program shows only
//  while at least one routine is archived (tradeoffs.md "Archived routines").
//  RESTORE clears `isArchived`, so the routine is back in every routine list
//  at once. Archive stays a soft delete: nothing here deletes a routine.
//
//  Composition (top to bottom):
//    BRUHeaderBar (left: .back, center: "Archived routines", one line at default text)
//    ScrollView { LazyVStack: one ArchivedRoutineRow per archived routine,
//      by name, or "No archived routines." once the last one is restored }
//
//  Navigation: pushed via ArchivedRoutinesRoute on Program's NavigationStack.
//  No child NavigationStack - one stack per tab rule.
//

import SwiftUI
import SwiftData

// MARK: - ArchivedRoutinesRoute

/// Typed route for pushing ArchivedRoutinesView onto Program's NavigationPath.
public enum ArchivedRoutinesRoute: Hashable, Sendable {
    case list
}

// MARK: - ArchivedRoutinesView

public struct ArchivedRoutinesView: View {

    @Environment(\.modelContext) private var ctx
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // Archived splits only - isArchived is a stored Bool, so predicate-safe.
    @Query(
        filter: #Predicate<Split> { $0.isArchived },
        sort: [SortDescriptor(\Split.name)]
    )
    private var archivedSplits: [Split]

    @State private var showSaveError = false

    public init() {}

    /// The header fits a title with no breaking space to its third of the
    /// row, shrinking it if it must, and wraps one with a space. At default
    /// text and smaller a no-break space keeps "Archived routines" on one
    /// line, at about 0.85 of its size on the small phone (T38, finding
    /// F149), as the weekly recap's title does. Larger text keeps the space
    /// and wraps between the words, as before. VoiceOver reads the title the
    /// same either way.
    private var title: String {
        dynamicTypeSize <= .large ? "Archived\u{00A0}routines" : "Archived routines"
    }

    public var body: some View {
        VStack(spacing: 0) {
            BRUHeaderBar.slots(left: .back, center: title)

            ScrollView {
                LazyVStack(spacing: 0) {
                    if archivedSplits.isEmpty {
                        Text("No archived routines.")
                            .font(BRUFont.bodyDefault)
                            .foregroundStyle(Color.bruMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }

                    ForEach(archivedSplits) { split in
                        ArchivedRoutineRow(split: split, onRestore: { restore(split) })
                        BRUDivider(.hair)
                    }
                }
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
        .alert("Couldn't Save", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Couldn't save. Try again.")
        }
    }

    /// Makes the routine active again. On save failure the flag reverts, so
    /// the row stays while the store still holds the routine as archived.
    private func restore(_ split: Split) {
        split.isArchived = false
        do {
            try ctx.save()
        } catch {
            split.isArchived = true
            showSaveError = true
        }
    }
}

// MARK: - ArchivedRoutineRow

/// One archived routine: its name and session count, then RESTORE, which
/// moves under the name at accessibility sizes.
fileprivate struct ArchivedRoutineRow: View {

    let split: Split
    let onRestore: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var name: String {
        split.name.isEmpty ? "Untitled Routine" : split.name
    }

    var body: some View {
        rowLayout {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(BRUCountLabel.text(split.slots?.count ?? 0, "session"))
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            // BRUButton fills its width, so it keeps its own size in the row.
            BRUButton("Restore", kind: .ghost, size: .sm, action: onRestore)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel("Restore \(name)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 64)
    }

    private var rowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
    }
}
