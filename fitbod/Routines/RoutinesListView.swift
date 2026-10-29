//
//  RoutinesListView.swift
//  fitbod
//
//  Phase 2.1 Plan 06 — BRU visual rewrite of the Routines tab list.
//  UI-SPEC v2 § RoutinesListView (lines 302-322) + § Surfaces (lines 544-549).
//
//  ## Composition
//
//  NavigationStack with .navigationBarHidden(true) + .safeAreaInset(edge: .top)
//  mounting BRUHeaderBar(left: nil, center: "Routines", right: HeaderAction("+ NEW")).
//  The BRUHeaderBar right action opens a SwiftUI Menu (system styling acceptable
//  per UI-SPEC line 261 — Apple's chrome cannot be fully restyled).
//
//  Body is a ScrollView > LazyVStack(pinnedViews: [.sectionHeaders]) grouping
//  routines by RoutineFolder. Each group renders BRUSectionHead(folder name
//  UPPERCASED) as the pinned section header, followed by RoutineRow items
//  separated by BRUDivider(.hair). "Unfiled" section (folderID == nil) renders
//  FIRST when any unfiled routines exist (per existing Phase 2 convention).
//
//  ## Preserved Behaviors (Phase 2 — soft-ref invariants + active-session guard)
//
//  - Soft-ref folder design: `Routine.folderID` is UUID? (NOT a SwiftData
//    relationship). `handleFolderDelete(_:)` re-maps routines to nil BEFORE
//    deleting the folder — preventing cascade-delete of routines.
//  - Deleting a Routine query-and-deletes orphan `SupersetGroup` rows (soft
//    UUID ref) before `ctx.delete(routine)`.
//  - Active-session conflict guard: `handleStartTap(routine:)` gates on
//    `activeSessions` @Query and surfaces the UI-SPEC "Workout in Progress"
//    alert (RESEARCH §6 Pitfall 7).
//
//  ## State Vars Preserved
//
//  @State: presentingNewFolder, presentingMoveSheet, presentingNewRoutine,
//          editingRoutine, conflictRoutine, deleteConfirmFolder,
//          pendingBlockBuilder, pendingBlockDelete, navigationPath, searchText,
//          presentingNewMenu
//

import SwiftUI
import SwiftData

/// Routines tab body — BRU brutalist composition replacing navigationTitle+List.
///
/// Grouped by `RoutineFolder` with a BRUHeaderBar "+ NEW" right action opening
/// a Menu for creating new routines / folders. Preserves all Phase 2 swipe,
/// context-menu, active-session-conflict, and soft-ref delete behaviors.
public struct RoutinesListView: View {
    @Environment(\.modelContext) private var ctx

    @Query(sort: \RoutineFolder.sortOrder)
    private var folders: [RoutineFolder]

    @Query(sort: [SortDescriptor(\SessionTemplate.name)])
    private var routines: [SessionTemplate]

    @Query(sort: [SortDescriptor(\Block.startDate, order: .reverse)])
    private var blocks: [Block]

    @Query(filter: #Predicate<Session> { $0.completedAt == nil })
    private var activeSessions: [Session]

    @State private var presentingNewFolder = false
    @State private var presentingMoveSheet: SessionTemplate? = nil
    @State private var presentingNewRoutine = false
    @State private var editingRoutine: SessionTemplate? = nil
    @State private var conflictRoutine: SessionTemplate? = nil
    @State private var deleteConfirmFolder: RoutineFolder? = nil
    @State private var pendingBlockBuilder: PendingBlockBuilder? = nil
    @State private var pendingBlockDelete: Block? = nil
    @State private var navigationPath = NavigationPath()
    @State private var searchText = ""
    @State private var presentingNewMenu = false
    // Plan 02.1-10: v1 History surface — presented as a sheet from the Routines tab
    @State private var presentingSessionHistory = false

    public init() {}

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    // Resume-workout banner at top
                    ResumeWorkoutBanner(
                        onResume: { session in
                            navigationPath.append(SessionRoute.logger(session))
                        },
                        onDiscard: { session in
                            ctx.delete(session)
                            try? ctx.save()
                        }
                    )

                    // Blocks section
                    bruBlocksSection

                    // Routines sections or empty state
                    if filteredSectionsForRendering.allSatisfy({ $0.routines.isEmpty }) &&
                       routines.filter({ matchesSearch($0) }).isEmpty {
                        bruEmptyState
                    } else {
                        ForEach(filteredSectionsForRendering, id: \.id) { section in
                            Section {
                                ForEach(section.routines) { routine in
                                    RoutineRow(
                                        routine: routine,
                                        onTap: { editingRoutine = $0 },
                                        onStart: { handleStartTap(routine: $0) },
                                        onDuplicate: { handleDuplicate(routine: $0) },
                                        onMove: { presentingMoveSheet = $0 },
                                        onDelete: { handleDelete(routine: $0) }
                                    )
                                    BRUDivider(.hair)
                                }
                            } header: {
                                BRUSectionHead(section.title.uppercased())
                            }
                        }
                    }
                }
            }
            .background(Color.bruPaper.ignoresSafeArea())
            .navigationBarHidden(true)
            .searchable(text: $searchText, prompt: "Search routines")
            .safeAreaInset(edge: .top) {
                BRUHeaderBar(
                    left: nil,
                    center: "Routines",
                    right: HeaderAction("+ NEW", isSignal: true, action: { presentingNewMenu = true })
                )
            }
            .confirmationDialog(
                "Add",
                isPresented: $presentingNewMenu,
                titleVisibility: .hidden
            ) {
                Button("New Routine") {
                    presentingNewRoutine = true
                }
                Button("New Folder") {
                    presentingNewFolder = true
                }
                // Plan 02.1-10: surface SessionHistoryView from the Routines tab
                Button("History") {
                    presentingSessionHistory = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .navigationDestination(for: SessionRoute.self) { route in
                switch route {
                case .logger(let session):
                    SessionLoggerView(session: session)
                }
            }
            .sheet(isPresented: $presentingNewFolder) {
                NewFolderSheet(draft: RoutineFolderDraft())
            }
            .sheet(item: $presentingMoveSheet) { routine in
                MoveRoutineSheet(routine: routine, folders: folders)
            }
            .sheet(isPresented: $presentingNewRoutine) {
                NavigationStack {
                    RoutineBuilderView(draft: RoutineDraft())
                }
            }
            .sheet(item: $editingRoutine) { routine in
                NavigationStack {
                    RoutineBuilderView(
                        draft: RoutineDraft(routine: routine),
                        editing: routine
                    )
                }
            }
            .sheet(item: $pendingBlockBuilder) { pending in
                NavigationStack {
                    switch pending {
                    case .template(let template):
                        BlockBuilderView(draft: BlockDraft(template: template))
                    case .edit(let block):
                        BlockBuilderView(draft: BlockDraft(block: block), editing: block)
                    }
                }
            }
            // Plan 02.1-10: session history surface — v1 reachability via Routines "+" menu
            .sheet(isPresented: $presentingSessionHistory) {
                NavigationStack {
                    SessionHistoryView()
                        .sessionHistoryDestinations()
                }
            }
            // UI-SPEC verbatim: "Workout in Progress" active-session-conflict alert
            .alert(
                "Workout in Progress",
                isPresented: Binding(
                    get: { conflictRoutine != nil },
                    set: { if !$0 { conflictRoutine = nil } }
                )
            ) {
                Button("Resume Workout") {
                    conflictRoutine = nil
                }
                Button("Discard", role: .destructive) {
                    if let active = activeSessions.first {
                        ctx.delete(active)
                        try? ctx.save()
                    }
                    conflictRoutine = nil
                }
                Button("Cancel", role: .cancel) {
                    conflictRoutine = nil
                }
            } message: {
                Text("Finish or discard the current workout before starting a new one.")
            }
            .alert(
                "Delete block?",
                isPresented: Binding(
                    get: { pendingBlockDelete != nil },
                    set: { if !$0 { pendingBlockDelete = nil } }
                )
            ) {
                Button("Delete", role: .destructive) {
                    if let block = pendingBlockDelete {
                        ctx.delete(block)
                        try? ctx.save()
                    }
                    pendingBlockDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingBlockDelete = nil
                }
            } message: {
                Text("Linked routines stay; sessions logged under this block keep their snapshot context.")
            }
            .confirmationDialog(
                deleteConfirmFolder.map { "Delete \"\($0.name)\"?" } ?? "Delete?",
                isPresented: Binding(
                    get: { deleteConfirmFolder != nil },
                    set: { if !$0 { deleteConfirmFolder = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let folder = deleteConfirmFolder {
                        handleFolderDelete(folder)
                    }
                    deleteConfirmFolder = nil
                }
                Button("Cancel", role: .cancel) {
                    deleteConfirmFolder = nil
                }
            } message: {
                Text("The folder will be removed.")
            }
        }
    }

    // MARK: - Blocks section (BRU-styled, preserving block create/edit behaviors)
    // Phase 04.1 (BRU re-skin blocksSection + D-09 copy fix) — see 04.1-PATTERNS.md File #12

    @ViewBuilder
    private var bruBlocksSection: some View {
        VStack(spacing: 0) {
            // Section header: BRU-styled HStack (BRUSectionHead wiring deferred to Phase 2.1)
            HStack {
                Text("BLOCKS")
                    .font(BRUFont.labelSmall)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.bruInk)
                Spacer()
                Menu {
                    bruTemplateMenuItems
                } label: {
                    Text("+ BLOCK")
                        .font(BRUFont.labelSmall)
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(Color.bruSignalText)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            BRUDivider(.hair)

            if blocks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    // D-09 copy fix: "No blocks defined." replaces "No blocks yet."
                    Text("No blocks defined.")
                        .font(BRUFont.displayLarge)
                        .foregroundStyle(Color.bruInk)
                    // D-09 copy fix: updated body copy
                    Text("Create a training block to track mesocycles, phases, and scheduled deloads.")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                    // D-09: signal text CTA "+ NEW BLOCK" replaces "+ Block" with accentColor
                    Menu {
                        bruTemplateMenuItems
                    } label: {
                        Text("+ NEW BLOCK")
                            .font(BRUFont.labelSmall)
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(Color.bruSignalText)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                BRUDivider(.hair)
            } else {
                ForEach(BlockRow.sortedForDisplay(blocks)) { block in
                    BlockRow(
                        block: block,
                        onTap: { pendingBlockBuilder = .edit($0) },
                        onDelete: { pendingBlockDelete = $0 }
                    )
                    BRUDivider(.hair)
                }
            }
        }
    }

    @ViewBuilder
    private var bruTemplateMenuItems: some View {
        Button("Generic Strength Meso") {
            pendingBlockBuilder = .template(BlockTemplates.generic)
        }
        Button("Hypertrophy Meso") {
            pendingBlockBuilder = .template(BlockTemplates.hypertrophy)
        }
        Button("Powerlifting Peak") {
            pendingBlockBuilder = .template(BlockTemplates.powerliftingPeak)
        }
        Button("Blank Block") {
            pendingBlockBuilder = .template(BlockTemplates.blank)
        }
    }

    // MARK: - Empty state (UI-SPEC line 467, line 322)

    @ViewBuilder
    private var bruEmptyState: some View {
        VStack(spacing: 16) {
            BRUDisplay("No routines yet", size: .large)
            Text("Build a routine to start logging workouts.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .multilineTextAlignment(.center)
            BRUButton("+ NEW ROUTINE", kind: .signal, size: .md) {
                presentingNewRoutine = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 32)
    }

    // MARK: - Folder grouping logic

    /// Builds the sections from live @Query slices.
    ///
    /// Sort: "UNFILED" first (only when ≥1 unfiled routine), then user
    /// folders in `sortOrder` order (driven by @Query sort descriptor).
    private var sectionsForRendering: [RoutineSection] {
        let unfiled = routines.filter { $0.folderID == nil }
        let folderSections = folders.map { folder -> RoutineSection in
            let folderRoutines = routines.filter { $0.folderID == folder.id }
            return RoutineSection(
                id: folder.id,
                title: folder.name,
                routines: folderRoutines
            )
        }
        var out = [RoutineSection]()
        // UI-SPEC line 308: "UNFILED" section head for routines with no folder
        if !unfiled.isEmpty {
            out.append(
                RoutineSection(
                    id: Self.unfiledSectionID,
                    title: "UNFILED",
                    routines: unfiled
                )
            )
        }
        out.append(contentsOf: folderSections)
        return out
    }

    private var filteredSectionsForRendering: [RoutineSection] {
        sectionsForRendering.map { section in
            RoutineSection(
                id: section.id,
                title: section.title,
                routines: section.routines.filter { matchesSearch($0) }
            )
        }.filter { !$0.routines.isEmpty || searchText.isEmpty }
    }

    private func matchesSearch(_ routine: SessionTemplate) -> Bool {
        guard !searchText.isEmpty else { return true }
        return routine.name.localizedCaseInsensitiveContains(searchText)
    }

    /// Stable id for the "UNFILED" pseudo-section — pre-generated so
    /// SwiftUI's ForEach diffing doesn't see it as new every redraw.
    private static let unfiledSectionID = UUID()

    private struct RoutineSection: Identifiable {
        let id: UUID
        let title: String
        let routines: [SessionTemplate]
    }

    private enum PendingBlockBuilder: Identifiable {
        case template(BlockTemplate)
        case edit(Block)

        var id: String {
            switch self {
            case .template(let template):
                return "template-\(template.name)"
            case .edit(let block):
                return "edit-\(block.id.uuidString)"
            }
        }
    }

    // MARK: - Handlers

    /// "Start Workout" tap — enforces RESEARCH §6 Pitfall 7 (one active session at a time).
    private func handleStartTap(routine: SessionTemplate) {
        if !activeSessions.isEmpty {
            conflictRoutine = routine
            return
        }
        do {
            let session = try SessionFactory.start(template: routine, on: .now, context: ctx)
            navigationPath.append(SessionRoute.logger(session))
        } catch SessionFactoryError.activeSessionAlreadyExists {
            conflictRoutine = routine
        } catch SessionFactoryError.routineHasNoExercises {
            // Plan 03-02 wires the empty-routine error path.
        } catch {
            // Plan 04-01 polish: surface "Couldn't Start Workout".
        }
    }

    /// "Duplicate" action — deep-copies the SessionTemplate + SessionExerciseTemplate rows.
    private func handleDuplicate(routine: SessionTemplate) {
        RoutineDuplicator.duplicate(routine: routine, context: ctx)
    }

    /// "Delete" routine — query-and-deletes orphan SupersetGroup rows (soft
    /// UUID ref) BEFORE `ctx.delete(routine)` (ROUTINE-07 / PITFALLS-doc #1).
    private func handleDelete(routine: SessionTemplate) {
        let id = routine.id
        let supersetDescriptor = FetchDescriptor<SupersetGroup>(
            predicate: #Predicate { $0.routineID == id }
        )
        let supersets = (try? ctx.fetch(supersetDescriptor)) ?? []
        for sg in supersets {
            ctx.delete(sg)
        }
        ctx.delete(routine)
        try? ctx.save()
    }

    /// "Delete" folder — re-maps affected routines to nil (Unfiled) BEFORE
    /// deleting the folder (soft-ref invariant, CONTEXT.md Area 6).
    private func handleFolderDelete(_ folder: RoutineFolder) {
        let folderID = folder.id
        let affectedDescriptor = FetchDescriptor<SessionTemplate>(
            predicate: #Predicate { $0.folderID == folderID }
        )
        let affected = (try? ctx.fetch(affectedDescriptor)) ?? []
        for routine in affected {
            routine.folderID = nil
        }
        ctx.delete(folder)
        try? ctx.save()
    }
}

// MARK: - Session navigation route

/// Typed navigation route for the Routines tab's NavigationStack.
/// Plan 04-01 wired `.logger(session)` to `SessionLoggerView`.
public enum SessionRoute: Hashable {
    case logger(Session)
}

#Preview("empty state") {
    RoutinesListView()
        .modelContainer(PreviewModelContainer.make(seedFixture: false))
}

#Preview("populated") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let r1 = SessionTemplate()
    r1.name = "Push Day A"
    let r2 = SessionTemplate()
    r2.name = "Pull Day A"
    let folder = RoutineFolder(name: "Push / Pull / Legs")
    ctx.insert(folder)
    r2.folderID = folder.id
    ctx.insert(r1)
    ctx.insert(r2)
    try? ctx.save()
    return RoutinesListView()
        .modelContainer(container)
}
