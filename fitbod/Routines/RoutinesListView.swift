//
//  RoutinesListView.swift
//  fitbod
//
//  Routines tab (Chalkline redesign of plan 03-01).
//
//    - "+" menu: New routine / New folder.
//    - An open workout shows as a compact iron "resume" card on top.
//    - Routines grouped by folder ("Unfiled" first). Each row: name, a
//      structured meta line (exercises · sets · last done), and a visible
//      START button — no hidden swipe needed to begin a workout.
//    - Row tap → routine detail. Swipe: Delete (confirmed) / Duplicate.
//      Long-press: Start, Edit, Duplicate, Move…, Delete.
//    - Empty: "No routines yet" with a primary New routine action.
//
//  Deleting a routine never touches history: sessions keep a soft
//  `sourceRoutineID` and a snapshot of the name (PITFALLS #1).
//

import SwiftUI
import SwiftData

public struct RoutinesListView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(AppRouter.self) private var router

    @Query(sort: \RoutineFolder.sortOrder) private var folders: [RoutineFolder]
    @Query(sort: [SortDescriptor(\Routine.name)]) private var routines: [Routine]
    @Query(filter: #Predicate<Session> { $0.completedAt == nil }) private var activeSessions: [Session]
    @Query(
        filter: #Predicate<Session> { $0.completedAt != nil },
        sort: \Session.startedAt,
        order: .reverse
    )
    private var finishedSessions: [Session]

    @State private var presentingNewFolder = false
    @State private var presentingNewRoutine = false
    @State private var editingRoutine: Routine?
    @State private var movingRoutine: Routine?
    @State private var deletingRoutine: Routine?
    @State private var deletingFolder: RoutineFolder?
    @State private var startFailure: WorkoutStartFailure?

    public init() {}

    public var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.routinesPath) {
            content
                .chalkCanvasBackground()
                .navigationTitle("ROUTINES")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                presentingNewRoutine = true
                            } label: {
                                Label("New routine", systemImage: "plus")
                            }
                            Button {
                                presentingNewFolder = true
                            } label: {
                                Label("New folder", systemImage: "folder.badge.plus")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add routine or folder")
                        .accessibilityIdentifier("routines.add")
                    }
                }
                .appRouteDestinations()
                .sheet(isPresented: $presentingNewFolder) {
                    NewFolderSheet(draft: RoutineFolderDraft())
                }
                .sheet(item: $movingRoutine) { routine in
                    MoveRoutineSheet(routine: routine, folders: folders)
                }
                .sheet(isPresented: $presentingNewRoutine) {
                    NavigationStack {
                        RoutineBuilderView(draft: RoutineDraft())
                    }
                }
                .sheet(item: $editingRoutine) { routine in
                    NavigationStack {
                        RoutineBuilderView(draft: RoutineDraft(routine: routine), editing: routine)
                    }
                }
                .workoutStartAlert($startFailure)
                .alert(
                    deleteRoutineTitle,
                    isPresented: Binding(
                        get: { deletingRoutine != nil },
                        set: { if !$0 { deletingRoutine = nil } }
                    ),
                    presenting: deletingRoutine
                ) { routine in
                    Button("Delete", role: .destructive) {
                        RoutineStore.delete(routine, context: ctx)
                        deletingRoutine = nil
                    }
                    Button("Cancel", role: .cancel) { deletingRoutine = nil }
                } message: { _ in
                    Text("Past workouts from this routine stay in History.")
                }
                .alert(
                    deleteFolderTitle,
                    isPresented: Binding(
                        get: { deletingFolder != nil },
                        set: { if !$0 { deletingFolder = nil } }
                    ),
                    presenting: deletingFolder
                ) { folder in
                    Button("Delete", role: .destructive) {
                        RoutineStore.delete(folder, context: ctx)
                        deletingFolder = nil
                    }
                    Button("Cancel", role: .cancel) { deletingFolder = nil }
                } message: { _ in
                    Text("The folder is removed. Its routines move to Unfiled.")
                }
                .onAppear(perform: consumePendingNewRoutine)
                .onChange(of: router.pendingNewRoutine) { _, _ in consumePendingNewRoutine() }
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if routines.isEmpty && folders.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: Chalk.Space.lg) {
                    resumeCard
                    ChalkEmptyState(
                        systemImage: "list.bullet.rectangle",
                        title: "No routines yet",
                        message: "A routine is your plan: exercises in order, with target sets, reps and rest. Build one, then start a workout from it in one tap.",
                        primaryTitle: "New routine",
                        primaryAction: { presentingNewRoutine = true }
                    )
                    .accessibilityIdentifier("routines.empty")
                }
                .padding(Chalk.Space.gutter)
            }
        } else {
            List {
                if !activeSessions.isEmpty {
                    Section {
                        resumeCard
                            .chalkBareListRow()
                    }
                }
                ForEach(sections) { section in
                    Section {
                        if section.routines.isEmpty {
                            Text("No routines in this folder yet.")
                                .font(.chalkFootnote)
                                .foregroundStyle(.chalkInk2)
                                .listRowBackground(Color.chalkSurface)
                        }
                        ForEach(section.routines) { routine in
                            RoutineRow(
                                routine: routine,
                                lastDone: lastDone(routine),
                                onOpen: { router.routinesPath.append(AppRoute.routine(routine)) },
                                onStart: { start(routine) }
                            )
                            .listRowBackground(Color.chalkSurface)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deletingRoutine = routine
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    RoutineDuplicator.duplicate(routine: routine, context: ctx)
                                } label: {
                                    Label("Duplicate", systemImage: "plus.square.on.square")
                                }
                                .tint(Color.chalkInk2)
                            }
                            .contextMenu {
                                Button {
                                    start(routine)
                                } label: {
                                    Label("Start workout", systemImage: "play.fill")
                                }
                                Button {
                                    editingRoutine = routine
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button {
                                    RoutineDuplicator.duplicate(routine: routine, context: ctx)
                                } label: {
                                    Label("Duplicate", systemImage: "plus.square.on.square")
                                }
                                Button {
                                    movingRoutine = routine
                                } label: {
                                    Label("Move…", systemImage: "folder")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    deletingRoutine = routine
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text(section.title)
                            Spacer()
                            if let folder = section.folder {
                                Menu {
                                    Button(role: .destructive) {
                                        deletingFolder = folder
                                    } label: {
                                        Label("Delete folder", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .frame(width: Chalk.Size.minTouch, height: 28)
                                }
                                .accessibilityLabel(Text("Options for folder \(folder.name)"))
                            }
                        }
                        .chalkLabelStyle()
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    @ViewBuilder
    private var resumeCard: some View {
        if let active = activeSessions.first {
            ChalkPanel(padding: Chalk.Space.md) {
                HStack(spacing: Chalk.Space.md) {
                    VStack(alignment: .leading, spacing: Chalk.Space.xxs) {
                        Text("Workout in progress").chalkLabelStyle(color: .chalkAccentOnPanel)
                        Text(active.routineSnapshotName.isEmpty ? "Workout" : active.routineSnapshotName)
                            .font(.chalkHeadline)
                            .foregroundStyle(.chalkOnPanel)
                    }
                    Spacer(minLength: Chalk.Space.sm)
                    Button("Resume") {
                        router.present(workout: active)
                    }
                    .buttonStyle(.chalk(.primary, size: .compact))
                    .accessibilityIdentifier("routines.resume")
                }
            }
        }
    }

    // MARK: Sections

    private struct RoutineSection: Identifiable {
        let id: String
        let title: String
        let folder: RoutineFolder?
        let routines: [Routine]
    }

    private var sections: [RoutineSection] {
        var result: [RoutineSection] = []
        let unfiled = routines.filter { routine in
            routine.folderID == nil || !folders.contains { $0.id == routine.folderID }
        }
        if !unfiled.isEmpty {
            result.append(RoutineSection(id: "unfiled", title: folders.isEmpty ? "All routines" : "Unfiled", folder: nil, routines: unfiled))
        }
        for folder in folders {
            result.append(RoutineSection(
                id: folder.id.uuidString,
                title: folder.name,
                folder: folder,
                routines: routines.filter { $0.folderID == folder.id }
            ))
        }
        return result
    }

    private var deleteRoutineTitle: String {
        "Delete \"\(deletingRoutine?.name ?? "routine")\"?"
    }

    private var deleteFolderTitle: String {
        "Delete folder \"\(deletingFolder?.name ?? "")\"?"
    }

    private func lastDone(_ routine: Routine) -> Date? {
        finishedSessions.first { $0.sourceRoutineID == routine.id }?.startedAt
    }

    // MARK: Actions

    private func start(_ routine: Routine) {
        startFailure = WorkoutLauncher.start(routine, context: ctx, router: router)
    }

    private func consumePendingNewRoutine() {
        if router.pendingNewRoutine {
            router.pendingNewRoutine = false
            presentingNewRoutine = true
        }
    }
}

/// Persistence helpers for routine/folder deletion (soft references are
/// cleaned up explicitly).
enum RoutineStore {
    /// Deletes a routine, its owned exercise rows (cascade) and the superset
    /// groups that soft-reference it. Sessions are untouched.
    static func delete(_ routine: Routine, context: ModelContext) {
        let id = routine.id
        let descriptor = FetchDescriptor<SupersetGroup>(predicate: #Predicate { $0.routineID == id })
        for group in (try? context.fetch(descriptor)) ?? [] {
            context.delete(group)
        }
        context.delete(routine)
        try? context.save()
    }

    /// Deletes a folder after moving its routines to Unfiled.
    static func delete(_ folder: RoutineFolder, context: ModelContext) {
        let folderID = folder.id
        let descriptor = FetchDescriptor<Routine>(predicate: #Predicate { $0.folderID == folderID })
        for routine in (try? context.fetch(descriptor)) ?? [] {
            routine.folderID = nil
        }
        context.delete(folder)
        try? context.save()
    }
}

#Preview("Routines — empty") {
    RoutinesListView()
        .environment(AppRouter())
        .modelContainer(PreviewModelContainer.make(seedFixture: false))
}
