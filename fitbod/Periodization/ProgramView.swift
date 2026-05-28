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
//  - Feature chips rendered by a wrapping layout using fixed chip tokens.
//  - ProgramTemplateSection: compact ProgramTemplateHeader + four
//    ProgramTemplateRow presets mapped to existing BlockTemplates.
//
//  ## Scope decisions (260525-gen)
//
//  - Always renders the empty-state design regardless of existing Block
//    count. The "active block" populated state is a separate task.
//  - Drops the search bar, folder/routine list, New Folder / History menu,
//    and the active-session conflict alert that lived in RoutinesListView.
//  - "+ NEW" opens the custom BRU action popover from bru-screens/New-modal:
//    "+ New block" routes to a blank block builder, "+ New routine" routes
//    to the existing RoutineBuilderView.
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

/// Program tab body — BRU brutalist empty-state surface for periodization.
public struct ProgramView: View {

    // MARK: State

    @Environment(\.modelContext) private var ctx

    @Query(filter: #Predicate<Session> { $0.completedAt == nil })
    private var activeSessions: [Session]

    @State private var navigationPath = NavigationPath()
    @State private var pendingBlockBuilder: PendingBlockBuilder? = nil
    @State private var showingNewPopover = false
    @State private var presentingNewRoutine = false

    // MARK: Init

    public init() {}

    // MARK: Body

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    ProgramChromeHeader(onNew: { showingNewPopover = true })

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

                            NoProgramHero(
                                defineAction: { startBlank() }
                            )

                            ProgramTemplateSection(
                                presets: ProgramView.templatePresets,
                                onSelect: { preset in
                                    pendingBlockBuilder = .template(preset.template)
                                }
                            )
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
            .fullScreenCover(item: $pendingBlockBuilder) { pending in
                switch pending {
                case .newBlock:
                    BlockBuilderView(draft: BlockDraft.newBlock())
                case .template(let template):
                    BlockBuilderView(draft: BlockDraft(template: template))
                }
            }
            .sheet(isPresented: $presentingNewRoutine) {
                NavigationStack {
                    RoutineBuilderView(draft: RoutineDraft())
                }
            }
        }
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
            .padding(.top, ProgramChromeHeader.totalHeight + ProgramScreenTokens.newPopoverTopGap)
            .padding(.trailing, ProgramScreenTokens.newPopoverTrailingPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
        .zIndex(1)
    }

    // MARK: Actions

    private func startBlank() {
        pendingBlockBuilder = .newBlock
    }

    private func startNewRoutine() {
        presentingNewRoutine = true
    }

    // MARK: Static data

    fileprivate static let templatePresets: [ProgramTemplatePreset] = [
        ProgramTemplatePreset(
            weeks: "5W",
            title: "Hypertrophy meso",
            cadence: "4 / WK · INTERMEDIATE",
            phaseDescriptor: "ACCUM 3 · INTNS 1 · DELOAD 1",
            popular: true,
            template: BlockTemplates.hypertrophy
        ),
        ProgramTemplatePreset(
            weeks: "4W",
            title: "Linear strength",
            cadence: "3 / WK · BEGINNER",
            phaseDescriptor: "BUILD 3 · TEST 1",
            popular: false,
            template: BlockTemplates.generic
        ),
        ProgramTemplatePreset(
            weeks: "8W",
            title: "Powerbuilding",
            cadence: "5 / WK · ADVANCED",
            phaseDescriptor: "ACCUM 3 · INTNS 2 · PEAK 2 · DELOAD 1",
            popular: false,
            template: BlockTemplates.powerliftingPeak
        ),
        ProgramTemplatePreset(
            weeks: "4W",
            title: "5 / 3 / 1 cycle",
            cadence: "4 / WK · INTERMEDIATE",
            phaseDescriptor: "WEEK 1 · 2 · 3 · DELOAD",
            popular: false,
            template: BlockTemplates.blank
        ),
    ]

    private enum PendingBlockBuilder: Identifiable {
        case newBlock
        case template(BlockTemplate)

        var id: String {
            switch self {
            case .newBlock:
                return "new-block"
            case .template(let template):
                return "template-\(template.name)"
            }
        }
    }
}

// MARK: - ProgramScreenTokens

fileprivate enum ProgramScreenTokens {
    static let screenBackground = Color(red: 240 / 255, green: 237 / 255, blue: 229 / 255)
    static let ink = Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255)
    static let muted = Color(red: 126 / 255, green: 123 / 255, blue: 114 / 255)
    static let blackDividerThickness: CGFloat = 2
    static let lightRowDividerColor = Color(red: 212 / 255, green: 209 / 255, blue: 202 / 255)
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
    static let ctaColor = Color(red: 255 / 255, green: 77 / 255, blue: 46 / 255)
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
    static let popularBadgeSpacing: CGFloat = 2
    static let templateWeeksFontSize: CGFloat = 32
    static let templateWeeksWidth: CGFloat = 56
    static let popularBadgeWidth: CGFloat = 62
    static let popularBadgeHeight: CGFloat = 18

    static let bottomTabBarHeight: CGFloat = 63
    static let selectedTabWidth: CGFloat = 99
    static let selectedTabHeight: CGFloat = 29
    static let bottomSafeAreaSpacing: CGFloat = 34
}

// MARK: - ProgramTypography

fileprivate enum ProgramTypography {
    static let chromeLabel: Font = .custom("SpaceGrotesk-Bold", size: ProgramScreenTokens.headerLabelFontSize)
    static let templateMeta: Font = .custom("SpaceGrotesk-Bold", size: ProgramScreenTokens.templateMetaFontSize)
}

// MARK: - ProgramChromeHeader

fileprivate struct ProgramChromeHeader: View {
    static let totalHeight: CGFloat = ProgramScreenTokens.topHeaderHeight

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
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
            .frame(height: ProgramScreenTokens.topHeaderRowHeight)
            .frame(maxWidth: .infinity)
            .background(ProgramScreenTokens.screenBackground)

            rule
        }
        .frame(height: Self.totalHeight)
        .background(ProgramScreenTokens.screenBackground)
    }

    private var rule: some View {
        Rectangle()
            .fill(ProgramScreenTokens.ink)
            .frame(height: ProgramScreenTokens.blackDividerThickness)
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

// MARK: - ProgramTemplatePreset

fileprivate struct ProgramTemplatePreset: Identifiable {
    let weeks: String
    let title: String
    let cadence: String
    let phaseDescriptor: String
    let popular: Bool
    let template: BlockTemplate

    var id: String { "\(weeks)-\(title)" }
}

// MARK: - NoProgramHero

/// Hero block: ACTIVE BLOCK caption, big condensed NO PROGRAM headline,
/// explanatory body paragraph with inline bold on the phase keywords,
/// coral CTA, and a wrapping feature-chip row (3 + 1).
fileprivate struct NoProgramHero: View {

    let defineAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Active block · None")
                    .font(.custom("SpaceGrotesk-Bold", size: ProgramScreenTokens.heroCaptionFontSize))
                    .tracking(ProgramScreenTokens.heroCaptionLetterSpacing)
                    .textCase(.uppercase)
                    .foregroundStyle(ProgramScreenTokens.muted)
                    .frame(height: ProgramScreenTokens.heroCaptionLineHeight, alignment: .center)

                heroHeadline
                    .padding(.top, ProgramScreenTokens.captionToHeadlineSpacing)

                bodyParagraph
                    .padding(.top, ProgramScreenTokens.headlineToBodySpacing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
            .padding(.top, ProgramScreenTokens.heroTopPadding)
            .frame(height: ProgramScreenTokens.heroCopyHeight, alignment: .top)

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

    private var heroHeadline: some View {
        Text("NO PROGRAM")
            .font(.custom("BebasNeue-Regular", size: ProgramScreenTokens.noProgramFontSize))
            .foregroundStyle(ProgramScreenTokens.ink)
            .tracking(ProgramScreenTokens.noProgramLetterSpacing)
            .frame(height: ProgramScreenTokens.noProgramLineHeight, alignment: .center)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Body paragraph with inline bold on "accumulation, intensification,
    /// peak, deload." via SwiftUI Markdown so the span flows inline with
    /// the surrounding regular weight.
    private var bodyParagraph: some View {
        Text(.init("A block schedules routines across weeks and phases — **accumulation, intensification, peak, deload.** You can also lift without a block, but Fitbod really earns its keep when you’re running one."))
            .font(.custom("Geist-Regular", size: ProgramScreenTokens.bodyFontSize))
            .foregroundStyle(ProgramScreenTokens.ink)
            .lineSpacing(ProgramScreenTokens.bodyLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var defineCTA: some View {
        Button(action: defineAction) {
            Text("+ DEFINE BLOCK ▶︎")
                .font(.custom("BebasNeue-Regular", size: ProgramScreenTokens.ctaFontSize))
                .tracking(ProgramScreenTokens.noProgramLetterSpacing)
                .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: ProgramScreenTokens.ctaHeight)
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

    var body: some View {
        Text(label)
            .font(.custom("SpaceGrotesk-Bold", size: ProgramScreenTokens.chipFontSize))
            .tracking(ProgramScreenTokens.chipLetterSpacing)
            .foregroundStyle(ProgramScreenTokens.ink)
            .padding(.horizontal, ProgramScreenTokens.chipHorizontalPadding)
            .frame(height: ProgramScreenTokens.chipHeight)
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

    let presets: [ProgramTemplatePreset]
    let onSelect: (ProgramTemplatePreset) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ProgramTemplateHeader(
                title: "Or start from a template",
                right: "\(presets.count) presets"
            )

            ForEach(Array(presets.enumerated()), id: \.element.id) { index, preset in
                ProgramTemplateRow(preset: preset) {
                    onSelect(preset)
                }
                if index < presets.count - 1 {
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

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text(title)
                    .foregroundStyle(ProgramScreenTokens.ink)

                Spacer()

                Text(right)
                    .foregroundStyle(ProgramScreenTokens.muted)
            }
            .font(ProgramTypography.chromeLabel)
            .tracking(ProgramScreenTokens.headerLetterSpacing)
            .textCase(.uppercase)
            .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
            .frame(height: ProgramScreenTokens.templateHeaderHeight - ProgramScreenTokens.templateHeaderDividerThickness)
            .background(ProgramScreenTokens.screenBackground)

            ProgramTemplateHeaderDivider()
        }
    }
}

// MARK: - ProgramTemplateRow

/// One preset row: large condensed weeks label on the left, stacked
/// title / cadence / phase block in the middle (with optional POPULAR
/// badge inline next to the title), chevron on the right.
fileprivate struct ProgramTemplateRow: View {

    let preset: ProgramTemplatePreset
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 16) {
                Text(preset.weeks)
                    .font(.custom("BebasNeue-Regular", size: ProgramScreenTokens.templateWeeksFontSize))
                    .foregroundStyle(ProgramScreenTokens.ink)
                    .frame(width: ProgramScreenTokens.templateWeeksWidth, alignment: .leading)

                VStack(alignment: .leading, spacing: ProgramScreenTokens.templateTextSpacing) {
                    HStack(spacing: ProgramScreenTokens.popularBadgeSpacing) {
                        Text(preset.title)
                            .font(.custom("Geist-Regular", size: ProgramScreenTokens.templateTitleFontSize))
                            .fontWeight(.semibold)
                            .foregroundStyle(ProgramScreenTokens.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                        if preset.popular {
                            popularBadge
                        }
                        Spacer(minLength: 0)
                    }

                    Text(preset.cadence)
                        .font(ProgramTypography.templateMeta)
                        .tracking(ProgramScreenTokens.headerLetterSpacing)
                        .textCase(.uppercase)
                        .foregroundStyle(ProgramScreenTokens.muted)
                        .frame(height: ProgramScreenTokens.templateMetaLineHeight, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(preset.phaseDescriptor)
                        .font(ProgramTypography.templateMeta)
                        .tracking(ProgramScreenTokens.headerLetterSpacing)
                        .textCase(.uppercase)
                        .foregroundStyle(ProgramScreenTokens.muted)
                        .frame(height: ProgramScreenTokens.templateMetaLineHeight, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Text("›")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(ProgramScreenTokens.muted)
            }
            .padding(.horizontal, ProgramScreenTokens.horizontalPagePadding)
            .frame(height: ProgramScreenTokens.templateRowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(ProgramScreenTokens.screenBackground)
    }

    private var popularBadge: some View {
        Text("POPULAR")
            .font(.custom("SpaceGrotesk-Bold", size: 10))
            .tracking(1.5)
            .foregroundStyle(.white)
            .frame(width: ProgramScreenTokens.popularBadgeWidth, height: ProgramScreenTokens.popularBadgeHeight)
            .background(ProgramScreenTokens.ctaColor)
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
