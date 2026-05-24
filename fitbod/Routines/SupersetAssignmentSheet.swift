//
//  SupersetAssignmentSheet.swift
//  fitbod
//
//  Phase 2.1 Plan 05 REWRITE — replaces NavigationStack .navigationTitle / .toolbar
//  with BRUHeaderBar("ADD TO SUPERSET") + BRU-styled rows.
//
//  Mutation surface: writes to RoutineExerciseDraft.supersetGroupID (in-memory draft).
//  The persisted write happens at Save time via RoutineDraft.save(into:).
//
//  Verbatim copy: "ADD TO SUPERSET" / "Cancel" — anchored in RoutineBuilderBRUCopyTests.
//
//  BRU contract: NO accentColor / NO Image(systemName:) / NO Capsule / NO RoundedRectangle
//  NO .navigationTitle / NO .toolbar / NO accentColor
//

import SwiftUI
import SwiftData

public struct SupersetAssignmentSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    public let routine: Routine
    public let exerciseDraft: RoutineExerciseDraft

    @Query private var groups: [SupersetGroup]

    public init(routine: Routine, exerciseDraft: RoutineExerciseDraft) {
        self.routine = routine
        self.exerciseDraft = exerciseDraft
        let routineID = routine.id
        self._groups = Query(
            filter: #Predicate<SupersetGroup> { $0.routineID == routineID },
            sort: \SupersetGroup.sortOrder
        )
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        // Existing superset groups
                        ForEach(groups) { group in
                            Button {
                                exerciseDraft.supersetGroupID = group.id
                                dismiss()
                            } label: {
                                HStack {
                                    Text(label(for: group))
                                        .font(BRUFont.bodyEmphasis)
                                        .foregroundStyle(Color.bruInk)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)

                            BRUDivider(.hair)
                        }

                        // "New Superset" signal action row
                        BRUButton("+ New superset", kind: .signal, size: .md) {
                            let newGroup = SupersetGroup(
                                routineID: routine.id,
                                kindRaw: SupersetKind.paired.rawValue,
                                sortOrder: groups.count
                            )
                            ctx.insert(newGroup)
                            try? ctx.save()
                            exerciseDraft.supersetGroupID = newGroup.id
                            dismiss()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .background(Color.bruPaper.ignoresSafeArea())
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                BRUHeaderBar(
                    left: HeaderAction("Cancel") { dismiss() },
                    center: "ADD TO SUPERSET",
                    right: nil
                )
            }
        }
    }

    /// UI-SPEC § Routine builder verbatim format:
    ///   "Superset A (Bench + Row)" / "Superset B (Squat + Curl)"
    private func label(for group: SupersetGroup) -> String {
        let letter = String(UnicodeScalar(UInt8(65 + min(group.sortOrder, 25))))
        let routineExercises = (routine.exercises ?? [])
            .filter { $0.supersetGroupID == group.id }
        let names = routineExercises
            .compactMap { $0.exercise?.name }
            .joined(separator: " + ")
        if names.isEmpty {
            return "Superset \(letter)"
        }
        return "Superset \(letter) (\(names))"
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SupersetAssignmentSheet — no groups") {
    // Preview requires a ModelContainer — use in-memory for safety
    let schema = Schema(SchemaV5.models)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    if let container = try? ModelContainer(
        for: schema,
        migrationPlan: FitbodSchemaMigrationPlan.self,
        configurations: config
    ) {
        let routine = Routine()
        container.mainContext.insert(routine)
        let draft = RoutineExerciseDraft()
        return AnyView(
            SupersetAssignmentSheet(routine: routine, exerciseDraft: draft)
                .modelContainer(container)
        )
    } else {
        return AnyView(Text("Preview unavailable").foregroundStyle(Color.bruMuted))
    }
}
#endif
