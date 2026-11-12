//
//  PastBlocksView.swift
//  fitbod
//
//  The finished blocks, pushed from Program's PAST BLOCKS · n › row
//  (RM-011, docs/design-map/redesign/program-layouts.md). Each row opens
//  the block's overview, where its review reopens.
//
//  Composition (top to bottom):
//    BRUHeaderBar (left: .back, center: "Past blocks")
//    ScrollView { LazyVStack: one PastBlockRow per completed block, the
//      newest ended first, or "No past blocks." once the last is deleted }
//
//  Navigation: pushed via PastBlocksRoute on Program's NavigationStack; a
//  row pushes BlockOverviewRoute on the same stack. No child NavigationStack.
//

import SwiftUI
import SwiftData

// MARK: - PastBlocksRoute

/// Typed route for pushing PastBlocksView onto Program's NavigationPath.
public enum PastBlocksRoute: Hashable, Sendable {
    case list
}

// MARK: - PastBlocksView

public struct PastBlocksView: View {

    // A block is completed once it has an end date (`Block.derivedStatus`),
    // a stored field, so predicate-safe.
    @Query(
        filter: #Predicate<Block> { $0.endDate != nil },
        sort: [SortDescriptor(\Block.endDate, order: .reverse)]
    )
    private var pastBlocks: [Block]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            BRUHeaderBar.slots(left: .back, center: "Past blocks")

            ScrollView {
                LazyVStack(spacing: 0) {
                    if pastBlocks.isEmpty {
                        Text("No past blocks.")
                            .font(BRUFont.bodyDefault)
                            .foregroundStyle(Color.bruMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }

                    ForEach(pastBlocks) { block in
                        PastBlockRow(block: block)
                        BRUDivider(.hair)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    /// "6 weeks · Mar 3 - Apr 14 · 18 workouts": the plan's length, the
    /// dates it ran and its counted workouts. The dates tell two blocks with
    /// one name apart (D-127). The end carries its year when the block
    /// ended in an earlier year than `now`, and the start carries its own
    /// whenever the block began in another year than it ended.
    static func line(of block: Block, now: Date = .now, calendar: Calendar = .current) -> (line: String, spoken: String) {
        let end = block.endDate ?? now
        let endYear = calendar.component(.year, from: end)
        var day = Date.FormatStyle.dateTime.month(.abbreviated).day()
        day.calendar = calendar
        day.timeZone = calendar.timeZone
        let start = block.startDate.formatted(calendar.component(.year, from: block.startDate) != endYear ? day.year() : day)
        let ended = end.formatted(endYear < calendar.component(.year, from: now) ? day.year() : day)

        let weeks = MesocycleWeekPage.totalWeeks(of: block)
        let workouts = BRUCountLabel.text(SessionSetActions.countedWorkouts(block.sessions ?? []).count, "workout")
        let lead = weeks > 0 ? [BRUCountLabel.text(weeks, "week")] : []
        return (
            (lead + ["\(start) - \(ended)", workouts]).joined(separator: " · "),
            (lead + ["\(start) to \(ended)", workouts]).joined(separator: ", ")
        )
    }
}

// MARK: - PastBlockRow

/// One finished block: its name over `PastBlocksView.line(of:)`. VoiceOver
/// reads "DONE block: Winter Block", as Program's DONE cards did, then the line.
fileprivate struct PastBlockRow: View {

    let block: Block

    var body: some View {
        let line = PastBlocksView.line(of: block)
        NavigationLink(value: BlockOverviewRoute.summary(blockID: block.id)) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(block.programName)
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(line.line)
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ProgramRowChevron()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: BRUMetrics.touchTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bruRow)
        .accessibilityLabel("DONE block: \(block.programName)")
        .accessibilityValue(line.spoken)
    }
}
