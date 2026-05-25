//
//  ProgramView.swift
//  fitbod
//
//  Quick task 260525-gen — BRU Program empty-state surface that replaces
//  the Routines tab body in the bottom nav.
//
//  Source of truth: bru-screens/Program/empty-state.png + empty-state.html
//
//  ## Composition
//
//  NavigationStack with .navigationBarHidden(true) + .safeAreaInset(edge: .top)
//  mounting BRUHeaderBar(center: "Program", right: HeaderAction("+ NEW", signal)).
//  Body is a ScrollView > LazyVStack with the following layered sections:
//
//    1. ResumeWorkoutBanner — only renders when an active Session exists
//       (carried over from RoutinesListView; reactive via its own @Query).
//    2. NoProgramHero — "ACTIVE BLOCK · NONE" caption, big "NO PROGRAM"
//       hero headline, explanatory body paragraph.
//    3. Coral CTA "+ DEFINE BLOCK ▶" — opens BlockBuilderView with a
//       blank template (same flow as the "Blank Block" path that lived
//       in RoutinesListView.bruTemplateMenuItems).
//    4. Feature chip row — WEEKS / PHASES / DELOAD / CUSTOM (outline chips).
//    5. ProgramTemplateSection — BRUSectionHead("OR START FROM A
//       TEMPLATE", right: "4 PRESETS") followed by 4 ProgramTemplateRow
//       items, each opening BlockBuilderView with the mapped
//       BlockTemplate from BlockTemplates.swift.
//
//  ## Scope decisions (260525-gen)
//
//  - Always renders the empty-state design regardless of existing Block
//    count. The "active block" populated state is a separate task.
//  - Drops the search bar, folder/routine list, "+ NEW" menu (New Routine
//    / New Folder / History), and the active-session conflict alert that
//    lived in RoutinesListView — none of those surfaces apply to a
//    Program empty state.
//  - Preserves ResumeWorkoutBanner so an in-progress workout stays
//    reachable from the Program tab.
//  - "+ NEW" right header action is wired to the same blank-block flow
//    as the main CTA (the mockup's "+ NEW" reads as "new program/block",
//    not a Routine-style "+ NEW" menu).
//
//  ## File location
//
//  fitbod/Periodization/ — co-located with Block*, MesocycleWeek*, and
//  PeriodizationEngine. The Program concept owns the Block model below
//  it; co-locating keeps the periodization surfaces together.
//
//  Xcode wiring: the project uses synchronized file system groups
//  (PBXFileSystemSynchronizedRootGroup, objectVersion 77), so this file
//  is picked up automatically with no pbxproj edit required.
//

import SwiftUI
import SwiftData

// MARK: - ProgramView

/// Program tab body — BRU brutalist empty-state surface for periodization.
///
/// Renders the "NO PROGRAM" composition from bru-screens/Program/empty-state.png:
/// hero headline, explanatory body, coral define-block CTA, feature
/// chips, and 4 template preset rows that route into BlockBuilderView.
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
                        defineAction: { startBlank() },
                        chips: ProgramView.featureChips
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
            .safeAreaInset(edge: .top) {
                BRUHeaderBar(
                    left: nil,
                    center: "Program",
                    right: HeaderAction("+ NEW", isSignal: true, action: { startBlank() })
                )
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

    // MARK: Actions

    private func startBlank() {
        pendingBlockBuilder = .template(BlockTemplates.blank)
    }

    // MARK: Static data

    fileprivate static let featureChips: [String] = [
        "Weeks · 4-12",
        "Phases · 1-4",
        "Deload optional",
        "Custom",
    ]

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

/// Display-side preset descriptor that maps a mockup row to an existing
/// BlockTemplate. The displayed `weeks`, `cadence`, and `phaseDescriptor`
/// strings come from the mockup; the underlying `template` is the closest
/// existing BlockTemplate in BlockTemplates.swift.
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

/// Hero block: "ACTIVE BLOCK · NONE" caption, big "NO PROGRAM" headline,
/// explanatory paragraph, coral CTA, and outline feature chips. Closes
/// with a 2pt bruInk divider so the next section starts crisply.
fileprivate struct NoProgramHero: View {

    let defineAction: () -> Void
    let chips: [String]

    var body: some View {
        VStack(spacing: 0) {
            BRUDivider(.ink)

            VStack(alignment: .leading, spacing: 16) {
                Text("Active block · None")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)

                BRUDisplay("NO PROGRAM", size: .hero)

                Text("A block schedules routines across weeks and phases — accumulation, intensification, peak, deload. You can also lift without a block, but Fitbod really earns its keep when you’re running one.")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 16)

            BRUButton("+ Define block ▸", kind: .signal, size: .lg, action: defineAction)
                .padding(.horizontal, 16)

            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    ProgramFeatureChip(label: chip)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)

            BRUDivider(.ink)
        }
    }
}

// MARK: - ProgramFeatureChip

/// Outline chip used in the hero "feature row" beneath the define CTA.
///
/// Thin wrapper over BRUChip — kept as a named primitive so the chip
/// styling for this row can evolve (e.g. swap to a tighter padding tier)
/// without touching the hero composition.
fileprivate struct ProgramFeatureChip: View {
    let label: String

    var body: some View {
        BRUChip(label)
    }
}

// MARK: - ProgramTemplateSection

/// "OR START FROM A TEMPLATE · 4 PRESETS" section: BRUSectionHead row
/// followed by the preset rows separated by hair dividers.
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

/// One preset row: large `weeks` label on the left, stacked
/// title+cadence+phase block in the middle (with optional POPULAR badge),
/// chevron on the right.
fileprivate struct ProgramTemplateRow: View {

    let preset: ProgramTemplatePreset
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                Text(preset.weeks)
                    .font(.custom("SpaceGrotesk-Bold", size: 24))
                    .foregroundStyle(Color.bruInk)
                    .frame(width: 40, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(preset.title)
                            .font(BRUFont.displayMedium)
                            .foregroundStyle(Color.bruInk)
                        if preset.popular {
                            BRUChip("Popular", color: .bruSignal, fill: true)
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
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruInk)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.bruPaper)
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
