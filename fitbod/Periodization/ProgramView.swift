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
//  - Custom pageHeader (not BRUHeaderBar) painted via .safeAreaInset(.top):
//      - Thin SETUP strip on the right
//      - BRUDivider(.ink)
//      - PROGRAM (left, bruInk) / + NEW (right, bruSignal) row
//      - BRUDivider(.ink)
//    BRUHeaderBar is bypassed here because BRUHeaderBar centers the
//    title and only paints a bottom rule — the mockup needs left-aligned
//    PROGRAM, right-aligned + NEW, and a top rule above the row.
//  - ResumeWorkoutBanner (reactive via its own @Query) when an active
//    Session exists.
//  - NoProgramHero: "ACTIVE BLOCK · NONE" caption, large condensed
//    "NO PROGRAM" headline (system .black .compressed), explanatory body
//    paragraph using SF system sans-serif with inline bold on the
//    accumulation/intensification/peak/deload keywords.
//  - Coral "+ DEFINE BLOCK ▸" CTA — inline button with bruSignal fill
//    and an explicit 68pt height (BRUButton .lg tier is 52pt — too short
//    for the mockup's hero CTA).
//  - Feature chip row: WEEKS / PHASES / DELOAD on line 1, CUSTOM wraps
//    to line 2. Hardcoded two-row VStack instead of a Layout protocol
//    implementation because the chip set is fixed at 4.
//  - ProgramTemplateSection: BRUSectionHead + four ProgramTemplateRow
//    presets mapped to existing BlockTemplates.
//
//  ## Scope decisions (260525-gen)
//
//  - Always renders the empty-state design regardless of existing Block
//    count. The "active block" populated state is a separate task.
//  - Drops the search bar, folder/routine list, "+ NEW" menu (New Routine
//    / New Folder / History), and the active-session conflict alert that
//    lived in RoutinesListView — none of those surfaces apply to a
//    Program empty state.
//  - "+ NEW" header action and the hero CTA both route to the same
//    blank-block flow (the mockup's "+ NEW" reads as "new program",
//    not the legacy Routine menu).
//
//  ## Font departures from the design system
//
//  Two BRU departures are intentional on this screen:
//  - The hero uses .system(size:weight:).width(.compressed) instead of
//    SpaceGrotesk-Bold — Space Grotesk is not a condensed cut, and the
//    mockup hero is unmistakably condensed. iOS 18 ships compressed
//    system weights so we get the look without bundling a font.
//  - The body paragraph uses SF system sans-serif (16pt) instead of
//    JetBrains Mono — the mockup body is plainly proportional sans-serif,
//    not mono. Using BRUFont.bodyDefault here visually breaks fidelity.
//  Both departures are scoped to this screen and documented at each call
//  site so future BRU audits don't flag them as drift.
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

    // MARK: Init

    public init() {}

    // MARK: Body

    public var body: some View {
        NavigationStack(path: $navigationPath) {
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
            .background(Color.bruPaper.ignoresSafeArea())
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top, spacing: 0) {
                pageHeader
            }
            .navigationDestination(for: SessionRoute.self) { route in
                switch route {
                case .logger(let session):
                    SessionLoggerView(session: session)
                }
            }
            .sheet(item: $pendingBlockBuilder) { pending in
                NavigationStack {
                    switch pending {
                    case .template(let template):
                        BlockBuilderView(draft: BlockDraft(template: template))
                    }
                }
            }
        }
    }

    // MARK: Page header (custom, not BRUHeaderBar)

    /// Two-tier top chrome that BRUHeaderBar can't express:
    ///   ─ SETUP right-aligned in a slim strip
    ///   ─ 2pt bruInk divider
    ///   ─ PROGRAM (left) / + NEW (right)
    ///   ─ 2pt bruInk divider
    ///
    /// Painted via .safeAreaInset(.top) so the rules pin to the top edge
    /// while the body scrolls beneath.
    @ViewBuilder
    private var pageHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("Setup")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruInk)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.bruPaper)

            BRUDivider(.ink)

            HStack(alignment: .center) {
                Text("Program")
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruInk)
                Spacer()
                Button {
                    startBlank()
                } label: {
                    Text("+ New")
                        .font(BRUFont.labelSmall)
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruSignal)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(Color.bruPaper)

            BRUDivider(.ink)
        }
    }

    // MARK: Actions

    private func startBlank() {
        pendingBlockBuilder = .template(BlockTemplates.blank)
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
        case template(BlockTemplate)

        var id: String {
            switch self {
            case .template(let template):
                return "template-\(template.name)"
            }
        }
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
            VStack(alignment: .leading, spacing: 20) {
                Text("Active block · None")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)

                heroHeadline

                bodyParagraph
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)

            BRUDivider(.ink)

            defineCTA
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)

            chipRows
                .padding(.horizontal, 16)
                .padding(.bottom, 24)

            BRUDivider(.ink)
        }
    }

    /// NO PROGRAM hero — system .black .width(.compressed) at ~84pt.
    /// Departure from BRUFont.displayHero (Space Grotesk Bold 56pt) is
    /// intentional: Space Grotesk has no condensed cut and the mockup
    /// hero is unmistakably condensed.
    private var heroHeadline: some View {
        Text("NO PROGRAM")
            .font(.system(size: 84, weight: .black).width(.compressed))
            .foregroundStyle(Color.bruInk)
            .tracking(-1)
            .lineSpacing(0)
            .minimumScaleFactor(0.75)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Body paragraph with inline bold on "accumulation, intensification,
    /// peak, deload." — concatenated Text segments so the bold span
    /// flows inline with the surrounding regular weight.
    /// Departure from BRUFont.bodyDefault (JetBrains Mono Regular 12pt)
    /// is intentional: mockup body is plainly proportional sans-serif.
    private var bodyParagraph: some View {
        let lead = Text("A block schedules routines across weeks and phases — ")
        let bold = Text("accumulation, intensification, peak, deload.")
            .fontWeight(.semibold)
        let tail = Text(" You can also lift without a block, but Fitbod really earns its keep when you’re running one.")

        return Text("\(lead)\(bold)\(tail)")
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(Color.bruInk)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Coral define-block CTA — 68pt tall (BRUButton .lg is 52pt and
    /// reads too short next to the mockup). Inline Button + bruSignal
    /// background gives us exact control without bending BRUButton's
    /// size enum.
    private var defineCTA: some View {
        Button(action: defineAction) {
            Text("+ Define block  ▸")
                .font(BRUFont.bodyEmphasis)
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruPaper)
                .frame(maxWidth: .infinity, minHeight: 68)
                .background(Color.bruSignal)
        }
        .buttonStyle(.plain)
    }

    /// Two-row chip layout: WEEKS / PHASES / DELOAD on row 1, CUSTOM
    /// alone on row 2. Hardcoded because the set is fixed at 4 — using
    /// a Layout protocol implementation would be overkill.
    private var chipRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ProgramFeatureChip(label: "Weeks · 4-12")
                ProgramFeatureChip(label: "Phases · 1-4")
                ProgramFeatureChip(label: "Deload optional")
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                ProgramFeatureChip(label: "Custom")
                Spacer(minLength: 0)
            }
        }
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
            .font(BRUFont.labelSmall)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.bruInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .overlay(
                Rectangle()
                    .stroke(Color.bruInk, lineWidth: 1.5)
            )
    }
}

// MARK: - ProgramTemplateSection

fileprivate struct ProgramTemplateSection: View {

    let presets: [ProgramTemplatePreset]
    let onSelect: (ProgramTemplatePreset) -> Void

    var body: some View {
        VStack(spacing: 0) {
            BRUSectionHead(
                "Or start from a template",
                right: "\(presets.count) presets"
            )

            ForEach(Array(presets.enumerated()), id: \.element.id) { index, preset in
                ProgramTemplateRow(preset: preset) {
                    onSelect(preset)
                }
                if index < presets.count - 1 {
                    BRUDivider(.hair)
                }
            }

            BRUDivider(.ink)
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
                    .font(.system(size: 36, weight: .black).width(.compressed))
                    .foregroundStyle(Color.bruInk)
                    .frame(width: 56, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(preset.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.bruInk)
                        if preset.popular {
                            popularBadge
                        }
                        Spacer(minLength: 0)
                    }

                    Text(preset.cadence)
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruMuted)

                    Text(preset.phaseDescriptor)
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruMuted)
                }

                Text("›")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.bruMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.bruPaper)
    }

    private var popularBadge: some View {
        Text("Popular")
            .font(BRUFont.labelMicro)
            .tracking(1.0)
            .textCase(.uppercase)
            .foregroundStyle(Color.bruPaper)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.bruSignal)
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
