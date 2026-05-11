//
//  RoutinesListView.swift
//  fitbod
//
//  Wave-3 plan 03-01 — the user-facing keystone of the Routines tab in
//  Phase 2. Replaces the `PlaceholderTabView(phaseNumber: 2)` placeholder
//  on the Routines tab in `RootView` with a sectioned `List` grouped by
//  `RoutineFolder`, a sticky `+` toolbar `Menu` (New Routine / New
//  Folder), per-row swipe + context-menu actions, and the empty state.
//
//  ## Sectioning
//
//  The list groups by `RoutineFolder`. The implicit "Unfiled" section
//  (routines with `folderID == nil`) renders FIRST and ONLY when at least
//  one such routine exists — empty folders do NOT render in Phase 2 (the
//  user-visible folder is only a header for routines below it). Folder
//  sections render in `sortOrder` order (driven by the `@Query` sort
//  descriptor).
//
//  ## Soft-ref invariants (CONTEXT.md Area 6)
//
//  `Routine.folderID` is a soft `UUID?` reference — NOT a SwiftData
//  `@Relationship`. This is load-bearing: deleting a `RoutineFolder` MUST
//  NOT cascade-delete its routines. `handleFolderDelete(_:)` enforces the
//  invariant by re-mapping `routine.folderID = nil` BEFORE deleting the
//  folder; affected routines then surface in the "Unfiled" section.
//
//  Similarly, deleting a `Routine` does NOT cascade-delete the soft-ref
//  `SupersetGroup` rows that reference it via `routineID`. The
//  `handleDelete(routine:)` handler query-and-deletes those groups
//  explicitly before deleting the routine, preventing orphan
//  `SupersetGroup` rows from accumulating in the store.
//
//  ## Active-session conflict guard (RESEARCH §6 Pitfall 7)
//
//  This view is the canonical "Start Workout" caller per plan 03-01's
//  pitfall mapping. `handleStartTap(routine:)` queries
//  `#Predicate<Session> { $0.completedAt == nil }` reactively (via the
//  `activeSessions` `@Query` property) AND defensively (via
//  `SessionFactoryError.activeSessionAlreadyExists` from
//  `SessionFactory.start`). Both paths surface the same UI-SPEC verbatim
//  alert ("Workout in Progress" / "Finish or discard the current workout
//  before starting a new one." / "Resume Workout" / "Discard" / "Cancel").
//
//  ## Stubbed navigation (plan 03-02 / 03-03 wires)
//
//  Two call sites are intentionally stubbed in plan 03-01:
//
//    - "New Routine" sheet body — interim placeholder text until plan
//      03-02 ships `RoutineBuilderView`.
//    - Row tap (edit mode) — no-op closure until plan 03-02 wires the
//      navigation destination.
//    - "Duplicate" menu item — no-op until plan 03-03 ships
//      `RoutineDuplicator.duplicate(routine:context:)`.
//
//  These stubs are documented as TODO comments at the call sites so the
//  consuming plans have unambiguous swap-in targets.
//

import SwiftUI
import SwiftData

/// Routines tab body — sectioned `List` grouped by `RoutineFolder` with a
/// "+" toolbar `Menu` for creating new routines / folders, swipe and
/// context-menu actions on each row, and a UI-SPEC verbatim empty state.
public struct RoutinesListView: View {
    @Environment(\.modelContext) private var ctx

    @Query(sort: \RoutineFolder.sortOrder)
    private var folders: [RoutineFolder]

    @Query(sort: [SortDescriptor(\Routine.name)])
    private var routines: [Routine]

    @Query(filter: #Predicate<Session> { $0.completedAt == nil })
    private var activeSessions: [Session]

    @State private var presentingNewFolder = false
    @State private var presentingMoveSheet: Routine? = nil
    @State private var presentingNewRoutine = false
    @State private var editingRoutine: Routine? = nil
    @State private var conflictRoutine: Routine? = nil
    @State private var deleteConfirmFolder: RoutineFolder? = nil

    public init() {}

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle("Routines")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("New Routine") {
                                presentingNewRoutine = true
                            }
                            Button("New Folder") {
                                presentingNewFolder = true
                            }
                        } label: {
                            Label("Add routine or folder", systemImage: "plus")
                                .labelStyle(.iconOnly)
                        }
                        .accessibilityLabel("Add routine or folder")
                    }
                }
                .sheet(isPresented: $presentingNewFolder) {
                    NewFolderSheet(draft: RoutineFolderDraft())
                }
                .sheet(item: $presentingMoveSheet) { routine in
                    MoveRoutineSheet(routine: routine, folders: folders)
                }
                .sheet(isPresented: $presentingNewRoutine) {
                    // Plan 03-02 wire — real RoutineBuilderView replaces
                    // the prior interim placeholder. A fresh
                    // `RoutineDraft()` is constructed per presentation so
                    // the sheet opens with empty fields each time.
                    NavigationStack {
                        RoutineBuilderView(draft: RoutineDraft())
                    }
                }
                .sheet(item: $editingRoutine) { routine in
                    // Plan 03-02 edit-mode wire — the row-tap closure on
                    // RoutineRow sets `editingRoutine = routine`, which
                    // presents the builder in edit mode (the builder
                    // round-trips the existing RoutineExercise + per-set
                    // override rows via `RoutineDraft(routine:)`).
                    NavigationStack {
                        RoutineBuilderView(
                            draft: RoutineDraft(routine: routine),
                            editing: routine
                        )
                    }
                }
                .alert(
                    "Workout in Progress",
                    isPresented: Binding(
                        get: { conflictRoutine != nil },
                        set: { if !$0 { conflictRoutine = nil } }
                    )
                ) {
                    Button("Resume Workout") {
                        // The visible resume banner mounted above the list
                        // owns the actual navigation to the session logger
                        // (plan 04-01). The alert just dismisses here.
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

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if routines.isEmpty && folders.isEmpty {
            emptyState
        } else {
            populatedList
        }
    }

    @ViewBuilder
    private var populatedList: some View {
        List {
            ResumeWorkoutBanner(
                onResume: { _ in
                    // TODO plan 04-01: navigate to SessionLoggerView via
                    // a Routines-tab NavigationPath.
                },
                onDiscard: { session in
                    ctx.delete(session)
                    try? ctx.save()
                }
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            ForEach(sectionsForRendering, id: \.id) { section in
                Section(section.title) {
                    if section.routines.isEmpty {
                        // Folder with no routines yet — show a faint
                        // placeholder row so the section header isn't
                        // visually orphaned.
                        Text("No routines in this folder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(section.routines) { routine in
                            RoutineRow(
                                routine: routine,
                                onTap: { editingRoutine = $0 },
                                onStart: { handleStartTap(routine: $0) },
                                onDuplicate: { handleDuplicate(routine: $0) },
                                onMove: { presentingMoveSheet = $0 },
                                onDelete: { handleDelete(routine: $0) }
                            )
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    /// Builds the rendering sections from the live `@Query` slices.
    /// "Unfiled" first (only when ≥1 unfiled routine), then user folders.
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
        if !unfiled.isEmpty {
            out.append(
                RoutineSection(
                    id: Self.unfiledSectionID,
                    title: "Unfiled",
                    routines: unfiled
                )
            )
        }
        out.append(contentsOf: folderSections)
        return out
    }

    /// Stable id for the "Unfiled" pseudo-section. Pre-generated once
    /// rather than `UUID()` on every `body` invocation so SwiftUI's
    /// `ForEach` diffing does not see the section as new every redraw.
    private static let unfiledSectionID = UUID()

    private struct RoutineSection: Identifiable {
        let id: UUID
        let title: String
        let routines: [Routine]
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 48)
            Text("No routines yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Build a routine to start logging workouts.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("New Routine") {
                presentingNewRoutine = true
            }
            .foregroundStyle(Color.accentColor)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Handlers

    /// "Start Workout" tap (from swipe action OR context menu).
    ///
    /// Enforces RESEARCH §6 Pitfall 7 — one active session at a time. If
    /// an active session exists, surface the UI-SPEC "Workout in Progress"
    /// alert and do NOT call `SessionFactory.start`. The factory itself
    /// guards defensively too, but the user-visible alert lives here.
    private func handleStartTap(routine: Routine) {
        if !activeSessions.isEmpty {
            conflictRoutine = routine
            return
        }
        do {
            _ = try SessionFactory.start(routine: routine, on: .now, context: ctx)
            // TODO plan 04-01: push SessionLoggerView via Routines-tab
            // NavigationPath. Plan 03-01 leaves the start-success path
            // visible only via the resume banner reactively re-rendering.
        } catch SessionFactoryError.activeSessionAlreadyExists {
            conflictRoutine = routine
        } catch SessionFactoryError.routineHasNoExercises {
            // Plan 03-02 wires the empty-routine error path (the user
            // can't currently build an empty routine from this view —
            // the row only exists if a routine already has rows).
        } catch {
            // Plan 04-01 polish: surface "Couldn't Start Workout".
        }
    }

    /// "Duplicate" action — STUB until plan 03-03 ships
    /// `RoutineDuplicator.duplicate(routine:context:)`. The closure exists
    /// so the menu wiring is end-to-end; the deep-copy logic plugs in
    /// later without touching this view.
    private func handleDuplicate(routine: Routine) {
        // TODO plan 03-03: RoutineDuplicator.duplicate(routine: routine, context: ctx)
        _ = routine
    }

    /// "Delete" action on a routine.
    ///
    /// Per ROUTINE-07 / PITFALLS-doc #1, deleting a Routine MUST NOT
    /// affect historical Sessions (Session.sourceRoutineID is a soft
    /// UUID ref). The SwiftData cascade on `Routine.exercises` deletes
    /// the owned `RoutineExercise` + `RoutineExerciseSetOverride` rows
    /// automatically. But `SupersetGroup` rows that reference this
    /// routine via the soft `routineID: UUID` ref must be explicitly
    /// query-and-deleted here so the store doesn't accumulate orphan
    /// groups.
    private func handleDelete(routine: Routine) {
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

    /// "Delete" action on a folder — confirmation is presented before
    /// reaching this handler.
    ///
    /// Soft-ref design (CONTEXT.md Area 6): deleting a folder MUST NOT
    /// cascade-delete its routines. Routines whose `folderID == folder.id`
    /// are re-mapped to `nil` (Unfiled) BEFORE the folder is deleted so
    /// the routines remain visible on the Routines tab. The order
    /// matters — if the folder were deleted first, the routines would
    /// still appear under their original folder.id until the user
    /// reopened the tab.
    private func handleFolderDelete(_ folder: RoutineFolder) {
        let folderID = folder.id
        let affectedDescriptor = FetchDescriptor<Routine>(
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

#Preview("empty state") {
    RoutinesListView()
        .modelContainer(PreviewModelContainer.make(seedFixture: false))
}

#Preview("populated") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let r1 = Routine()
    r1.name = "Push Day A"
    let r2 = Routine()
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
