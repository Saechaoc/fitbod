//
//  SupersetAssignmentSheet.swift
//  fitbod
//
//  Phase 2.1 Plan 05 REWRITE — replaces NavigationStack .navigationTitle / .toolbar
//  with BRUHeaderBar("ADD TO SUPERSET") + BRU-styled rows.
//
//  Mutation surface: writes to RoutineExerciseDraft.supersetGroupID (in-memory draft).
//  The persisted write happens at Save time via RoutineDraft.persist(into:context:).
//
//  Verbatim copy: "ADD TO SUPERSET" / "Cancel" — anchored in RoutineBuilderBRUCopyTests.
//
//  BRU contract: NO accentColor / NO Image(systemName:) / NO Capsule / NO RoundedRectangle
//  NO .navigationTitle / NO .toolbar / NO accentColor
//

import SwiftUI
import SwiftData

public struct SupersetAssignmentSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var draft: RoutineDraft
    public let exerciseDraft: RoutineExerciseDraft

    @Query private var groups: [SupersetGroup]

    public init(routine: SessionTemplate, draft: RoutineDraft, exerciseDraft: RoutineExerciseDraft) {
        self.draft = draft
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
                        ForEach(groups) { group in
                            groupRow(id: group.id, order: group.sortOrder)
                        }
                        ForEach(Array(draft.newSupersetIDs.enumerated()), id: \.element) { index, id in
                            groupRow(id: id, order: (groups.map(\.sortOrder).max() ?? -1) + 1 + index)
                        }

                        // "New Superset" signal action row
                        BRUButton("+ New superset", kind: .signal, size: .md) {
                            draft.addSuperset(for: exerciseDraft)
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

    private func groupRow(id: UUID, order: Int) -> some View {
        VStack(spacing: 0) {
            Button {
                exerciseDraft.supersetGroupID = id
                dismiss()
            } label: {
                HStack {
                    Text(label(for: id, order: order))
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruInk)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(minHeight: BRUMetrics.touchTarget)
            }
            .buttonStyle(.plain)
            BRUDivider(.hair)
        }
    }

    private func label(for id: UUID, order: Int) -> String {
        let letter = String(UnicodeScalar(UInt8(65 + min(max(order, 0), 25))))
        let names = draft.exercises
            .filter { $0.supersetGroupID == id }
            .compactMap { $0.exercise?.name }
            .joined(separator: " + ")
        return names.isEmpty ? "Superset \(letter)" : "Superset \(letter) (\(names))"
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SupersetAssignmentSheet — no groups") {
    // Preview requires a ModelContainer — use in-memory for safety
    if let container = try? FitbodModelContainer.make(inMemory: true) {
        let routine = SessionTemplate()
        container.mainContext.insert(routine)
        let draft = RoutineExerciseDraft()
        return AnyView(
            SupersetAssignmentSheet(routine: routine, draft: RoutineDraft(), exerciseDraft: draft)
                .modelContainer(container)
        )
    } else {
        return AnyView(Text("Preview unavailable").foregroundStyle(Color.bruMuted))
    }
}
#endif
