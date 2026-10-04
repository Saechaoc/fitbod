//
//  RoutineBuilderView.swift
//  fitbod
//
//  Create / edit a routine on one screen (Chalkline redesign of plan
//  03-02). Presented in a sheet wrapped in a NavigationStack.
//
//    - Name (prominent field).
//    - Ordered exercises: tap a card to expand its prescription steppers;
//      "Reorder" switches to drag handles; the card menu also moves items
//      up/down (no drag needed).
//    - "Add exercises" opens the library in multi-select; picks are
//      appended in the order they were tapped.
//    - Notes.
//
//  Validation: Save is always tappable. An invalid save reveals an error
//  summary at the top plus inline messages on the name field and the
//  exercise section, fires an error haptic and is announced to VoiceOver.
//  Errors clear as soon as they are fixed.
//
//  Persistence is the existing three-way merge in `RoutineDraft.save` —
//  sessions already started from this routine are snapshots and are never
//  rewritten by these edits.
//

import SwiftUI
import SwiftData
import UIKit

public struct RoutineBuilderView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Bindable public var draft: RoutineDraft

    /// nil = create mode; non-nil = edit mode (existing Routine).
    public let editing: Routine?

    @State private var expanded: Set<ObjectIdentifier> = []
    @State private var showErrors = false
    @State private var errorTick = 0
    @State private var editMode: EditMode = .inactive
    @State private var presentingPicker = false
    @State private var presentingDiscardConfirm = false
    @State private var initialSnapshot = ""
    @State private var pendingSupersetAssignment: RoutineExerciseDraft?
    @State private var presentingSaveFirstAlert = false
    @State private var pendingWarmupSheet: RoutineExerciseDraft?

    public init(draft: RoutineDraft, editing: Routine? = nil) {
        self.draft = draft
        self.editing = editing
    }

    public var body: some View {
        List {
            if showErrors, let summary = draft.issueSummary {
                Section {
                    ChalkInlineMessage(summary, kind: .error)
                        .accessibilityIdentifier("builder.errorSummary")
                }
                .chalkBareListRow()
            }

            Section {
                ChalkTextField(
                    "Routine name",
                    text: $draft.name,
                    prompt: "e.g. Push Day A",
                    error: showErrors && draft.issues.contains(.missingName) ? RoutineDraft.Issue.missingName.message : nil,
                    isProminent: true,
                    identifier: "builder.name"
                )
            }
            .chalkBareListRow()

            Section {
                if draft.exercises.isEmpty {
                    Text("Add exercises in the order you'll do them. You can reorder later.")
                        .font(.chalkCallout)
                        .foregroundStyle(.chalkInk2)
                        .listRowBackground(Color.chalkSurface)
                } else if editMode == .active {
                    ForEach(Array(draft.exercises.enumerated()), id: \.element.objectID) { index, exercise in
                        Text("\(index + 1) · \(exercise.exercise?.name ?? "Exercise")")
                            .font(.chalkHeadline)
                            .foregroundStyle(.chalkInk)
                            .listRowBackground(Color.chalkSurface)
                    }
                    .onMove { source, destination in
                        draft.exercises.move(fromOffsets: source, toOffset: destination)
                        draft.renumber()
                    }
                } else {
                    ForEach(Array(draft.exercises.enumerated()), id: \.element.objectID) { index, exercise in
                        RoutineExerciseCard(
                            draft: exercise,
                            index: index,
                            count: draft.exercises.count,
                            isExpanded: expansionBinding(for: exercise),
                            onMoveUp: { draft.move(exercise, by: -1) },
                            onMoveDown: { draft.move(exercise, by: 1) },
                            onAssignSuperset: { handleAssignSuperset($0) },
                            onRemoveFromSuperset: { $0.supersetGroupID = nil },
                            onDuplicate: { duplicateExercise($0) },
                            onRemove: { removeExercise($0) },
                            onEditWarmup: { pendingWarmupSheet = $0 }
                        )
                        .listRowBackground(Color.chalkSurface)
                    }
                }

                Button {
                    presentingPicker = true
                } label: {
                    Label("Add exercises", systemImage: "plus")
                }
                .buttonStyle(.chalk(.secondary, fullWidth: true))
                .chalkBareListRow()
                .accessibilityIdentifier("builder.addExercises")

                if showErrors && draft.issues.contains(.noExercises) {
                    ChalkValidationText(RoutineDraft.Issue.noExercises.message)
                        .chalkBareListRow()
                        .accessibilityIdentifier("builder.exercisesError")
                }
            } header: {
                HStack {
                    Text(exerciseHeader)
                    Spacer()
                    if draft.exercises.count > 1 {
                        Button(reorderTitle) {
                            withAnimation {
                                editMode = editMode == .active ? .inactive : .active
                            }
                        }
                        .font(.chalkChip)
                        .foregroundStyle(.chalkAccentInk)
                        .frame(minHeight: Chalk.Size.minTouch)
                        .accessibilityIdentifier("builder.reorder")
                    }
                }
                .chalkLabelStyle()
            }

            Section {
                TextField(
                    "Notes (optional)",
                    text: Binding(
                        get: { draft.notes ?? "" },
                        set: { draft.notes = $0.isEmpty ? nil : $0 }
                    ),
                    prompt: Text("Cues, warm-up, equipment").foregroundStyle(Color.chalkInk3),
                    axis: .vertical
                )
                .lineLimit(2...6)
                .font(.chalkBody)
                .listRowBackground(Color.chalkSurface)
            } header: {
                Text("Notes").chalkLabelStyle()
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, $editMode)
        .chalkCanvasBackground()
        .navigationTitle(screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if hasUnsavedChanges {
                        presentingDiscardConfirm = true
                    } else {
                        dismiss()
                    }
                }
                .accessibilityIdentifier("builder.cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.heavy)
                    .accessibilityIdentifier("builder.save")
            }
        }
        .sensoryFeedback(.error, trigger: errorTick)
        .onChange(of: draft.issues) { _, issues in
            if issues.isEmpty { showErrors = false }
        }
        .confirmationDialog("Discard changes?", isPresented: $presentingDiscardConfirm, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .sheet(isPresented: $presentingPicker) {
            ExercisePickerSheet(title: "Add exercises", allowsMultipleSelection: true) { exercises in
                let firstNew = draft.exercises.count
                for exercise in exercises {
                    draft.append(exercise: exercise)
                }
                if draft.exercises.indices.contains(firstNew) {
                    expanded.insert(draft.exercises[firstNew].objectID)
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { pendingSupersetAssignment != nil },
                set: { if !$0 { pendingSupersetAssignment = nil } }
            )
        ) {
            if let editing, let exDraft = pendingSupersetAssignment {
                SupersetAssignmentSheet(routine: editing, exerciseDraft: exDraft)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { pendingWarmupSheet != nil },
                set: { if !$0 { pendingWarmupSheet = nil } }
            )
        ) {
            if let exDraft = pendingWarmupSheet {
                @Bindable var bound = exDraft
                WarmupConfigSheet(config: $bound.warmupOverride)
                    .presentationDetents([.medium])
            }
        }
        .alert("Save routine first", isPresented: $presentingSaveFirstAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Save the routine once before grouping exercises into a superset.")
        }
        .onAppear {
            if initialSnapshot.isEmpty {
                initialSnapshot = snapshotHash()
            }
        }
    }

    // MARK: Derived

    private var screenTitle: String {
        editing == nil ? "NEW ROUTINE" : "EDIT ROUTINE"
    }

    private var reorderTitle: String {
        editMode == .active ? "Done" : "Reorder"
    }

    private var exerciseHeader: String {
        let count = draft.exercises.count
        let sets = draft.exercises.reduce(0) { $0 + $1.targetSets }
        if count == 0 { return "Exercises" }
        return "Exercises · \(count) · \(sets) sets"
    }

    private func expansionBinding(for exercise: RoutineExerciseDraft) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(exercise.objectID) },
            set: { isOpen in
                if isOpen {
                    expanded.insert(exercise.objectID)
                } else {
                    expanded.remove(exercise.objectID)
                }
            }
        )
    }

    private var hasUnsavedChanges: Bool {
        snapshotHash() != initialSnapshot
    }

    /// Cheap fingerprint for the dirty check.
    private func snapshotHash() -> String {
        let sets = draft.exercises.map { "\($0.exercise?.id.uuidString ?? "-"):\($0.targetSets):\($0.targetRepsLow)-\($0.targetRepsHigh):\($0.prescribedRestSeconds)" }
        return "\(draft.name)|\(draft.notes ?? "")|\(sets.joined(separator: ","))"
    }

    // MARK: Save

    private func save() {
        guard draft.isValid else {
            showErrors = true
            errorTick += 1
            if let summary = draft.issueSummary {
                UIAccessibility.post(notification: .announcement, argument: summary)
            }
            return
        }
        let routine: Routine
        if let editing {
            routine = editing
        } else {
            routine = Routine()
            ctx.insert(routine)
        }
        draft.save(into: routine, context: ctx)
        try? ctx.save()
        dismiss()
    }

    // MARK: Menu handlers

    /// Superset groups anchor on a persisted routine, so create mode asks
    /// the user to save first.
    private func handleAssignSuperset(_ exDraft: RoutineExerciseDraft) {
        if editing == nil {
            presentingSaveFirstAlert = true
            return
        }
        pendingSupersetAssignment = exDraft
    }

    /// Inserts a copy right after the original (not persisted until Save).
    private func duplicateExercise(_ exDraft: RoutineExerciseDraft) {
        guard let index = draft.exercises.firstIndex(where: { $0 === exDraft }) else { return }
        let clone = RoutineExerciseDraft()
        clone.exercise = exDraft.exercise
        clone.intent = exDraft.intent
        clone.targetSets = exDraft.targetSets
        clone.targetRepsLow = exDraft.targetRepsLow
        clone.targetRepsHigh = exDraft.targetRepsHigh
        clone.targetRPE = exDraft.targetRPE
        clone.prescribedRestSeconds = exDraft.prescribedRestSeconds
        clone.progressionKind = exDraft.progressionKind
        clone.tempo = exDraft.tempo
        clone.tracksTempo = exDraft.tracksTempo
        clone.tracksPartialReps = exDraft.tracksPartialReps
        clone.supersetGroupID = nil
        draft.exercises.insert(clone, at: index + 1)
        draft.renumber()
    }

    private func removeExercise(_ exDraft: RoutineExerciseDraft) {
        expanded.remove(exDraft.objectID)
        draft.exercises.removeAll { $0 === exDraft }
        draft.renumber()
    }
}
