//
//  ProgramView.swift
//  fitbod
//
//  Quick task 260525-gen — BRU Program empty-state surface that replaces
//  the Routines tab body in the bottom nav.
//
//  Source of truth: bru-screens/Program/empty-state.png (PNG primary),
//  bru-screens/Program/empty-state.html (typography + measurement
//  reference). The PNG governs spacing, vertical rhythm, and proportions;
//  the HTML governs exact copy, font weights, and inline emphasis.
//
//  ## Composition
//
//  - ProgramChromeHeader (not BRUHeaderBar) starts below the native
//    status bar:
//      - 2pt top rule
//      - PROGRAM (left) / + NEW (right) row
//      - 2pt bottom rule
//    BRUHeaderBar is bypassed here because BRUHeaderBar centers the
//    title and only paints a bottom rule — the mockup needs left-aligned
//    PROGRAM, right-aligned + NEW, and a top rule above the row.
//  - ResumeWorkoutBanner (reactive via its own @Query) when an active
//    Session exists.
//  - NoProgramHero: "ACTIVE BLOCK · NONE" caption, Bebas Neue
//    "NO PROGRAM" headline, Geist paragraph with inline bold on the
//    accumulation/intensification/peak/deload keywords.
//  - Coral "+ DEFINE BLOCK ▶" CTA with the measured 71pt height.
//  - Feature chips rendered by a wrapping layout using measured chip tokens.
//  - ProgramTemplateSection: compact ProgramTemplateHeader + one
//    ProgramTemplateRow per BlockTemplates.catalog template, showing only
//    its weeks, name and phases.
//
//  ## Accessibility sizes
//
//  The measured heights are minimums, so larger text grows the hero, CTA,
//  chips and rows instead of drawing over them. At accessibility sizes
//  NO PROGRAM wraps, and the template header and rows stack their parts.
//  The chrome header grows with its text, and + NEW's popover opens under
//  its measured height. CREATE BLOCK and CHOOSE PRESET open at full height
//  and scroll, and every row's chevron scales with the text.
//
//  ## Scope decisions (260525-gen)
//
//  - Always renders the empty-state design regardless of existing Block
//    count. The "active block" populated state is a separate task.
//  - Drops the search bar, folder/routine list, New Folder / History menu,
//    and the active-session conflict alert that lived in RoutinesListView.
//  - "+ NEW" opens the custom BRU action popover from bru-screens/New-modal:
//    "+ New block" routes to a blank block builder, "+ New routine" creates
//    a routine (code `Split`) and pushes its SplitDetailView.
//  - The hero CTA still routes directly to the blank-block flow.
//
//  ## Font departures from the design system
//
//  Two BRU departures are intentional on this screen:
//  - BebasNeue-Regular.ttf and Geist-Regular.ttf are registered in
//    Info.plist for this measured mockup pass. Space Grotesk remains the
//    BRU default elsewhere.
//
//  ## File location & Xcode wiring
//
//  fitbod/Periodization/ — co-located with Block*, MesocycleWeek*, and
//  PeriodizationEngine. The project uses synchronized file system groups
//  (PBXFileSystemSynchronizedRootGroup, objectVersion 77), so this file
//  is picked up automatically with no pbxproj edit required.
//

import SwiftUI
import SwiftData

// MARK: - ProgramView

/// Program tab body — BRU brutalist surface for periodization.
/// Empty-state (NoProgramHero + ProgramTemplateSection) is shown ONLY when
/// there are zero blocks AND zero non-archived splits. When either exists the
/// BLOCKS and ROUTINES sections are rendered instead.
///
/// THREADING NOTE: `derivedStatus` is a computed property on Block and is NOT
/// addressable in #Predicate. All status-based ordering and usage-tag filtering
/// is performed as Swift post-filter after the @Query result is received.
public struct ProgramView: View {

    // MARK: State

    @Environment(\.modelContext) private var ctx

    @Query(filter: #Predicate<Session> { $0.completedAt == nil })
    private var activeSessions: [Session]

    // All blocks, sorted by startDate descending. Status ordering applied as
    // Swift post-filter in `orderedBlocks` (derivedStatus is computed, not stored).
    @Query(sort: [SortDescriptor(\Block.startDate, order: .reverse)])
    private var allBlocks: [Block]

    // Non-archived splits only — isArchived is a stored Bool so predicate-safe.
    @Query(
        filter: #Predicate<Split> { !$0.isArchived },
        sort: [SortDescriptor(\Split.name)]
    )
    private var allSplits: [Split]

    @State private var navigationPath = NavigationPath()
    @State private var pendingBlockBuilder: PendingBlockBuilder? = nil
    @State private var showingNewPopover = false
    @State private var presentingStartChoice = false
    @State private var presentingPresetPicker = false
    @State private var stagedBuilder: PendingBlockBuilder? = nil
    @State private var showAllDone = false
    @State private var headerHeight = ProgramChromeHeader.totalHeight

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: Init

    public init() {}

    // MARK: Body

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    ProgramChromeHeader(onNew: { showingNewPopover = true })
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                        // + NEW's 44pt target overhangs the header; in front
                        // of the scroll view, the overhang takes taps.
                        .zIndex(1)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ResumeWorkoutBanner(
                                onResume: { session in
                                    navigationPath.append(SessionRoute.logger(session))
                                },
                                onDiscard: { session in
                                    ctx.delete(session)
                                    try? ctx.save()
                                }
                            )

                            // Empty-state gate: show hero ONLY when zero blocks AND zero splits.
                            // When either exists, show the live BLOCKS + ROUTINES sections.
                            if allBlocks.isEmpty && allSplits.isEmpty {
                                NoProgramHero(
                                    defineAction: { presentingStartChoice = true }
                                )
                                ProgramTemplateSection(
                                    rows: ProgramView.templateRows,
                                    onSelect: { row in
                                        pendingBlockBuilder = .template(row.template)
                                    }
                                )
                            } else {
                                blocksSection
                                routinesSection
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }

                if showingNewPopover {
                    newPopoverLayer
                }
            }
            .background(ProgramScreenTokens.screenBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationDestination(for: SessionRoute.self) { route in
                switch route {
                case .logger(let session):
                    SessionLoggerView(session: session)
                }
            }
            // T-09-04 mitigation: register BlockOverviewRoute BEFORE any BLOCKS taps.
            // Resolves Block by UUID via FetchDescriptor — mirrors TodayView pattern.
            .navigationDestination(for: BlockOverviewRoute.self) { route in
                switch route {
                case .summary(let blockID):
                    let blockIDCapture = blockID
                    let fetchedBlock = (try? ctx.fetch(
                        FetchDescriptor<Block>(
                            predicate: #Predicate<Block> { $0.id == blockIDCapture }
                        )
                    ))?.first
                    if let resolvedBlock = fetchedBlock {
                        BlockOverviewScreen(block: resolvedBlock, onEdit: {
                            pendingBlockBuilder = .edit(resolvedBlock)
                        })
                    } else {
                        Text("Block not found")
                            .font(BRUFont.bodyDefault)
                            .foregroundStyle(Color.bruMuted)
                    }
                }
            }
            // SplitDetailRoute destination — resolves Split by UUID.
            .navigationDestination(for: SplitDetailRoute.self) { route in
                switch route {
                case .detail(let splitID):
                    let splitIDCapture = splitID
                    let fetchedSplit = (try? ctx.fetch(
                        FetchDescriptor<Split>(
                            predicate: #Predicate<Split> { $0.id == splitIDCapture }
                        )
                    ))?.first
                    if let resolvedSplit = fetchedSplit {
                        SplitDetailView(split: resolvedSplit)
                    } else {
                        Text("Routine not found")
                            .font(BRUFont.bodyDefault)
                            .foregroundStyle(Color.bruMuted)
                    }
                }
            }
            .fullScreenCover(item: $pendingBlockBuilder) { pending in
                switch pending {
                case .newBlock(let chosenPreset):
                    BlockBuilderView(draft: BlockDraft.newBlock(), initialPreset: chosenPreset)
                case .template(let template):
                    BlockBuilderView(draft: BlockDraft(template: template))
                case .edit(let block):
                    BlockBuilderView(draft: BlockDraft(block: block), editing: block)
                }
            }
            .sheet(isPresented: $presentingStartChoice, onDismiss: {
                if let staged = stagedBuilder {
                    pendingBlockBuilder = staged
                    stagedBuilder = nil
                }
            }) {
                NewBlockStartChoiceSheet(
                    onScratch: {
                        stagedBuilder = .newBlock(nil)
                        presentingStartChoice = false
                    },
                    onPreset: {
                        presentingPresetPicker = true
                    }
                )
                .sheet(isPresented: $presentingPresetPicker, onDismiss: {
                    if stagedBuilder != nil {
                        presentingStartChoice = false
                    }
                }) {
                    NewBlockPresetPickerSheet { chosenPreset in
                        stagedBuilder = .newBlock(chosenPreset)
                        presentingPresetPicker = false
                    }
                    .presentationDetents(blockSheetDetents)
                    .presentationDragIndicator(.visible)
                }
                .presentationDetents(blockSheetDetents)
                .presentationDragIndicator(.visible)
            }
        }
    }

    /// CREATE BLOCK and CHOOSE PRESET open at half height, or at full height
    /// at accessibility sizes, where their rows outgrow half the screen.
    private var blockSheetDetents: Set<PresentationDetent> {
        dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium]
    }

    // MARK: Popover

    private var newPopoverLayer: some View {
        ZStack(alignment: .topTrailing) {
            Color.bruInk
                .opacity(0.34)
                .ignoresSafeArea()
                .onTapGesture {
                    showingNewPopover = false
                }

            BRUActionPopover(
                items: [
                    BRUActionPopoverItem(title: "+ New block") {
                        showingNewPopover = false
                        startBlank()
                    },
                    BRUActionPopoverItem(title: "+ New routine") {
                        showingNewPopover = false
                        startNewRoutine()
                    },
                ]
            )
            .padding(.top, headerHeight + ProgramScreenTokens.newPopoverTopGap)
            .padding(.trailing, ProgramScreenTokens.newPopoverTrailingPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
        .zIndex(1)
    }

    // MARK: Actions

    private func startBlank() {
        presentingStartChoice = true
    }

    /// "+ New routine" creates the routine (UI term; code `Split`) right
    /// away and opens it, where the user names it and adds sessions. An
    /// untitled routine still shows in ROUTINES so it is never orphaned.
    private func startNewRoutine() {
        if let split = RoutineCreator.create(context: ctx) {
            navigationPath.append(SplitDetailRoute.detail(splitID: split.id))
        }
    }

    // MARK: Static data

    /// One row per catalog template, in catalog order.
    static let templateRows: [ProgramTemplateRowContent] =
        BlockTemplates.catalog.map(ProgramTemplateRowContent.init)

    private enum PendingBlockBuilder: Identifiable {
        case newBlock(NewBlockPreset?)
        case template(BlockTemplate)
        case edit(Block)

        var id: String {
            switch self {
            case .newBlock(let preset):
                if let preset = preset {
                    return "new-block-preset-\(preset.id)"
                } else {
                    return "new-block-scratch"
                }
            case .template(let template):
                return "template-\(template.name)"
            case .edit(let block):
                return "edit-\(block.id)"
            }
        }
    }

    // MARK: - Ordered blocks (Swift post-filter — derivedStatus is computed, not stored)

    /// Blocks sorted by status precedence ACTIVE → READY → DRAFT → DONE,
    /// then by startDate descending within each status group.
    /// NOTE: derivedStatus is a computed property on Block and is NOT
    /// addressable in #Predicate — ordering performed in Swift post-filter.
    private var orderedBlocks: [Block] {
        let statusOrder: [BlockStatus: Int] = [
            .active: 0, .ready: 1, .draft: 2, .completed: 3
        ]
        return allBlocks.sorted { a, b in
            let aPriority = statusOrder[a.derivedStatus] ?? 4
            let bPriority = statusOrder[b.derivedStatus] ?? 4
            if aPriority != bPriority { return aPriority < bPriority }
            return a.startDate > b.startDate
        }
    }

    // MARK: - BLOCKS section

    @ViewBuilder
    private var blocksSection: some View {
        BRUSectionHead("Blocks")

        let liveBlocks = orderedBlocks.filter { $0.derivedStatus != .completed }
        let doneBlocks = orderedBlocks.filter { $0.derivedStatus == .completed }
        let visibleDone = showAllDone ? doneBlocks : Array(doneBlocks.prefix(3))

        ForEach(liveBlocks) { block in
            BlockStatusCard(
                block: block,
                onTap: {
                    navigationPath.append(BlockOverviewRoute.summary(blockID: block.id))
                }
            )
            BRUDivider(.hair)
        }

        ForEach(visibleDone) { block in
            BlockStatusCard(
                block: block,
                onTap: {
                    navigationPath.append(BlockOverviewRoute.summary(blockID: block.id))
                }
            )
            BRUDivider(.hair)
        }

        if !showAllDone && doneBlocks.count > 3 {
            let doneCount = doneBlocks.count
            Button {
                if reduceMotion {
                    showAllDone = true
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showAllDone = true
                    }
                }
            } label: {
                Text("ALL HISTORY ▸")
                    .font(BRUFont.labelSmall)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.bruSignal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show all \(doneCount) completed blocks")
        }

        BRUDivider(.ink)
    }

    // MARK: - ROUTINES section

    @ViewBuilder
    private var routinesSection: some View {
        BRUSectionHead("Routines")

        ForEach(allSplits) { split in
            RoutineSplitRow(
                split: split,
                onTap: {
                    navigationPath.append(SplitDetailRoute.detail(splitID: split.id))
                }
            )
            BRUDivider(.hair)
        }

        // "+ NEW ROUTINE" action row (dedicated row per UI-SPEC §2)
        Button {
            startNewRoutine()
        } label: {
            Text("+ NEW ROUTINE")
                .font(BRUFont.labelSmall)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Color.bruSignal)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        BRUDivider(.ink)
    }
}

// MARK: - BlockStatusCard

/// Card displaying a single Block in the BLOCKS section.
/// Fileprivate so ProgramChipFlow and ProgramScreenTokens remain accessible.
fileprivate struct BlockStatusCard: View {

    let block: Block
    let onTap: () -> Void

    // Capture today at construction — mirrors BlockOverviewScreen init pattern.
    private let today = Date.now

    private var derivedStatus: BlockStatus { block.derivedStatus }

    private var weekIndex: Int {
        PeriodizationEngine.weekIndex(for: block, on: today) ?? 0
    }

    private var totalWeeks: Int {
        MesocycleWeekPage.totalWeeks(of: block)
    }

    private var phaseLabel: String {
        let ctx = PeriodizationEngine.weekContext(for: block, weekIndex: weekIndex, on: today)
        return (ctx?.phaseKind.rawValue ?? "Accumulation").capitalized
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                // Status chip row
                HStack(spacing: 8) {
                    statusChip
                    Spacer()
                    if derivedStatus == .active {
                        Text("W\(weekIndex + 1) · \(phaseLabel.uppercased())")
                            .font(BRUFont.labelSmall)
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(Color.bruMuted)
                    }
                }

                // Block name
                Text(block.name.isEmpty ? "Untitled Block" : block.name)
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                    .fixedSize(horizontal: false, vertical: true)

                // Active progress line
                if derivedStatus == .active {
                    Text("Week \(weekIndex + 1) of \(totalWeeks) · \(phaseLabel)")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
    }

    private var statusChip: some View {
        switch derivedStatus {
        case .active:
            return BRUChip("ACTIVE", color: .bruSignal, fill: true)
        case .ready:
            return BRUChip("READY", color: .bruSignal)
        case .draft:
            return BRUChip("DRAFT")
        case .completed:
            return BRUChip("DONE")
        }
    }

    private var accessibilityLabelText: String {
        let name = block.name.isEmpty ? "Untitled Block" : block.name
        switch derivedStatus {
        case .active:
            return "ACTIVE block: \(name). Week \(weekIndex + 1) of \(totalWeeks), \(phaseLabel)."
        case .ready:
            return "READY block: \(name)"
        case .draft:
            return "DRAFT block: \(name)"
        case .completed:
            return "DONE block: \(name)"
        }
    }
}

// MARK: - RoutineSplitRow

/// Row for a single Split in the ROUTINES section.
/// Fileprivate so it can access ProgramChipFlow and ProgramScreenTokens.
fileprivate struct RoutineSplitRow: View {

    let split: Split
    let onTap: () -> Void

    // Session count = number of slots in the split.
    private var sessionCount: Int { split.slots?.count ?? 0 }

    // Usage tags: live (non-completed) block names attached to this split.
    // Post-filter in Swift — multi-level chain (split.blocks + derivedStatus)
    // is not expressible in #Predicate (T-09-06 mitigation).
    private var liveBlockNames: [String] {
        (split.blocks ?? [])
            .filter { $0.derivedStatus != .completed }
            .map { $0.name.isEmpty ? "Untitled" : $0.name }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(split.name.isEmpty ? "Untitled Routine" : split.name)
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruInk)

                    Text("\(sessionCount) sessions")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                }

                Spacer()

                if !liveBlockNames.isEmpty {
                    UsageTagFlow(names: liveBlockNames)
                }

                Text("›")
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruMuted)
            }
            .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - UsageTagFlow

/// Wrapping horizontal flow of usage tag chips using ProgramChipFlow layout.
/// Renders nothing when names is empty (no "unused" label).
fileprivate struct UsageTagFlow: View {

    let names: [String]

    var body: some View {
        if names.isEmpty {
            EmptyView()
        } else {
            ProgramChipFlow(
                spacing: ProgramScreenTokens.chipSpacing,
                rowSpacing: ProgramScreenTokens.chipRowSpacing
            ) {
                ForEach(names, id: \.self) { name in
                    BRUChip(name)
                }
            }
        }
    }
}

// MARK: - NewBlockStartChoiceSheet

fileprivate struct NewBlockStartChoiceSheet: View {
    let onScratch: () -> Void
    let onPreset: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            ProgramScreenTokens.screenBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Title (left-aligned, editorial — high contrast on paper)
                VStack(alignment: .leading, spacing: 6) {
                    Text("CREATE BLOCK")
                        .font(.bru(.condensed, size: 30))
                        .tracking(1.5)
                        .foregroundStyle(ProgramScreenTokens.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Choose a starting point for your reusable training block.")
                        .font(.bru(.text, size: 13))
                        .foregroundStyle(ProgramScreenTokens.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
                .padding(.top, 24)
                .padding(.bottom, 20)

                // Section label
                Text("CHOOSE STARTING POINT")
                    .font(.bru(.grotesk, size: 11))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(ProgramScreenTokens.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
                    .padding(.bottom, 10)

                // Divider
                Rectangle()
                    .fill(ProgramScreenTokens.ink)
                    .frame(height: 2)

                // Choice: Blank Block
                Button(action: onScratch) {
                    HStack(alignment: .center, spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Blank Block")
                                .font(.bru(.grotesk, size: 15))
                                .foregroundStyle(ProgramScreenTokens.ink)
                            Text("Build your own phases manually.")
                                .font(.bru(.grotesk, size: 11))
                                .tracking(ProgramScreenTokens.headerLetterSpacing)
                                .foregroundStyle(ProgramScreenTokens.muted)
                        }
                        Spacer()
                        ProgramRowChevron()
                    }
                    .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
                    .padding(.vertical, choiceVerticalPadding)
                    .frame(minHeight: 64)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(ProgramScreenTokens.screenBackground)

                // Divider
                Rectangle()
                    .fill(ProgramScreenTokens.lightRowDividerColor)
                    .frame(height: 1)

                // Choice: Use Preset
                Button(action: onPreset) {
                    HStack(alignment: .center, spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use Preset")
                                .font(.bru(.grotesk, size: 15))
                                .foregroundStyle(ProgramScreenTokens.ink)
                            Text("Start from \(BlockTemplates.catalog.map(\.name).formatted(.list(type: .or))).")
                                .font(.bru(.grotesk, size: 11))
                                .tracking(ProgramScreenTokens.headerLetterSpacing)
                                .foregroundStyle(ProgramScreenTokens.muted)
                        }
                        Spacer()
                        ProgramRowChevron()
                    }
                    .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
                    .padding(.vertical, choiceVerticalPadding)
                    .frame(minHeight: 64)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(ProgramScreenTokens.screenBackground)

                // Divider
                Rectangle()
                    .fill(ProgramScreenTokens.ink)
                    .frame(height: 2)

                Spacer()
            }
            .modifier(ProgramSheetScroll())
        }
    }

    /// Room above and below a choice's wrapped text at accessibility sizes.
    /// At standard sizes the 64pt minimum height holds it.
    private var choiceVerticalPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 12 : 0
    }
}

// MARK: - NewBlockPresetPickerSheet

fileprivate struct NewBlockPresetPickerSheet: View {
    let onSelect: (NewBlockPreset) -> Void

    var body: some View {
        ZStack {
            ProgramScreenTokens.screenBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Title (left-aligned, editorial — high contrast on paper)
                Text("CHOOSE PRESET")
                    .font(.bru(.condensed, size: 30))
                    .tracking(1.5)
                    .foregroundStyle(ProgramScreenTokens.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                // Top rule
                Rectangle()
                    .fill(ProgramScreenTokens.ink)
                    .frame(height: 2)

                ForEach(Array(NewBlockPreset.all.enumerated()), id: \.element) { index, preset in
                    Button {
                        onSelect(preset)
                    } label: {
                        HStack(alignment: .center, spacing: 0) {
                            Text(preset == .blank ? "FROM SCRATCH" : preset.label)
                                .font(.bru(.grotesk, size: 13))
                                .tracking(1.5)
                                .foregroundStyle(ProgramScreenTokens.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Spacer()
                            ProgramRowChevron()
                        }
                        .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
                        .frame(height: 52)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(ProgramScreenTokens.screenBackground)

                    if index < NewBlockPreset.all.count - 1 {
                        Rectangle()
                            .fill(ProgramScreenTokens.lightRowDividerColor)
                            .frame(height: 1)
                    }
                }

                // Bottom rule
                Rectangle()
                    .fill(ProgramScreenTokens.ink)
                    .frame(height: 2)

                Spacer()
            }
            .modifier(ProgramSheetScroll())
        }
    }
}

// MARK: - ProgramSheetScroll

/// A block sheet's content, scrolling at accessibility sizes, where it can
/// outgrow even the full-height sheet. At standard sizes it stays as is.
fileprivate struct ProgramSheetScroll: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView {
                content
            }
        } else {
            content
        }
    }
}

// MARK: - ProgramScreenTokens

fileprivate enum ProgramScreenTokens {
    // Adaptive BRU tokens, so Program turns dark with the other tabs.
    static let screenBackground = Color.bruPaper
    static let ink = Color.bruInk
    static let muted = Color.bruMuted
    static let blackDividerThickness: CGFloat = 2
    static let lightRowDividerColor = Color.bruHair
    static let lightRowDividerThickness: CGFloat = 1
    static let horizontalPagePadding: CGFloat = 16

    static let topHeaderHeight: CGFloat = 34
    static let topHeaderRowHeight: CGFloat = 30
    static let headerLabelFontSize: CGFloat = 11
    static let headerLetterSpacing: CGFloat = 1.2
    static let newPopoverTopGap: CGFloat = 4
    static let newPopoverTrailingPadding: CGFloat = 14

    static let heroCopyHeight: CGFloat = 208
    static let heroTopPadding: CGFloat = 20
    static let heroCaptionFontSize: CGFloat = 10
    static let heroCaptionLineHeight: CGFloat = 14
    static let heroCaptionLetterSpacing: CGFloat = 1.5
    static let captionToHeadlineSpacing: CGFloat = 0
    static let noProgramFontSize: CGFloat = 68
    static let noProgramLineHeight: CGFloat = 70
    static let noProgramLetterSpacing: CGFloat = 0.5
    static let headlineToBodySpacing: CGFloat = 8
    static let bodyFontSize: CGFloat = 13.4
    static let bodyLineHeight: CGFloat = 20
    static let bodyLineSpacing: CGFloat = 2

    static let ctaTopSpacing: CGFloat = 16
    static let ctaHeight: CGFloat = 71
    static let ctaColor = Color.bruSignal
    static let ctaBottomSpacing: CGFloat = 10
    static let ctaFontSize: CGFloat = 28

    static let chipHeight: CGFloat = 20
    static let chipHorizontalPadding: CGFloat = 4
    static let chipBorderWidth: CGFloat = 1
    static let chipSpacing: CGFloat = 6
    static let chipRowSpacing: CGFloat = 5
    static let chipFontSize: CGFloat = 10
    static let chipLetterSpacing: CGFloat = 1.5
    static let chipBottomSpacing: CGFloat = 16

    static let templateHeaderHeight: CGFloat = 26
    static let templateHeaderDividerThickness: CGFloat = 1
    static let templateRowHeight: CGFloat = 77
    static let templateTitleFontSize: CGFloat = 15
    static let templateMetaFontSize: CGFloat = 10
    static let templateMetaLineHeight: CGFloat = 13
    static let templateTextSpacing: CGFloat = 2
    static let templateWeeksFontSize: CGFloat = 32
    static let templateWeeksWidth: CGFloat = 56

    static let bottomTabBarHeight: CGFloat = 63
    static let selectedTabWidth: CGFloat = 99
    static let selectedTabHeight: CGFloat = 29
    static let bottomSafeAreaSpacing: CGFloat = 34
}

// MARK: - ProgramTypography

fileprivate enum ProgramTypography {
    static let chromeLabel: Font = .bru(.grotesk, size: ProgramScreenTokens.headerLabelFontSize)
    static let templateMeta: Font = .bru(.grotesk, size: ProgramScreenTokens.templateMetaFontSize)
}

// MARK: - ProgramChromeHeader

fileprivate struct ProgramChromeHeader: View {
    /// The height at default text. Larger text grows the row, so ProgramView
    /// opens + NEW's popover under the header's measured height.
    static let totalHeight: CGFloat = ProgramScreenTokens.topHeaderHeight
    /// How far + NEW's 44pt target hangs below the header at default text.
    private static let newTargetOverhang: CGFloat = BRUMetrics.touchTarget - totalHeight

    let onNew: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            rule

            HStack(alignment: .center) {
                Text("PROGRAM")
                    .font(ProgramTypography.chromeLabel)
                    .tracking(ProgramScreenTokens.headerLetterSpacing)
                    .foregroundStyle(ProgramScreenTokens.ink)

                Spacer()

                Button {
                    onNew()
                } label: {
                    Text("+ NEW")
                        .font(ProgramTypography.chromeLabel)
                        .tracking(ProgramScreenTokens.headerLetterSpacing)
                        .foregroundStyle(ProgramScreenTokens.ink)
                        // Lifts the text inside its 44pt target, so the target
                        // starts at the header's top edge and hangs below the
                        // header, never into the status bar, which takes no taps.
                        .padding(.bottom, Self.newTargetOverhang)
                        .frame(minWidth: BRUMetrics.touchTarget, minHeight: BRUMetrics.touchTarget, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // The target takes no height in the row, whose height comes
                // from PROGRAM in the same font, and keeps its text level
                // with PROGRAM.
                .padding(.top, -(BRUMetrics.touchTarget - Self.newTargetOverhang) / 2)
                .padding(.bottom, -(BRUMetrics.touchTarget + Self.newTargetOverhang) / 2)
            }
            .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
            .padding(.vertical, 4)
            .frame(minHeight: ProgramScreenTokens.topHeaderRowHeight)
            .frame(maxWidth: .infinity)
            .background(ProgramScreenTokens.screenBackground)

            rule
        }
        .background(ProgramScreenTokens.screenBackground)
    }

    /// A 2pt rule. It takes no taps, so + NEW's target takes them where it
    /// hangs over the bottom rule.
    private var rule: some View {
        Rectangle()
            .fill(ProgramScreenTokens.ink)
            .frame(height: ProgramScreenTokens.blackDividerThickness)
            .allowsHitTesting(false)
    }
}

// MARK: - Program Dividers

fileprivate struct ProgramInkDivider: View {
    var body: some View {
        Rectangle()
            .fill(ProgramScreenTokens.ink)
            .frame(height: ProgramScreenTokens.blackDividerThickness)
    }
}

fileprivate struct ProgramHairDivider: View {
    var body: some View {
        Rectangle()
            .fill(ProgramScreenTokens.lightRowDividerColor)
            .frame(height: ProgramScreenTokens.lightRowDividerThickness)
    }
}

fileprivate struct ProgramTemplateHeaderDivider: View {
    var body: some View {
        Rectangle()
            .fill(ProgramScreenTokens.ink)
            .frame(height: ProgramScreenTokens.templateHeaderDividerThickness)
    }
}

// MARK: - ProgramTemplateRowContent

/// What one template row shows: only facts its template holds, such as
/// "8W", "Hypertrophy Meso" and "ACCUM 5 · INTNS 2 · DELOAD 1".
struct ProgramTemplateRowContent: Identifiable {
    let template: BlockTemplate

    var id: String { template.id }
    var weeks: String { "\(template.totalWeeks)W" }
    var title: String { template.name }
    var phases: String { template.phaseSummary }
}

// MARK: - NoProgramHero

/// Hero block: ACTIVE BLOCK caption, big condensed NO PROGRAM headline,
/// explanatory body paragraph with inline bold on the phase keywords,
/// coral CTA, and a wrapping feature-chip row (3 + 1).
fileprivate struct NoProgramHero: View {

    let defineAction: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The measured 70pt headline line box, scaled with the headline.
    @ScaledMetric(relativeTo: .largeTitle) private var headlineLineHeight: CGFloat = ProgramScreenTokens.noProgramLineHeight

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Active block · None")
                    .font(.bru(.grotesk, size: ProgramScreenTokens.heroCaptionFontSize))
                    .tracking(ProgramScreenTokens.heroCaptionLetterSpacing)
                    .textCase(.uppercase)
                    .foregroundStyle(ProgramScreenTokens.muted)
                    .frame(minHeight: ProgramScreenTokens.heroCaptionLineHeight, alignment: .center)

                heroHeadline
                    .padding(.top, ProgramScreenTokens.captionToHeadlineSpacing)

                bodyParagraph
                    .padding(.top, ProgramScreenTokens.headlineToBodySpacing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
            .padding(.top, ProgramScreenTokens.heroTopPadding)
            .frame(minHeight: ProgramScreenTokens.heroCopyHeight, alignment: .top)

            ProgramInkDivider()

            defineCTA
                .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
                .padding(.top, ProgramScreenTokens.ctaTopSpacing)
                .padding(.bottom, ProgramScreenTokens.ctaBottomSpacing)

            chipRows
                .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
                .padding(.bottom, ProgramScreenTokens.chipBottomSpacing)

            ProgramInkDivider()
        }
    }

    /// Bebas Neue's own line box is taller than the mockup's, so standard
    /// sizes keep the measured one. At accessibility sizes the headline
    /// drops it and wraps rather than truncate to "NO PROGR…".
    private var heroHeadline: some View {
        Text("NO PROGRAM")
            .font(.bru(.condensed, size: ProgramScreenTokens.noProgramFontSize))
            .foregroundStyle(ProgramScreenTokens.ink)
            .tracking(ProgramScreenTokens.noProgramLetterSpacing)
            .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
            .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : headlineLineHeight, alignment: .center)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Body paragraph with inline bold on "accumulation, intensification,
    /// peak, deload." via SwiftUI Markdown so the span flows inline with
    /// the surrounding regular weight.
    private var bodyParagraph: some View {
        Text(.init("A block schedules routines across weeks and phases — **accumulation, intensification, peak, deload.** You can also lift without a block, but Fitbod really earns its keep when you’re running one."))
            .font(.bru(.text, size: ProgramScreenTokens.bodyFontSize))
            .foregroundStyle(ProgramScreenTokens.ink)
            .lineSpacing(ProgramScreenTokens.bodyLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var defineCTA: some View {
        Button(action: defineAction) {
            Text("+ DEFINE BLOCK ▶︎")
                .font(.bru(.condensed, size: ProgramScreenTokens.ctaFontSize))
                .tracking(ProgramScreenTokens.noProgramLetterSpacing)
                .foregroundStyle(ProgramScreenTokens.ctaColor.bruLabelOnFill)
            .frame(maxWidth: .infinity)
            .frame(minHeight: ProgramScreenTokens.ctaHeight)
            .background(ProgramScreenTokens.ctaColor)
        }
        .buttonStyle(.plain)
    }

    private var chipRows: some View {
        ProgramChipFlow(
            spacing: ProgramScreenTokens.chipSpacing,
            rowSpacing: ProgramScreenTokens.chipRowSpacing
        ) {
            ProgramFeatureChip(label: "WEEKS · 4-12")
            ProgramFeatureChip(label: "PHASES · 1-4")
            ProgramFeatureChip(label: "DELOAD OPTIONAL")
            ProgramFeatureChip(label: "CUSTOM")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - ProgramFeatureChip

/// Outline chip used in the hero feature row. Slightly larger padding
/// and a stronger border weight than BRUChip's defaults to match the
/// mockup's chip presence.
fileprivate struct ProgramFeatureChip: View {
    let label: String

    /// The measured 20pt chip height, scaled with the chip's label.
    @ScaledMetric(relativeTo: .caption2) private var minHeight: CGFloat = ProgramScreenTokens.chipHeight

    var body: some View {
        Text(label)
            .font(.bru(.grotesk, size: ProgramScreenTokens.chipFontSize))
            .tracking(ProgramScreenTokens.chipLetterSpacing)
            .foregroundStyle(ProgramScreenTokens.ink)
            .padding(.horizontal, ProgramScreenTokens.chipHorizontalPadding)
            .frame(minHeight: minHeight)
            .overlay(
                Rectangle()
                    .stroke(ProgramScreenTokens.ink, lineWidth: ProgramScreenTokens.chipBorderWidth)
            )
    }
}

// MARK: - ProgramChipFlow

fileprivate struct ProgramChipFlow: Layout {
    let spacing: CGFloat
    let rowSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let rows = arrangedRows(proposal: proposal, subviews: subviews)
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let rows = arrangedRows(
            proposal: ProposedViewSize(width: bounds.width, height: proposal.height),
            subviews: subviews
        )

        for row in rows {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    private func arrangedRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var rows: [Row] = []
        var currentItems: [Item] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var currentHeight: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let itemX = currentItems.isEmpty ? 0 : currentX + spacing
            let wraps = !currentItems.isEmpty && itemX + size.width > maxWidth

            if wraps {
                rows.append(Row(y: currentY, height: currentHeight, width: currentX, items: currentItems))
                currentY += currentHeight + rowSpacing
                currentItems = []
                currentX = 0
                currentHeight = 0
            }

            let x = currentItems.isEmpty ? 0 : currentX + spacing
            currentItems.append(Item(index: index, x: x, size: size))
            currentX = x + size.width
            currentHeight = max(currentHeight, size.height)
        }

        if !currentItems.isEmpty {
            rows.append(Row(y: currentY, height: currentHeight, width: currentX, items: currentItems))
        }

        return rows
    }

    private struct Row {
        let y: CGFloat
        let height: CGFloat
        let width: CGFloat
        let items: [Item]
    }

    private struct Item {
        let index: Int
        let x: CGFloat
        let size: CGSize
    }
}

// MARK: - ProgramTemplateSection

fileprivate struct ProgramTemplateSection: View {

    let rows: [ProgramTemplateRowContent]
    let onSelect: (ProgramTemplateRowContent) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ProgramTemplateHeader(
                title: "Or start from a template",
                right: BRUCountLabel.text(rows.count, "preset")
            )

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                ProgramTemplateRow(content: row) {
                    onSelect(row)
                }
                if index < rows.count - 1 {
                    ProgramHairDivider()
                }
            }

            ProgramInkDivider()
        }
    }
}

// MARK: - ProgramTemplateHeader

fileprivate struct ProgramTemplateHeader: View {
    let title: String
    let right: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            headerLayout {
                Text(title)
                    .foregroundStyle(ProgramScreenTokens.ink)

                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer()
                }

                Text(right)
                    .foregroundStyle(ProgramScreenTokens.muted)
            }
            .font(ProgramTypography.chromeLabel)
            .tracking(ProgramScreenTokens.headerLetterSpacing)
            .textCase(.uppercase)
            .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
            .padding(.vertical, 4)
            .frame(minHeight: ProgramScreenTokens.templateHeaderHeight - ProgramScreenTokens.templateHeaderDividerThickness)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ProgramScreenTokens.screenBackground)

            ProgramTemplateHeaderDivider()
        }
    }

    /// Title and count on one line, or the count under the title at
    /// accessibility sizes.
    private var headerLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .center))
    }
}

// MARK: - ProgramTemplateRow

/// One template row: large condensed weeks label on the left, the
/// template's name over its phases in the middle, chevron on the right.
/// At accessibility sizes the weeks, name and phases stack and wrap.
fileprivate struct ProgramTemplateRow: View {

    let content: ProgramTemplateRowContent
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The measured 56pt weeks column, scaled with the weeks label.
    @ScaledMetric(relativeTo: .largeTitle) private var weeksWidth: CGFloat = ProgramScreenTokens.templateWeeksWidth

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 16) {
                partsLayout {
                    Text(content.weeks)
                        .font(.bru(.condensed, size: ProgramScreenTokens.templateWeeksFontSize))
                        .foregroundStyle(ProgramScreenTokens.ink)
                        .frame(width: weeksWidth, alignment: .leading)

                    VStack(alignment: .leading, spacing: ProgramScreenTokens.templateTextSpacing) {
                        Text(content.title)
                            .font(.bru(.text, size: ProgramScreenTokens.templateTitleFontSize))
                            .fontWeight(.semibold)
                            .foregroundStyle(ProgramScreenTokens.ink)
                            .modifier(ProgramRowTextFit(minimumScaleFactor: 0.9))

                        Text(content.phases)
                            .font(ProgramTypography.templateMeta)
                            .tracking(ProgramScreenTokens.headerLetterSpacing)
                            .textCase(.uppercase)
                            .foregroundStyle(ProgramScreenTokens.muted)
                            .frame(minHeight: ProgramScreenTokens.templateMetaLineHeight, alignment: .leading)
                            .modifier(ProgramRowTextFit(minimumScaleFactor: 0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                ProgramRowChevron()
            }
            .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
            .padding(.vertical, 12)
            .frame(minHeight: ProgramScreenTokens.templateRowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(ProgramScreenTokens.screenBackground)
    }

    /// Weeks beside the name and phases, or above them at accessibility sizes.
    private var partsLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
    }
}

// MARK: - ProgramRowChevron

/// The muted "›" closing a template row or a block sheet's row: 16pt at
/// default text, scaled like body text so it grows with the row's words.
fileprivate struct ProgramRowChevron: View {
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 16

    var body: some View {
        Text("›")
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(ProgramScreenTokens.muted)
    }
}

// MARK: - ProgramRowTextFit

/// A template row's name or phases: one line at standard sizes, shrinking
/// a little to fit. At accessibility sizes it wraps to every line it needs
/// and keeps that height, since a stack splitting the row's height between
/// two wrapping texts would cut one short with "…".
fileprivate struct ProgramRowTextFit: ViewModifier {
    let minimumScaleFactor: CGFloat

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            content.fixedSize(horizontal: false, vertical: true)
        } else {
            content
                .lineLimit(1)
                .minimumScaleFactor(minimumScaleFactor)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Program — empty state") {
    ProgramView()
        .modelContainer(PreviewModelContainer.make(seedFixture: false))
}

#Preview("Program — seeded fixtures") {
    ProgramView()
        .modelContainer(PreviewModelContainer.make())
}
#endif
