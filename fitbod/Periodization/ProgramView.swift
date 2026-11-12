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
//    logger on Today's stack through ResumeWorkoutRequest (FT-02), and
//    its DISCARD follows Today's slab (RM-012). RESUME ▸ is then the
//    page's one signal: START BLOCK ▸, + NEW ROUTINE and the + NEW BLOCK
//    and + NEW ROUTINE links draw in ink.
//  - The lead block (`ProgramBlocks.lead`): the active block as an ink slab
//    that opens Block overview (no week cells, O-13); with none active, the
//    oldest created ready block with START BLOCK ▸ (O-6); with drafts only,
//    the newest created draft with CONTINUE BLOCK ▸.
//  - PLANNED: the other ready blocks, oldest created first, then the other
//    drafts, newest created first. With no live block, BLOCKS says "No
//    block yet." or "No block planned." beside + NEW BLOCK.
//  - ROUTINES: each routine over "3 sessions · used by Spring Block", or
//    "No routines yet." beside + NEW ROUTINE, then "Archived routines · n ›"
//    while one is archived.
//  - PAST BLOCKS · n ›, which pushes PastBlocksView.
//
//  A store with no block and no live routine shows only "Start with a
//  routine" and + NEW ROUTINE, with Archived routines under it when any
//  exist. Presets live only inside + New block › Use Preset (O-8).
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

    // The workout in progress, for the resume banner.
    @Query(filter: #Predicate<Session> { $0.completedAt == nil })
    private var openWorkouts: [Session]

    @State private var navigationPath = NavigationPath()
    @State private var pendingBlockBuilder: BlockBuilderRoute? = nil
    @State private var showingNewPopover = false
    @State private var presentingStartChoice = false
    /// The ready block whose START BLOCK ▸ threw; its alert offers Try again and Open block.
    @State private var failedBlockStart: Block? = nil
    #if DEBUG
    /// UI tests' `-fitbod-fail-block-start-once` makes the first START BLOCK ▸ throw, as on Today.
    @State private var failNextBlockStart = ProcessInfo.processInfo.arguments.contains("-fitbod-fail-block-start-once")
    #endif
    /// The header's height, which places + New's popover under it: a 44pt row and a 2pt rule at default text.
    @State private var headerHeight = BRUMetrics.touchTarget + BRUMetrics.Border.structural

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
                            if let openWorkout {
                                ResumeWorkoutBanner(session: openWorkout) { resumeRequest?.isPending = true }
                            }

                            if allBlocks.isEmpty && allSplits.isEmpty {
                                startWithARoutine
                                if !archivedSplits.isEmpty {
                                    archivedRoutinesEntry
                                }
                            } else {
                                blocksSection(blocks)
                                routinesSection
                                if !blocks.past.isEmpty {
                                    pastBlocksEntry(count: blocks.past.count)
                                }
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
            .blockDestinations(origin: .program) { pendingBlockBuilder = .edit($0) }
            .navigationDestination(for: ArchivedRoutinesRoute.self) { _ in
                ArchivedRoutinesView()
            }
            .navigationDestination(for: PastBlocksRoute.self) { _ in
                PastBlocksView()
            }
            .newRoutineDestination(path: $navigationPath)
            .fullScreenCover(item: $pendingBlockBuilder) { route in
                route.builder(origin: .program)
            }
            .blockCreateFlow(isPresented: $presentingStartChoice) { pendingBlockBuilder = $0 }
            .modifier(TodayBlockAlerts(failedBlock: $failedBlockStart, onRetry: startBlock, onOpen: openBlock))
        }
    }

    /// The workout in progress. Its banner's RESUME ▸ is then the page's one
    /// signal, so every other signal control draws in ink (RM-012).
    private var openWorkout: Session? { openWorkouts.first }

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

    /// + New block opens CREATE BLOCK, whose Use Preset holds the presets (O-8).
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
            #if DEBUG
            if failNextBlockStart {
                failNextBlockStart = false
                throw CocoaError(.fileWriteUnknown)
            }
            #endif
            try BlockLifecycleService.start(block: block, context: ctx)
            failedBlockStart = nil
        } catch {
            failedBlockStart = block
        }
    }

    // MARK: - Empty program

    /// A fresh store starts with a routine; blocks schedule one later, and
    /// the presets wait inside + New block (O-8).
    private var startWithARoutine: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start with a routine")
                .font(BRUFont.condensedHeading)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruInk)
                .fixedSize(horizontal: false, vertical: true)
            Text("A routine is your split, like Push / Pull / Legs. Each session in it lists exercises with target sets and reps. Blocks schedule a routine across weeks, and come after.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .fixedSize(horizontal: false, vertical: true)
            BRUButton("+ New routine", kind: openWorkout == nil ? .signal : .primary, size: .lg, action: startNewRoutine)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    // MARK: - Blocks

    /// The lead block, or BLOCKS saying there is none, then PLANNED.
    @ViewBuilder
    private func blocksSection(_ blocks: ProgramBlocks) -> some View {
        if let active = blocks.active {
            ActiveBlockSlab(block: active) { openBlock(active) }
        } else if let ready = blocks.ready.first {
            ReadyBlockCard(
                block: ready, readyCount: blocks.ready.count,
                onStart: { startBlock(ready) }, onOpen: { openBlock(ready) },
                isSignal: openWorkout == nil
            )
        } else if let draft = blocks.drafts.first {
            DraftBlockSlab(block: draft) { openBlock(draft) }
        } else {
            // The header's rule is this head's top rule, so the two do not
            // stack into one thick rule (D-299).
            BRUSectionHead("Blocks")
                .padding(.top, -BRUMetrics.Border.structural)
            // A block runs a routine, so with none the routine link is the signal.
            EmptySectionLine(
                message: blocks.past.isEmpty ? "No block yet." : "No block planned.",
                action: "+ New block", isSignal: !allSplits.isEmpty && openWorkout == nil,
                onTap: { presentingStartChoice = true }
            )
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
    }

    // MARK: - Routines

    @ViewBuilder
    private var routinesSection: some View {
        BRUSectionHead("Routines")

        if allSplits.isEmpty {
            EmptySectionLine(message: "No routines yet.", action: "+ New routine", isSignal: openWorkout == nil, onTap: startNewRoutine)
        }

        ForEach(Array(allSplits.enumerated()), id: \.element.id) { index, split in
            if index > 0 {
                BRUDivider(.hair)
            }
            RoutineSplitRow(split: split) {
                navigationPath.append(SplitDetailRoute.detail(splitID: split.id))
            }
        }

        if !archivedSplits.isEmpty {
            archivedRoutinesEntry
        }
    }

    /// "Archived routines · 2 ›", muted, in every state while a routine is
    /// archived; it opens the list where each one can be restored.
    private var archivedRoutinesEntry: some View {
        let count = archivedSplits.count
        return VStack(spacing: 0) {
            BRUDivider(.hair)
            Button {
                navigationPath.append(ArchivedRoutinesRoute.list)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Archived routines · \(count)")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ProgramRowChevron()
                }
                .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: BRUMetrics.touchTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.bruRow)
            .accessibilityLabel("Archived routines")
            .accessibilityValue(BRUCountLabel.text(count, "routine"))
        }
    }

    // MARK: - Past blocks

    /// "PAST BLOCKS · 3 ›": the finished blocks, out of the way, one tap to
    /// their list, where a review reopens from its block.
    private func pastBlocksEntry(count: Int) -> some View {
        VStack(spacing: 0) {
            BRUDivider(.ink)
            Button {
                navigationPath.append(PastBlocksRoute.list)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    // The section heads' type, since this row heads a list one tap away.
                    Text("Past blocks · \(count)")
                        .font(.bru(.grotesk, size: 14))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ProgramRowChevron()
                }
                .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: BRUMetrics.touchTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.bruRow)
            .accessibilityLabel("Past blocks")
            .accessibilityValue(BRUCountLabel.text(count, "block"))
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
        .accessibilityValue(routineLine.replacingOccurrences(of: "\u{00A0}· ", with: ", "))
    }

    /// The routine's name, "· Rotation" on a rotation block. A no-break
    /// space keeps the dot off the start of a wrapped line.
    private var routineLine: String {
        guard let routine = block.split else { return "No routine" }
        return block.schedulingMode == .rotation ? "\(routine.name)\u{00A0}· Rotation" : routine.name
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

/// A routine under ROUTINES: its name over "3 sessions · used by Spring
/// Block", the live blocks that run it, so the subline says what the chips
/// used to.
struct RoutineSplitRow: View {

    let split: Split
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(split.name.isEmpty ? "Untitled Routine" : split.name)
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(Self.subline(for: split))
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ProgramRowChevron()
            }
            .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: BRUMetrics.touchTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bruRow)
    }

    /// "3 sessions · used by Spring Block, Summer Block": the live (not
    /// completed) blocks on the routine by name, or the session count alone
    /// when none runs it. Post-filter in Swift: split.blocks plus
    /// derivedStatus is not expressible in #Predicate (T-09-06 mitigation).
    static func subline(for split: Split) -> String {
        let count = BRUCountLabel.text(split.slots?.count ?? 0, "session")
        let users = (split.blocks ?? [])
            .filter { $0.derivedStatus != .completed }
            .map(\.programName)
            .sorted()
        return users.isEmpty ? count : "\(count) · used by \(users.joined(separator: ", "))"
    }
}

// MARK: - EmptySectionLine

/// A section with nothing in it says so beside its one way forward, as
/// "No block yet. + NEW BLOCK". The action moves under the words at
/// accessibility sizes.
fileprivate struct EmptySectionLine: View {
    let message: String
    let action: String
    /// Signal text when it is the page's one way forward, ink otherwise.
    let isSignal: Bool
    let onTap: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        layout {
            Text(message)
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .fixedSize(horizontal: false, vertical: true)

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 12)
            }

            Button(action: onTap) {
                Text(action)
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(isSignal ? Color.bruSignalText : Color.bruInk)
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

    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 0))
    }
}

// MARK: - NewBlockStartChoiceSheet

/// Create block: Blank Block or Use Preset, then the preset list. The pick
/// opens once both sheets have gone, through `onChoose`. Program's
/// + New block and its + NEW BLOCK link open it; the presets live only
/// here (O-8).
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
    static let horizontalPagePadding: CGFloat = 16
    static let headerLetterSpacing: CGFloat = 1.2
    static let newPopoverTopGap: CGFloat = 4
    static let newPopoverTrailingPadding: CGFloat = 14
}

// MARK: - ProgramRowChevron

/// The muted "›" closing a row that opens a screen: 16pt at default text,
/// scaled like body text so it grows with the row's words. VoiceOver skips
/// it, since the row already reads as a button.
struct ProgramRowChevron: View {
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 16

    var body: some View {
        Text("›")
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(Color.bruMuted)
            .accessibilityHidden(true)
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
