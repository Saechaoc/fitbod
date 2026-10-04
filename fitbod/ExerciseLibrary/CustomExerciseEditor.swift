//
//  CustomExerciseEditor.swift
//  fitbod
//
//  Create / edit a custom exercise (Chalkline redesign of plan 03-04).
//
//    - Name (required) · Equipment chips · Mechanic · Muscles with stimulus
//      weights (≥ 1 primary at ≥ 50% — FOUND-07 / PITFALLS #5) · optional
//      photo.
//    - Save is always tappable. An invalid save shows a summary banner,
//      inline errors on the name and muscles, an error haptic and a
//      VoiceOver announcement; errors clear as they are fixed.
//    - Edit mode adds Delete, which explains what happens to history and
//      routines first (`ExerciseStore`).
//
//  The draft round-trips through `CustomExerciseDraft` (value-aware form
//  state, unit-tested without a container).
//

import SwiftUI
import SwiftData
import UIKit

struct CustomExerciseEditor: View {
    @Bindable var draft: CustomExerciseDraft
    /// When supplied (edit from the detail screen) the parent performs the
    /// delete after leaving the screen; otherwise the editor deletes.
    var onDelete: ((Exercise) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MuscleGroup.slug) private var allMuscles: [MuscleGroup]

    @State private var initialSnapshot: CustomExerciseDraft.Snapshot?
    @State private var presentingMusclePicker = false
    @State private var presentingCancelConfirmation = false
    @State private var presentingDeleteConfirmation = false
    @State private var showErrors = false
    @State private var errorTick = 0

    var body: some View {
        List {
            if showErrors, let summary = errorSummary {
                Section {
                    ChalkInlineMessage(summary, kind: .error)
                        .accessibilityIdentifier("custom.errorSummary")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                ChalkTextField(
                    "Name",
                    text: $draft.name,
                    prompt: "e.g. Zercher Good Morning",
                    error: showErrors && nameMissing ? "Name is required." : nil,
                    isProminent: true,
                    identifier: "custom.name"
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: Chalk.Space.sm)], spacing: Chalk.Space.sm) {
                    ForEach(Equipment.allCases, id: \.self) { equipment in
                        ChalkChip(ExerciseRow.equipmentName(equipment.rawValue), isSelected: draft.equipment == equipment) {
                            draft.equipment = equipment
                        }
                        .accessibilityIdentifier("custom.equipment.\(equipment.rawValue)")
                    }
                }
                .padding(.vertical, Chalk.Space.xs)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } header: {
                Text("Equipment").chalkLabelStyle()
            }

            Section {
                Picker("Mechanic", selection: $draft.mechanic) {
                    ForEach(Mechanic.allCases, id: \.self) { mechanic in
                        Text(mechanic.rawValue.capitalized).tag(mechanic)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } header: {
                Text("Mechanic").chalkLabelStyle()
            }

            Section {
                ForEach($draft.muscles) { $assignment in
                    MuscleWeightRow(
                        assignment: $assignment,
                        displayName: displayName(for: assignment.slug),
                        onDelete: { remove(assignment) }
                    )
                    .listRowBackground(Color.chalkSurface)
                }
                Button {
                    presentingMusclePicker = true
                } label: {
                    Label(addMuscleTitle, systemImage: "plus")
                }
                .buttonStyle(.chalk(.ghost, size: .compact))
                .listRowBackground(Color.chalkSurface)
                .accessibilityIdentifier("custom.addMuscle")
            } header: {
                Text("Muscles").chalkLabelStyle()
            } footer: {
                VStack(alignment: .leading, spacing: Chalk.Space.xs) {
                    Text("Stimulus weight sets how much one set counts toward that muscle's weekly volume: 100% primary, 50% assisting.")
                        .font(.chalkFootnote)
                        .foregroundStyle(.chalkInk2)
                    if showErrors, let muscleError {
                        ChalkValidationText(muscleError)
                            .accessibilityIdentifier("custom.muscleError")
                    }
                }
            }

            Section {
                CustomExerciseImagePicker(draft: draft)
                    .listRowBackground(Color.chalkSurface)
            } header: {
                Text("Photo (optional)").chalkLabelStyle()
            }

            if draft.editingExisting != nil {
                Section {
                    Button("Delete exercise", role: .destructive) {
                        presentingDeleteConfirmation = true
                    }
                    .buttonStyle(.chalk(.destructive, fullWidth: true))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .accessibilityIdentifier("custom.delete")
                }
            }
        }
        .listStyle(.insetGrouped)
        .chalkCanvasBackground()
        .navigationTitle(draft.editingExisting == nil ? "NEW EXERCISE" : "EDIT EXERCISE")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if isDirty {
                        presentingCancelConfirmation = true
                    } else {
                        dismiss()
                    }
                }
                .accessibilityIdentifier("custom.cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .fontWeight(.heavy)
                    .accessibilityIdentifier("custom.save")
            }
        }
        .sensoryFeedback(.error, trigger: errorTick)
        .sheet(isPresented: $presentingMusclePicker) {
            MusclePickerSheet { muscle in
                appendMuscle(muscle)
            }
        }
        .confirmationDialog("Discard changes?", isPresented: $presentingCancelConfirmation, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .alert("Delete \"\(draft.name)\"?", isPresented: $presentingDeleteConfirmation) {
            Button("Delete", role: .destructive, action: deleteCustom)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
        .onAppear {
            if initialSnapshot == nil {
                initialSnapshot = draft.snapshot()
            }
        }
    }

    // MARK: Validation

    private var nameMissing: Bool {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var muscleError: String? {
        if !draft.muscles.contains(where: { $0.role == .primary }) {
            return "Pick at least one primary muscle — it drives weekly volume."
        }
        if !draft.muscles.contains(where: { $0.role == .primary && $0.weight >= 0.5 }) {
            return "A primary muscle needs at least 50% stimulus."
        }
        return nil
    }

    private var errorSummary: String? {
        let count = (nameMissing ? 1 : 0) + (muscleError == nil ? 0 : 1)
        guard count > 0 else { return nil }
        return count == 1 ? "Fix 1 thing to save this exercise." : "Fix \(count) things to save this exercise."
    }

    // MARK: Derived

    private var addMuscleTitle: String {
        draft.muscles.contains(where: { $0.role == .primary }) ? "Add another muscle" : "Add primary muscle"
    }

    private var isDirty: Bool {
        guard let initial = initialSnapshot else { return false }
        return initial != draft.snapshot()
    }

    private var deleteMessage: String {
        guard let target = draft.editingExisting else { return "" }
        let usage = ExerciseStore.usage(of: target, context: modelContext)
        var parts: [String] = []
        if usage.loggedSessions > 0 {
            parts.append("\(usage.loggedSessions) logged workout\(usage.loggedSessions == 1 ? "" : "s") keep their sets but will show “Removed exercise”.")
        }
        if usage.routines > 0 {
            parts.append("It will be removed from \(usage.routines) routine\(usage.routines == 1 ? "" : "s").")
        }
        return parts.isEmpty ? "This can't be undone." : parts.joined(separator: " ")
    }

    private func displayName(for slug: String) -> String {
        allMuscles.first(where: { $0.slug == slug })?.displayName ?? MuscleRegionMap.displayName(for: slug)
    }

    // MARK: Mutations

    private func appendMuscle(_ muscle: MuscleGroup) {
        guard !draft.muscles.contains(where: { $0.slug == muscle.slug }) else { return }
        let hasPrimary = draft.muscles.contains { $0.role == .primary }
        let role: CustomExerciseDraft.MuscleAssignment.Role = hasPrimary ? .secondary : .primary
        draft.muscles.append(.init(slug: muscle.slug, role: role, weight: role == .primary ? 1.0 : 0.5))
    }

    private func remove(_ assignment: CustomExerciseDraft.MuscleAssignment) {
        draft.muscles.removeAll { $0.id == assignment.id }
    }

    private func save() {
        guard draft.isValid else {
            showErrors = true
            errorTick += 1
            if let errorSummary {
                UIAccessibility.post(notification: .announcement, argument: errorSummary)
            }
            return
        }
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if draft.editingExisting != nil {
            draft.updateExisting(in: modelContext, allMuscles: allMuscles)
        } else {
            draft.materialize(into: modelContext, allMuscles: allMuscles)
        }
        try? modelContext.save()
        dismiss()
    }

    private func deleteCustom() {
        guard let target = draft.editingExisting else { return }
        if let onDelete {
            onDelete(target)
        } else {
            ExerciseStore.delete(target, context: modelContext)
        }
        dismiss()
    }
}

#Preview("New exercise") {
    NavigationStack {
        CustomExerciseEditor(draft: CustomExerciseDraft())
    }
    .modelContainer(PreviewModelContainer.make())
}
