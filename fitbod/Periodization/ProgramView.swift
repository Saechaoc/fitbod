//
//  ProgramView.swift
//  fitbod
//
//  The Program tab: what the lifter is running now, what comes after it,
//  and the routines it runs (RM-011, docs/design-map/redesign/program-layouts.md).
//
//  ## Composition, top to bottom
//
//  - BRUHeaderBar "Fitbod / Program" with "+ New" in ink, the one creation
//    entry: its popover offers + New block and + New routine. The popover
//    opens under the header's measured height.
//  - ResumeWorkoutBanner while a workout is open. Its RESUME ▸ opens the
//    logger on Today's stack through ResumeWorkoutRequest (FT-02).
//  - The lead block (`ProgramBlocks.lead`): the active block as an ink slab
//    that opens Block overview (no week cells, O-13); with none active, the
//    oldest created ready block with START BLOCK ▸ (O-6); with drafts only,
//    the newest created draft with CONTINUE BLOCK ▸.
//  - PLANNED: the other ready blocks, oldest created first, then the other
//    drafts, newest created first.
//  - ROUTINES, and Archived routines while one is archived.
//
//  ## Accessibility sizes
//
//  Rows grow with their text from a 44pt minimum and nothing truncates.
//  The active slab stacks ACTIVE BLOCK over OPEN ›, and Planned cards keep
//  their chevron on the first line. CREATE BLOCK and CHOOSE PRESET open at
//  full height and scroll.
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
///
/// THREADING NOTE: `derivedStatus` is a computed property on Block and is NOT
/// addressable in #Predicate. All status-based ordering and usage-tag filtering
/// is performed as Swift post-filter after the @Query result is received.
public struct ProgramView: View {

    // MARK: State

    @Environment(\.modelContext) private var ctx

    // Every block; `ProgramBlocks` orders them by status in Swift, since
    // derivedStatus is computed, not stored.
    @Query private var allBlocks: [Block]

    // Non-archived splits only — isArchived is a stored Bool so predicate-safe.
    @Query(
        filter: #Predicate<Split> { !$0.isArchived },
        sort: [SortDescriptor(\Split.name)]
    )
    private var allSplits: [Split]

    // Archived splits only, for the "Archived routines" entry.
    @Query(filter: #Predicate<Split> { $0.isArchived })
    private var archivedSplits: [Split]

    @State private var navigationPath = NavigationPath()
    @State private var pendingBlockBuilder: BlockBuilderRoute? = nil
    @State private var showingNewPopover = false
    @State private var presentingStartChoice = false
    @State private var showAllDone = false
    /// The ready block whose START BLOCK ▸ threw; its alert offers Try again and Open block.
    @State private var failedBlockStart: Block? = nil
    /// The header's height, which places + New's popover under it: a 44pt row and a 2pt rule at default text.
    @State private var headerHeight = BRUMetrics.touchTarget + BRUMetrics.Border.structural

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(ResumeWorkoutRequest.self) private var resumeRequest: ResumeWorkoutRequest?

    // MARK: Init

    public init() {}

    // MARK: Body

    public var body: some View {
        let blocks = ProgramBlocks(allBlocks)
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    BRUHeaderBar(center: title, right: HeaderAction("+ New") { showingNewPopover = true })
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                        // + New's touch area reaches past the header; in front
                        // of the scroll view, it takes those taps.
                        .zIndex(1)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ResumeWorkoutBanner(
                                onResume: { _ in resumeRequest?.isPending = true },
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
                                blocksSection(blocks)
                                routinesSection
                            }

                            if !archivedSplits.isEmpty {
                                archivedRoutinesEntry
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }

                if showingNewPopover {
                    newPopoverLayer
                }
            }
            .background(Color.bruPaper.ignoresSafeArea())
            .navigationBarHidden(true)
            // T-09-04 mitigation: register BlockOverviewRoute BEFORE any BLOCKS taps.
            .blockDestinations { pendingBlockBuilder = .edit($0) }
            .navigationDestination(for: ArchivedRoutinesRoute.self) { _ in
                ArchivedRoutinesView()
            }
            .newRoutineDestination(path: $navigationPath)
            .fullScreenCover(item: $pendingBlockBuilder) { route in
                route.builder(origin: .program)
            }
            .blockCreateFlow(isPresented: $presentingStartChoice) { pendingBlockBuilder = $0 }
            .modifier(TodayBlockAlerts(failedBlock: $failedBlockStart, onRetry: startBlock, onOpen: openBlock))
        }
    }

    /// "Fitbod / Program" outgrows its third of the header at default text,
    /// where no-break spaces keep it on one line, a little smaller, as
    /// Archived routines does. Larger text wraps between the words.
    private var title: String {
        dynamicTypeSize <= .large ? "Fitbod\u{00A0}/\u{00A0}Program" : "Fitbod / Program"
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

    /// "+ New routine" opens the name step. The routine (UI term; code
    /// `Split`) exists only once the user saves its name there, so backing
    /// out leaves nothing in ROUTINES.
    private func startNewRoutine() {
        navigationPath.append(NewRoutineRoute.name)
    }

    private func openBlock(_ block: Block) {
        navigationPath.append(BlockOverviewRoute.summary(blockID: block.id))
    }

    /// START BLOCK ▸ on the ready slab. It shows only while no block is
    /// active, so there is nothing to confirm; starting beside an active
    /// block stays on Block overview, which asks first.
    private func startBlock(_ block: Block) {
        do {
            try BlockLifecycleService.start(block: block, context: ctx)
            failedBlockStart = nil
        } catch {
            failedBlockStart = block
        }
    }

    // MARK: Static data

    /// One row per catalog template, in catalog order.
    static let templateRows: [ProgramTemplateRowContent] =
        BlockTemplates.catalog.map(ProgramTemplateRowContent.init)

    // MARK: - Blocks

    /// The lead block, then PLANNED, then the finished blocks.
    @ViewBuilder
    private func blocksSection(_ blocks: ProgramBlocks) -> some View {
        if let active = blocks.active {
            ActiveBlockSlab(block: active) { openBlock(active) }
        } else if let ready = blocks.ready.first {
            ReadyBlockCard(
                block: ready, readyCount: blocks.ready.count,
                onStart: { startBlock(ready) }, onOpen: { openBlock(ready) }
            )
        } else if let draft = blocks.drafts.first {
            DraftBlockSlab(block: draft) { openBlock(draft) }
        } else {
            BRUSectionHead("Blocks")
            if allBlocks.isEmpty {
                noBlocksRow
            }
        }

        if !blocks.planned.isEmpty {
            BRUSectionHead("Planned")
            ForEach(Array(blocks.planned.enumerated()), id: \.element.id) { index, block in
                if index > 0 {
                    BRUDivider(.hair)
                }
                BlockStatusCard(block: block) { openBlock(block) }
            }
        }

        doneBlocks(blocks.past)
    }

    @ViewBuilder
    private func doneBlocks(_ doneBlocks: [Block]) -> some View {
        let visibleDone = showAllDone ? doneBlocks : Array(doneBlocks.prefix(3))

        ForEach(visibleDone) { block in
            BRUDivider(.hair)
            BlockStatusCard(block: block) { openBlock(block) }
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
                    .foregroundStyle(Color.bruSignalText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show all \(doneCount) completed blocks")
        }
    }

    /// BLOCKS once a routine has taken the first-run screen's place but no
    /// block exists: it says so and offers the hero's + DEFINE BLOCK ▶,
    /// which opens CREATE BLOCK. At accessibility sizes the action moves
    /// under the words.
    private var noBlocksRow: some View {
        noBlocksLayout {
            Text("No blocks yet.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .fixedSize(horizontal: false, vertical: true)

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 12)
            }

            Button {
                presentingStartChoice = true
            } label: {
                Text("+ DEFINE BLOCK ▶︎")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .foregroundStyle(Color.bruSignalText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: BRUMetrics.touchTarget, minHeight: BRUMetrics.touchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 0)
        .frame(maxWidth: .infinity, minHeight: BRUMetrics.touchTarget, alignment: .leading)
    }

    /// The words and the action on one line, or the action under the words
    /// at accessibility sizes.
    private var noBlocksLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 0))
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
                .foregroundStyle(Color.bruSignalText)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bruRow)

        BRUDivider(.ink)
    }

    // MARK: - Archived routines entry

    /// Opens the archived routines, where each one can be restored.
    private var archivedRoutinesEntry: some View {
        let count = archivedSplits.count
        return VStack(spacing: 0) {
            Button {
                navigationPath.append(ArchivedRoutinesRoute.list)
            } label: {
                HStack(spacing: 12) {
                    Text("Archived routines")
                        .font(BRUFont.labelSmall)
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(Color.bruInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    Text("\(count)")
                        .font(BRUFont.labelSmall)
                        .foregroundStyle(Color.bruMuted)

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
            .buttonStyle(.bruRow)
            .accessibilityLabel("Archived routines")
            .accessibilityValue(BRUCountLabel.text(count, "routine"))

            BRUDivider(.ink)
        }
    }
}

// MARK: - ProgramBlocks

/// Program's blocks by status, each list in the order the page shows it.
/// `startDate` is a block's creation date until it starts (O-14), so it
/// orders the blocks that have not started.
struct ProgramBlocks {
    /// The running block; one at most (`BlockLifecycleService`).
    let active: Block?
    /// Oldest created first (O-6).
    let ready: [Block]
    /// Newest created first: the draft made last is the one the lifter moved on to (O-6).
    let drafts: [Block]
    /// Completed blocks, the newest ended first.
    let past: [Block]

    init(_ blocks: [Block]) {
        active = blocks.first { $0.derivedStatus == .active }
        ready = blocks.filter { $0.derivedStatus == .ready }.sorted(by: Self.readyOrder)
        drafts = blocks.filter { $0.derivedStatus == .draft }.sorted {
            ($1.startDate, $0.name, $0.id.uuidString) < ($0.startDate, $1.name, $1.id.uuidString)
        }
        past = blocks.filter { $0.derivedStatus == .completed }.sorted {
            ($0.endDate ?? .distantPast) > ($1.endDate ?? .distantPast)
        }
    }

    /// The block the page leads with: the active one, else the first ready
    /// one, else the newest draft.
    var lead: Block? { active ?? ready.first ?? drafts.first }

    /// PLANNED: the ready blocks, then the drafts, without the lead.
    var planned: [Block] { (ready + drafts).filter { $0.id != lead?.id } }

    /// Today's T-READY and Program's ready slab both lead with the first
    /// ready block in this order: oldest created, then name, then id (O-6).
    static func readyOrder(_ a: Block, _ b: Block) -> Bool {
        (a.startDate, a.name, a.id.uuidString) < (b.startDate, b.name, b.id.uuidString)
    }
}

extension Block {
    /// The name Program shows, "Untitled Block" while it has none.
    var programName: String { name.isEmpty ? "Untitled Block" : name }
}

private extension BlockStatus {
    /// The chip's word, and the start of the block's VoiceOver label, "READY block: …".
    var word: String {
        switch self {
        case .active: "Active"
        case .ready: "Ready"
        case .draft: "Draft"
        case .completed: "Done"
        }
    }
}

private extension BlockMissingPiece {
    /// What a draft still lacks, as Program says it: "No routine yet".
    var draftLine: String {
        switch self {
        case .name: "No name yet"
        case .phase: "No phases yet"
        case .routine: "No routine yet"
        case .session: "Its routine has no sessions"
        case .trainingDays(let count): "Pick \(BRUCountLabel.text(count, "training day"))"
        }
    }
}

// MARK: - ActiveBlockSlab

/// The active block, first and largest: its name, where it is in its plan
/// and the routine it runs. The whole slab opens Block overview, which keeps
/// the week cells (O-13).
fileprivate struct ActiveBlockSlab: View {
    let block: Block
    let onOpen: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let position = BlockPosition.label(block, on: .now)
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                labelRowLayout {
                    slabLabel("● Active block", muted: true)
                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer(minLength: 12)
                    }
                    slabLabel("Open ›", muted: false)
                }
                BRUDisplay(block.programName, size: .large, color: .bruOnSlab)
                    .fixedSize(horizontal: false, vertical: true)
                slabLabel(position.line, muted: false)
                slabLabel(routineLine, muted: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bruSlab)
        }
        .buttonStyle(.bruRow)
        .accessibilityLabel("ACTIVE block: \(block.programName). \(position.spoken).")
        .accessibilityValue(routineLine.replacingOccurrences(of: " · ", with: ", "))
    }

    /// The routine's name, "· Rotation" on a rotation block.
    private var routineLine: String {
        guard let routine = block.split else { return "No routine" }
        return block.schedulingMode == .rotation ? "\(routine.name) · Rotation" : routine.name
    }

    private func slabLabel(_ text: String, muted: Bool) -> some View {
        Text(text)
            .font(BRUFont.labelSmall)
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(Color.bruOnSlab.opacity(muted ? 0.6 : 1))
            .fixedSize(horizontal: false, vertical: true)
    }

    /// ACTIVE BLOCK beside OPEN ›, or over it at accessibility sizes.
    private var labelRowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 0))
    }
}

// MARK: - DraftBlockSlab

/// With drafts only, nothing can start: the newest draft leads on paper,
/// naming what it lacks, and CONTINUE BLOCK ▸ opens it in Block overview,
/// whose Edit opens the builder.
fileprivate struct DraftBlockSlab: View {
    let block: Block
    let onContinue: () -> Void

    var body: some View {
        let missing = block.missingPiece?.draftLine ?? ""
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Draft")
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                BRUDisplay(block.programName, size: .large)
                    .fixedSize(horizontal: false, vertical: true)
                Text(missing)
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("DRAFT block: \(block.programName)")
            .accessibilityValue(missing)

            BRUButton("Continue block ▸", kind: .primary, size: .lg, action: onContinue)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bruPaper)
        .overlay { Rectangle().strokeBorder(Color.bruInk, lineWidth: BRUMetrics.Border.structural) }
        .padding(16)
    }
}

// MARK: - BlockStatusCard

/// A block under PLANNED: its outlined status chip and name, then
/// "6 weeks · 3 phases · Push Pull Legs", then when a ready block was
/// created or what a draft still lacks. Opens Block overview.
fileprivate struct BlockStatusCard: View {

    let block: Block
    let onTap: () -> Void

    var body: some View {
        let status = block.derivedStatus
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    BRUChip(status.word)
                    Text(block.programName)
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ProgramRowChevron()
                }
                if let summary {
                    subline(summary, color: .bruInk)
                }
                if let detail {
                    subline(detail, color: .bruMuted)
                }
            }
            .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: BRUMetrics.touchTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bruRow)
        .accessibilityLabel("\(status.word.uppercased()) block: \(block.programName)")
        .accessibilityValue([summary, detail].compactMap { $0 }.joined(separator: ", "))
    }

    /// Its weeks, phases and routine, or nil while it has no phases.
    private var summary: String? {
        (block.phases ?? []).isEmpty ? nil : ReadyBlockCard.summary(of: block)
    }

    /// "Created Oct 3" for a ready block, or what a draft still lacks.
    private var detail: String? {
        switch block.derivedStatus {
        case .ready: ReadyBlockCard.created(block)
        case .draft: block.missingPiece?.draftLine
        case .active, .completed: nil
        }
    }

    private func subline(_ text: String, color: Color) -> some View {
        Text(text)
            .font(BRUFont.bodyDefault)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - RoutineSplitRow

/// Row for a single Split in the ROUTINES section.
/// Fileprivate so it can access ProgramChipFlow and ProgramScreenTokens.
fileprivate struct RoutineSplitRow: View {

    let split: Split
    let onTap: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                partsLayout {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(split.name.isEmpty ? "Untitled Routine" : split.name)
                            .font(BRUFont.bodyEmphasis)
                            .foregroundStyle(Color.bruInk)

                        Text(BRUCountLabel.text(sessionCount, "session"))
                            .font(BRUFont.bodyDefault)
                            .foregroundStyle(Color.bruMuted)
                    }

                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer()
                    }

                    if !liveBlockNames.isEmpty {
                        UsageTagFlow(names: liveBlockNames)
                    }
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
        .buttonStyle(.bruRow)
    }

    /// The name beside its block tags, or above them at accessibility
    /// sizes, where a tag beside the name runs off the screen.
    private var partsLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
    }
}

// MARK: - UsageTagFlow

/// Wrapping horizontal flow of usage tag chips using ProgramChipFlow layout.
/// At accessibility sizes the tags stack, one to a line, and a tag wider
/// than the row wraps its words instead of running off the screen.
/// Renders nothing when names is empty (no "unused" label).
fileprivate struct UsageTagFlow: View {

    let names: [String]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if names.isEmpty {
            EmptyView()
        } else if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: ProgramScreenTokens.chipRowSpacing) {
                ForEach(names, id: \.self) { name in
                    BRUChip(name)
                }
            }
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

/// Create block: Blank Block or Use Preset, then the preset list. The pick
/// opens once both sheets have gone, through `onChoose`. Program's + NEW
/// and + DEFINE BLOCK and Today's "Start a block" open it, so a block
/// starts the same way from either tab.
struct BlockCreateFlow: ViewModifier {
    @Binding var isPresented: Bool
    let onChoose: (BlockBuilderRoute) -> Void

    @State private var presentingPresetPicker = false
    @State private var staged: BlockBuilderRoute? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented, onDismiss: {
            if let staged {
                onChoose(staged)
                self.staged = nil
            }
        }) {
            NewBlockStartChoiceSheet(
                onScratch: {
                    staged = .newBlock(nil)
                    isPresented = false
                },
                onPreset: {
                    presentingPresetPicker = true
                }
            )
            .sheet(isPresented: $presentingPresetPicker, onDismiss: {
                if staged != nil {
                    isPresented = false
                }
            }) {
                NewBlockPresetPickerSheet { chosenPreset in
                    staged = .newBlock(chosenPreset)
                    presentingPresetPicker = false
                }
                .presentationDetents(detents)
                .presentationDragIndicator(.visible)
            }
            .presentationDetents(detents)
            .presentationDragIndicator(.visible)
        }
    }

    /// CREATE BLOCK and CHOOSE PRESET open at half height, or at full height
    /// at accessibility sizes, where their rows outgrow half the screen.
    private var detents: Set<PresentationDetent> {
        dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium]
    }
}

extension View {
    /// Presents Create block while `isPresented`; `onChoose` gets the
    /// builder route the lifter picked.
    func blockCreateFlow(isPresented: Binding<Bool>, onChoose: @escaping (BlockBuilderRoute) -> Void) -> some View {
        modifier(BlockCreateFlow(isPresented: isPresented, onChoose: onChoose))
    }
}

fileprivate struct NewBlockStartChoiceSheet: View {
    let onScratch: () -> Void
    let onPreset: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            Color.bruPaper.ignoresSafeArea()

            VStack(spacing: 0) {
                // Title (left-aligned, editorial — high contrast on paper)
                VStack(alignment: .leading, spacing: 6) {
                    Text("CREATE BLOCK")
                        .font(.bru(.condensed, size: 30))
                        .tracking(1.5)
                        .foregroundStyle(Color.bruInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Choose a starting point for your reusable training block.")
                        .font(.bru(.text, size: 13))
                        .foregroundStyle(Color.bruMuted)
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
                    .foregroundStyle(Color.bruMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
                    .padding(.bottom, 10)

                // Divider
                Rectangle()
                    .fill(Color.bruInk)
                    .frame(height: 2)

                // Choice: Blank Block
                Button(action: onScratch) {
                    HStack(alignment: .center, spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Blank Block")
                                .font(.bru(.grotesk, size: 15))
                                .foregroundStyle(Color.bruInk)
                            Text("Build your own phases manually.")
                                .font(.bru(.grotesk, size: 11))
                                .tracking(ProgramScreenTokens.headerLetterSpacing)
                                .foregroundStyle(Color.bruMuted)
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
                .buttonStyle(.bruRow)
                .background(Color.bruPaper)

                // Divider
                Rectangle()
                    .fill(Color.bruHair)
                    .frame(height: 1)

                // Choice: Use Preset
                Button(action: onPreset) {
                    HStack(alignment: .center, spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use Preset")
                                .font(.bru(.grotesk, size: 15))
                                .foregroundStyle(Color.bruInk)
                            Text("Start from \(BlockTemplates.catalog.map(\.name).formatted(.list(type: .or))).")
                                .font(.bru(.grotesk, size: 11))
                                .tracking(ProgramScreenTokens.headerLetterSpacing)
                                .foregroundStyle(Color.bruMuted)
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
                .buttonStyle(.bruRow)
                .background(Color.bruPaper)

                // Divider
                Rectangle()
                    .fill(Color.bruInk)
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
            Color.bruPaper.ignoresSafeArea()

            VStack(spacing: 0) {
                // Title (left-aligned, editorial — high contrast on paper)
                Text("CHOOSE PRESET")
                    .font(.bru(.condensed, size: 30))
                    .tracking(1.5)
                    .foregroundStyle(Color.bruInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                // Top rule
                Rectangle()
                    .fill(Color.bruInk)
                    .frame(height: 2)

                ForEach(Array(NewBlockPreset.all.enumerated()), id: \.element) { index, preset in
                    Button {
                        onSelect(preset)
                    } label: {
                        HStack(alignment: .center, spacing: 0) {
                            Text(preset == .blank ? "FROM SCRATCH" : preset.label)
                                .font(.bru(.grotesk, size: 13))
                                .tracking(1.5)
                                .foregroundStyle(Color.bruInk)
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
                    .buttonStyle(.bruRow)
                    .background(Color.bruPaper)

                    if index < NewBlockPreset.all.count - 1 {
                        Rectangle()
                            .fill(Color.bruHair)
                            .frame(height: 1)
                    }
                }

                // Bottom rule
                Rectangle()
                    .fill(Color.bruInk)
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
    static let blackDividerThickness: CGFloat = 2
    static let lightRowDividerThickness: CGFloat = 1
    static let horizontalPagePadding: CGFloat = 16

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
    static let bodyLineSpacing: CGFloat = 2

    static let ctaTopSpacing: CGFloat = 16
    static let ctaHeight: CGFloat = 71
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

}

// MARK: - ProgramTypography

fileprivate enum ProgramTypography {
    static let chromeLabel: Font = .bru(.grotesk, size: ProgramScreenTokens.headerLabelFontSize)
    static let templateMeta: Font = .bru(.grotesk, size: ProgramScreenTokens.templateMetaFontSize)
}

// MARK: - Program Dividers

fileprivate struct ProgramInkDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.bruInk)
            .frame(height: ProgramScreenTokens.blackDividerThickness)
    }
}

fileprivate struct ProgramHairDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.bruHair)
            .frame(height: ProgramScreenTokens.lightRowDividerThickness)
    }
}

fileprivate struct ProgramTemplateHeaderDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.bruInk)
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
                    .foregroundStyle(Color.bruMuted)
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
            .foregroundStyle(Color.bruInk)
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
            .foregroundStyle(Color.bruInk)
            .lineSpacing(ProgramScreenTokens.bodyLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var defineCTA: some View {
        Button(action: defineAction) {
            Text("+ DEFINE BLOCK ▶︎")
                .font(.bru(.condensed, size: ProgramScreenTokens.ctaFontSize))
                .tracking(ProgramScreenTokens.noProgramLetterSpacing)
                .foregroundStyle(Color.bruSignal.bruLabelOnFill)
            .frame(maxWidth: .infinity)
            .frame(minHeight: ProgramScreenTokens.ctaHeight)
            .background(Color.bruSignal)
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
            .foregroundStyle(Color.bruInk)
            .padding(.horizontal, ProgramScreenTokens.chipHorizontalPadding)
            .frame(minHeight: minHeight)
            .overlay(
                Rectangle()
                    .stroke(Color.bruInk, lineWidth: ProgramScreenTokens.chipBorderWidth)
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
                    .foregroundStyle(Color.bruInk)

                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer()
                }

                Text(right)
                    .foregroundStyle(Color.bruMuted)
            }
            .font(ProgramTypography.chromeLabel)
            .tracking(ProgramScreenTokens.headerLetterSpacing)
            .textCase(.uppercase)
            .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
            .padding(.vertical, 4)
            .frame(minHeight: ProgramScreenTokens.templateHeaderHeight - ProgramScreenTokens.templateHeaderDividerThickness)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bruPaper)

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
                        .foregroundStyle(Color.bruInk)
                        .frame(width: weeksWidth, alignment: .leading)

                    VStack(alignment: .leading, spacing: ProgramScreenTokens.templateTextSpacing) {
                        Text(content.title)
                            .font(.bru(.text, size: ProgramScreenTokens.templateTitleFontSize))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.bruInk)
                            .modifier(ProgramRowTextFit(minimumScaleFactor: 0.9))

                        Text(content.phases)
                            .font(ProgramTypography.templateMeta)
                            .tracking(ProgramScreenTokens.headerLetterSpacing)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.bruMuted)
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
        .buttonStyle(.bruRow)
        .background(Color.bruPaper)
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
            .foregroundStyle(Color.bruMuted)
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
