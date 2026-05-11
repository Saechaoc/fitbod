//
//  CustomExerciseEditor.swift
//  fitbod
//
//  Wave-3 plan 03-04 — the user-facing surface that creates (and edits)
//  custom `Exercise` rows. The save button is the runtime gate that
//  enforces PITFALLS #5 (no exercise lacks ≥1 primary muscle with
//  weight ≥ 0.5) via `draft.isValid`.
//
//  ## Composition
//
//  - `Form` with five sections: Name / Muscles / Equipment / Mechanic /
//    Image (optional). When `draft.editingExisting != nil` (Edit
//    Exercise mode), a sixth Delete section is appended.
//  - Muscles section renders one `MuscleWeightRow` per assignment via
//    `ForEach($draft.muscles)` — the `$`-binding into the `@Observable`
//    array means edits propagate back to the draft directly.
//  - Footer text per UI-SPEC: "How much this exercise contributes to
//    weekly volume for that muscle. 100% for primary, 50% for
//    assisting muscles."
//  - Inline error text when `!draft.isValid`: "At least one primary
//    muscle is required to save." in `systemRed`.
//  - Equipment picker exposes all 9 `Equipment.allCases`; display
//    names split underscored raws ("weighted_bodyweight" → "Weighted
//    Bodyweight") matching plan 03-02 D-6 convention.
//  - Mechanic picker is `.segmented` ("Compound" / "Isolation") per
//    UI-SPEC § Custom exercise editor.
//
//  ## Toolbar
//
//  - Leading: "Cancel" — dismisses immediately if !isDirty, else
//    presents the "Discard Changes?" confirmation dialog.
//  - Trailing: "Save" — disabled when `!draft.isValid`;
//    `accessibilityHint = "Add a primary muscle to enable saving"` per
//    UI-SPEC § Accessibility.
//
//  ## Discard / Delete confirmations (UI-SPEC verbatim)
//
//  - "Discard Changes?" `.confirmationDialog` — "Discard" (destructive)
//    + "Keep Editing" (cancel). Only presented when the snapshot
//    diff says the draft is dirty.
//  - "Delete \"{name}\"?" `.alert` — "Delete" (destructive) + "Cancel".
//    Message: "Logged session history for this exercise will be
//    preserved." (Cosmetic in Phase 1 since no sessions exist yet —
//    but the wiring is in place for LIB-05 + the cascade-rule from
//    `CascadeRuleTests/exerciseToSessionExerciseNullifies`.)
//
//  ## First-muscle vs subsequent
//
//  `appendMuscle(_:)` checks whether the draft already contains a
//  primary muscle. If not, the new row is `role = .primary` with
//  `weight = 1.0` (button label = "Add Primary Muscle"). Otherwise
//  `role = .secondary` with `weight = 0.5` (button label = "Add
//  Another Muscle"). The user can override either via the segmented
//  role picker + slider in the row.
//
//  ## Save flow
//
//  Save tap → `draft.materialize(into:allMuscles:)` (New) or
//  `draft.updateExisting(in:allMuscles:)` (Edit) → `ctx.save()` →
//  `dismiss()`. The new row appears in `ExerciseLibraryView` via the
//  outer `@Query<Exercise>` re-running on `Exercise` changes.
//

import SwiftUI
import SwiftData

/// `Form`-based authoring surface for a custom exercise.
///
/// Bind the editor to a fresh `CustomExerciseDraft()` for "New
/// Exercise" mode, or to a draft with `editingExisting` set to the
/// existing custom `Exercise` for "Edit Exercise" mode. The editor
/// expects to live inside a `NavigationStack` (it owns its own
/// navigation title + toolbar).
struct CustomExerciseEditor: View {
    @Bindable var draft: CustomExerciseDraft

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \MuscleGroup.slug) private var allMuscles: [MuscleGroup]

    @State private var initialSnapshot: CustomExerciseDraft.Snapshot? = nil
    @State private var presentingMusclePicker = false
    @State private var presentingCancelConfirmation = false
    @State private var presentingDeleteConfirmation = false

    var body: some View {
        Form {
            nameSection
            musclesSection
            equipmentSection
            mechanicSection
            imageSection

            if isEditing {
                Section {
                    Button("Delete Exercise", role: .destructive) {
                        presentingDeleteConfirmation = true
                    }
                }
            }
        }
        .navigationTitle(navigationTitle)
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
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!draft.isValid)
                    .accessibilityHint(
                        draft.isValid
                            ? ""
                            : "Add a primary muscle to enable saving"
                    )
            }
        }
        .sheet(isPresented: $presentingMusclePicker) {
            MusclePickerSheet { mg in
                appendMuscle(mg)
            }
        }
        .confirmationDialog(
            "Discard Changes?",
            isPresented: $presentingCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        }
        .alert(
            "Delete \"\(draft.name)\"?",
            isPresented: $presentingDeleteConfirmation
        ) {
            Button("Delete", role: .destructive, action: deleteCustom)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Logged session history for this exercise will be preserved.")
        }
        .onAppear {
            if initialSnapshot == nil {
                initialSnapshot = draft.snapshot()
            }
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section("Name") {
            TextField("e.g. Cambered Bar Bench Press", text: $draft.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(false)
        }
    }

    private var musclesSection: some View {
        Section {
            ForEach($draft.muscles) { $assignment in
                MuscleWeightRow(
                    assignment: $assignment,
                    displayName: displayName(for: assignment.slug),
                    onDelete: { remove(assignment) }
                )
            }
            Button {
                presentingMusclePicker = true
            } label: {
                Label(addMuscleButtonLabel, systemImage: "plus")
                    .foregroundStyle(Color.accentColor)
            }
        } header: {
            Text("Muscles")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    "How much this exercise contributes to weekly volume for that muscle. 100% for primary, 50% for assisting muscles."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                if !draft.isValid && !draft.muscles.isEmpty {
                    Text("At least one primary muscle is required to save.")
                        .font(.caption)
                        .foregroundStyle(Color(.systemRed))
                }
            }
        }
    }

    private var equipmentSection: some View {
        Section("Equipment") {
            Picker("Equipment", selection: $draft.equipment) {
                ForEach(Equipment.allCases, id: \.self) { eq in
                    Text(equipmentDisplay(eq)).tag(eq)
                }
            }
        }
    }

    private var mechanicSection: some View {
        Section("Mechanic") {
            Picker("Mechanic", selection: $draft.mechanic) {
                ForEach(Mechanic.allCases, id: \.self) { mech in
                    Text(mech.rawValue.capitalized).tag(mech)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var imageSection: some View {
        Section("Image (optional)") {
            CustomExerciseImagePicker(draft: draft)
        }
    }

    // MARK: - Derived

    private var isEditing: Bool { draft.editingExisting != nil }

    private var navigationTitle: String {
        isEditing ? "Edit Exercise" : "New Exercise"
    }

    private var addMuscleButtonLabel: String {
        draft.muscles.contains(where: { $0.role == .primary })
            ? "Add Another Muscle"
            : "Add Primary Muscle"
    }

    private var isDirty: Bool {
        guard let initial = initialSnapshot else { return false }
        return initial != draft.snapshot()
    }

    // MARK: - Helpers

    private func displayName(for slug: String) -> String {
        allMuscles.first(where: { $0.slug == slug })?.displayName
            ?? slug.capitalized
    }

    /// Splits underscored Equipment raws to "Title Cased" form per
    /// plan 03-02 D-6 ("weighted_bodyweight" → "Weighted Bodyweight").
    /// Single-word raws (`barbell`, `cable`, etc.) are a no-op for
    /// the split.
    private func equipmentDisplay(_ eq: Equipment) -> String {
        eq.rawValue
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    // MARK: - Mutations

    private func appendMuscle(_ mg: MuscleGroup) {
        // No-op if this muscle is already mapped — prevents accidental
        // double-mapping that would silently double the volume.
        guard !draft.muscles.contains(where: { $0.slug == mg.slug }) else {
            return
        }
        let hasPrimary = draft.muscles.contains { $0.role == .primary }
        let role: CustomExerciseDraft.MuscleAssignment.Role =
            hasPrimary ? .secondary : .primary
        let weight: Double = role == .primary ? 1.0 : 0.5
        draft.muscles.append(
            .init(slug: mg.slug, role: role, weight: weight)
        )
    }

    private func remove(_ assignment: CustomExerciseDraft.MuscleAssignment) {
        draft.muscles.removeAll { $0.id == assignment.id }
    }

    private func save() {
        if isEditing {
            draft.updateExisting(in: modelContext, allMuscles: allMuscles)
        } else {
            draft.materialize(into: modelContext, allMuscles: allMuscles)
        }
        try? modelContext.save()
        dismiss()
    }

    private func deleteCustom() {
        guard let target = draft.editingExisting else { return }
        modelContext.delete(target)
        try? modelContext.save()
        dismiss()
    }
}

#Preview("New Exercise") {
    NavigationStack {
        CustomExerciseEditor(draft: CustomExerciseDraft())
    }
    .modelContainer(PreviewModelContainer.make())
}
