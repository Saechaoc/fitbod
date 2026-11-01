//
//  BlockCard.swift
//  fitbod
//
//  Today-tab card for the active periodization block.
//  Phase 04.1 (BRU re-skin + KEEP TabView pager per revision iter 1 + D-14 reduced-motion + D-15 accessibilityLabel) — see 04.1-PATTERNS.md File #3 (line 355 'remove pager' instruction rescinded)
//

import SwiftData
import SwiftUI

public struct BlockCard: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public let block: Block
    /// When non-nil, called on card-body tap instead of opening the edit sheet directly.
    /// Wire this from TodayView to push BlockOverviewRoute.summary(blockID:) (CONTEXT D-11).
    public var onTapBlock: ((Block) -> Void)? = nil

    @State private var selectedWeekIndex = 0
    @State private var pendingBuilderForEdit: Block? = nil
    @State private var pendingEndConfirm: Block? = nil

    public init(block: Block, onTapBlock: ((Block) -> Void)? = nil) {
        self.block = block
        self.onTapBlock = onTapBlock
    }

    public var body: some View {
        cardBody(active: block)
            .sheet(item: $pendingBuilderForEdit) { block in
                NavigationStack {
                    BlockBuilderView(draft: BlockDraft(block: block), editing: block)
                }
            }
            .alert(
                "End block?",
                isPresented: Binding(
                    get: { pendingEndConfirm != nil },
                    set: { if !$0 { pendingEndConfirm = nil } }
                )
            ) {
                Button("End Block", role: .destructive) {
                    if let target = pendingEndConfirm {
                        do {
                            try ctx.transaction {
                                target.isActive = false
                                try ctx.save()
                            }
                        } catch {
                            // Offline single-user write; keep the card visible if the save fails.
                        }
                    }
                    pendingEndConfirm = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingEndConfirm = nil
                }
            } message: {
                Text("End this block now? You can review it from the Program tab.")
            }
    }

    public static func initialSelectedWeekIndex(for block: Block, on date: Date = .now) -> Int {
        PeriodizationEngine.weekIndex(for: block, on: date) ?? 0
    }

    @ViewBuilder
    private func cardBody(active: Block) -> some View {
        let totalWeeks = MesocycleWeekPage.totalWeeks(of: active)
        if totalWeeks > 0 {
            VStack(spacing: 0) {
                // Chip row: BRUChip("Block") + block name + phase chip + overflow menu
                HStack(spacing: 8) {
                    BRUChip("Block")
                    Text(active.name)
                        .font(BRUFont.labelSmall)
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(Color.bruInk)
                    Spacer()
                    BRUChip(
                        BlockPhaseColors.phaseLabel(selectedPhaseKind(for: active)).uppercased(),
                        color: .bruSignal,
                        fill: true
                    )
                    overflowMenu(for: active)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // 28pt week ticker strip — per 04-UI-SPEC line 333 + today.jsx line 39
                weekTickerStrip(active: active, totalWeeks: totalWeeks)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                // TabView(.page) week pager — PRESERVED per revision iter 1 B4 user decision.
                // Redundancy with BlockOverviewScreen's static week-carousel (Plan 07) is intentional:
                // BlockCard pager = compact day-by-day glanceable on Today;
                // BlockOverviewScreen carousel = full read-only summary on the pushed screen.
                TabView(selection: $selectedWeekIndex) {
                    ForEach(0..<totalWeeks, id: \.self) { weekIndex in
                        MesocycleWeekPage(block: active, weekIndex: weekIndex)
                            .tag(weekIndex)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(minHeight: 200)
                .animation(reduceMotion ? nil : .default, value: selectedWeekIndex)
            }
            .background(Color.bruPaper)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.bruInk)
                    .frame(height: 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                onTapBlock?(active)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Active block: \(active.name), \(BlockPhaseColors.phaseLabel(selectedPhaseKind(for: active))) phase, week \(displayWeekIndex(for: active) + 1) of \(totalWeeks).")
            .accessibilityHint("Swipe horizontally to navigate between weeks of the mesocycle.")
            .onAppear {
                selectedWeekIndex = Self.initialSelectedWeekIndex(for: active)
            }
        }
    }

    // MARK: - Week ticker strip

    @ViewBuilder
    private func weekTickerStrip(active: Block, totalWeeks: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<min(totalWeeks, 7), id: \.self) { weekIndex in
                weekTickerCell(weekIndex: weekIndex, active: active, totalWeeks: totalWeeks)
            }
        }
    }

    @ViewBuilder
    private func weekTickerCell(weekIndex: Int, active: Block, totalWeeks: Int) -> some View {
        let currentWeek = Self.initialSelectedWeekIndex(for: active)
        let isActive = weekIndex == currentWeek
        let isPast = weekIndex < currentWeek
        let weekContext = PeriodizationEngine.weekContext(for: active, weekIndex: weekIndex, on: .now)
        let isDeload = weekContext?.phaseKind == .deload

        ZStack {
            // Background fill: active = bruInk, past = bruFaint, future = transparent
            Rectangle()
                .fill(isActive ? Color.bruInk : isPast ? Color.bruFaint : Color.clear)
                .overlay(
                    Rectangle()
                        .stroke(Color.bruInk, lineWidth: 1.5)
                )

            Text("W\(weekIndex + 1)")
                .font(BRUFont.displayMedium)
                .foregroundStyle(isActive ? Color.bruPaper : Color.bruInk)
        }
        .frame(height: 28)
        .overlay(alignment: .topTrailing) {
            if isDeload {
                BRUCornerBadge("DL", fill: .bruSignal)
                    .offset(x: 3, y: -7)
            }
        }
    }

    // MARK: - Helpers

    private func selectedPhaseKind(for block: Block) -> BlockPhaseKind {
        PeriodizationEngine
            .weekContext(for: block, weekIndex: selectedWeekIndex, on: .now)?
            .phaseKind ?? .accumulation
    }

    /// Clamps selectedWeekIndex to a valid range for use in accessibility labels.
    private func displayWeekIndex(for block: Block) -> Int {
        let totalWeeks = MesocycleWeekPage.totalWeeks(of: block)
        return min(max(selectedWeekIndex, 0), max(totalWeeks - 1, 0))
    }

    private func overflowMenu(for block: Block) -> some View {
        Menu {
            Button("Edit Block") {
                pendingBuilderForEdit = block
            }
            Button("End Block", role: .destructive) {
                pendingEndConfirm = block
            }
        } label: {
            Text("•••")
                .font(BRUFont.labelSmall)
                .foregroundStyle(Color.bruMuted)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Block actions")
    }
}
