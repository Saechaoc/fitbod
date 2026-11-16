//
//  ArchivedRoutinesView.swift
//  fitbod
//
//  Ticket T20 - the archived routines (code `Split` with `isArchived`),
//  pushed from Program's "Archived routines" entry, which Program shows only
//  while at least one routine is archived.
//  RESTORE clears `isArchived`, so the routine is back in every routine list
//  at once. Archive stays a soft delete: nothing here deletes a routine.
//  A row opens ArchivedRoutineView, which shows the routine read only, so
//  it can be checked before it is restored (RM-026, D-33).
//
//  Composition (top to bottom):
//    BRUHeaderBar (left: .back, center: "Archived routines", one line at default text)
//    ScrollView { LazyVStack: one ArchivedRoutineRow per archived routine,
//      by name, or "No archived routines." once the last one is restored }
//
//  ArchivedRoutineView (top to bottom):
//    BRUHeaderBar (left: .back, center: "Archived routine")
//    The routine's name over "3 sessions · rotates in order"
//    SESSIONS: each session in rotation order over its summary line
//    USED IN: each block that used the routine, with its status, and its
//      weeks, dates and workouts once it has ended
//    RESTORE ROUTINE, the screen's one write, which goes back to the list
//
//  Navigation: pushed via ArchivedRoutinesRoute on Program's NavigationStack;
//  a row pushes ArchivedRoutineView on the same stack. No child
//  NavigationStack - one stack per tab rule.
//

import SwiftUI
import SwiftData

// MARK: - ArchivedRoutinesRoute

/// Typed route for pushing ArchivedRoutinesView onto Program's NavigationPath.
public enum ArchivedRoutinesRoute: Hashable, Sendable {
    case list
}

// MARK: - Restore

/// Makes an archived routine active again: the one write RESTORE makes, on
/// the list and on the routine's page. A failed save rolls the context
/// back, so the routine reads archived again, as the store still holds
/// it, and throws.
@MainActor
func restoreRoutine(
    _ split: Split, context: ModelContext,
    save: (ModelContext) throws -> Void = { try $0.save() }
) throws {
    split.isArchived = false
    do {
        try save(context)
    } catch {
        SessionSetActions.rollBack(context)
        throw error
    }
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
    /// The routine a row opened.
    @State private var openedSplit: Split?

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
                        ArchivedRoutineRow(
                            split: split,
                            onOpen: { openedSplit = split },
                            onRestore: { restore(split) }
                        )
                        BRUDivider(.hair)
                    }
                }
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(item: $openedSplit) { split in
            ArchivedRoutineView(split: split)
        }
        .alert("Couldn't Save", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Couldn't save. Try again.")
        }
    }

    /// Makes the routine active again. On save failure the row stays,
    /// since the store still holds the routine as archived.
    private func restore(_ split: Split) {
        do {
            try restoreRoutine(split, context: ctx)
        } catch {
            showSaveError = true
        }
    }
}

// MARK: - ArchivedRoutineRow

/// One archived routine: its name and session count, which open it, then
/// RESTORE, which moves under the name at accessibility sizes.
fileprivate struct ArchivedRoutineRow: View {

    let split: Split
    let onOpen: () -> Void
    let onRestore: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var name: String {
        split.name.isEmpty ? "Untitled Routine" : split.name
    }

    var body: some View {
        rowLayout {
            Button(action: onOpen) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
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
                    ProgramRowChevron()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.bruRow)

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

// MARK: - ArchivedRoutineView

/// An archived routine, read only, so the lifter can check what it holds
/// before restoring it (RM-026, D-33): its sessions in rotation order, as
/// the routine's own screen lists them, the blocks that used it, and
/// RESTORE ROUTINE. Nothing else here writes. Once the restore saves, the
/// screen goes back to the list, which no longer holds the routine.
struct ArchivedRoutineView: View {

    let split: Split

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var showSaveError = false

    /// One line at default text and smaller, as the list's title is.
    private var title: String {
        dynamicTypeSize <= .large ? "Archived\u{00A0}routine" : "Archived routine"
    }

    /// The sessions in rotation order.
    static func sessions(of split: Split) -> [SplitSessionSlot] {
        (split.slots ?? []).sorted { $0.position < $1.position }
    }

    /// The blocks that used the routine, in Program's order: the active one
    /// first, then ready and draft ones, then the ended ones, newest first.
    static func blocks(of split: Split) -> [Block] {
        let blocks = ProgramBlocks(split.blocks ?? [])
        return (blocks.active.map { [$0] } ?? []) + blocks.ready + blocks.drafts + blocks.past
    }

    var body: some View {
        let sessions = Self.sessions(of: split)
        VStack(spacing: 0) {
            BRUHeaderBar.slots(left: .back, center: title)

            ScrollView {
                VStack(spacing: 0) {
                    titleBlock(sessionCount: sessions.count)
                    sessionsSection(sessions)
                    usedInSection(Self.blocks(of: split))
                    restoreSection
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

    // MARK: - Title

    private func titleBlock(sessionCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(split.name.isEmpty ? "Untitled Routine" : split.name)
                .font(BRUFont.condensedTitle)
                .foregroundStyle(Color.bruInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(BRUCountLabel.text(sessionCount, "session") + " · rotates in order")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .overlay(alignment: .bottom) { BRUDivider(.ink) }
    }

    // MARK: - Sessions

    @ViewBuilder
    private func sessionsSection(_ sessions: [SplitSessionSlot]) -> some View {
        BRUSectionHead("Sessions")
        if sessions.isEmpty {
            emptyLine("No sessions.")
        }
        ForEach(Array(sessions.enumerated()), id: \.element.id) { index, slot in
            if index > 0 {
                BRUDivider(.hair)
            }
            sessionRow(slot, number: index + 1)
        }
        BRUDivider(.ink)
    }

    /// "01" beside the session's name and summary line, as the routine's
    /// own screen draws it, without the controls that change it.
    private func sessionRow(_ slot: SplitSessionSlot, number: Int) -> some View {
        let name = slot.sessionTemplate?.name ?? "Missing session"
        let summary = slot.sessionTemplate.map { SessionTemplateSummary(template: $0).line }
        return HStack(alignment: dynamicTypeSize.isAccessibilitySize ? .firstTextBaseline : .center, spacing: 12) {
            Text(String(format: "%02d", number))
                .font(BRUFont.condensedLabel)
                .foregroundStyle(Color.bruMuted)
                .fixedSize()
                .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 32, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruInk)
                    .fixedSize(horizontal: false, vertical: true)
                if let summary {
                    Text(summary)
                        .font(BRUFont.labelSmall)
                        .tracking(1.0)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 64)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Session \(number): \(name)")
        .accessibilityValue(summary ?? "")
    }

    // MARK: - Used in

    @ViewBuilder
    private func usedInSection(_ blocks: [Block]) -> some View {
        BRUSectionHead("Used in")
        if blocks.isEmpty {
            emptyLine("No block has used it.")
        }
        ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
            if index > 0 {
                BRUDivider(.hair)
            }
            blockRow(block)
        }
        BRUDivider(.ink)
    }

    /// The block's name and status, then, once it has ended, its weeks,
    /// dates and workouts as Past blocks lists them, which tell two blocks
    /// with one name apart.
    private func blockRow(_ block: Block) -> some View {
        let status = block.derivedStatus
        let line = status == .completed ? PastBlocksView.line(of: block) : nil
        return VStack(alignment: .leading, spacing: 4) {
            usedInLayout {
                Text(block.programName)
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                    .fixedSize(horizontal: false, vertical: true)
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 12)
                }
                BRUChip(status.word)
            }
            if let line {
                Text(line.line)
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: BRUMetrics.touchTarget, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(status.word.uppercased()) block: \(block.programName)")
        .accessibilityValue(line?.spoken ?? "")
    }

    /// A block's name beside its status, or above it at accessibility
    /// sizes, where both on one line break the name.
    private var usedInLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 0))
    }

    // MARK: - Restore

    private var restoreSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            BRUButton("Restore routine", kind: .signal) { restore() }
            Text("Restoring puts it back on Program and Today.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
    }

    /// Saves the routine back into the routine lists and goes back to the
    /// archived list. A failed save keeps the screen, and the routine
    /// archived, for a retry.
    private func restore() {
        do {
            try restoreRoutine(split, context: ctx)
            dismiss()
        } catch {
            showSaveError = true
        }
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(BRUFont.bodyDefault)
            .foregroundStyle(Color.bruMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
}
