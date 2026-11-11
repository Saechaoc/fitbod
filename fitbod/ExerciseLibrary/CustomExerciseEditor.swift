//
//  CustomExerciseEditor.swift
//  fitbod
//
//  Wave-3 plan 03-04 — the user-facing surface that creates (and edits)
//  custom `Exercise` rows. The save button is the runtime gate that
//  enforces PITFALLS #5 (no exercise lacks ≥1 primary muscle with
//  weight ≥ 0.5) via `draft.isValid`.
//
//  ## Composition (review item 20)
//
//  A BRU screen built from bru-screens/custom-exercise.jsx, the custom
//  exercise screen in the Oct 2 snapshot under bru-screens/Fitbod-Session/,
//  with only the fields the editor has, in the design's order:
//
//  - `BRUHeaderBar`: CANCEL, "New exercise" or "Edit exercise", SAVE.
//  - NAME, in the condensed display font.
//  - CLASSIFICATION: Equipment and Tracks each open a BRU list, of every
//    `Equipment.allCases` and every `Tracking.allCases`; Mechanic is a
//    `BRUSegmentedControl`, left out for cardio. The design's PATTERN,
//    TEMPO, BAR WT and INCREMENT cells are left out, because an exercise
//    has no such fields.
//  - "Primary muscle stimulus" (REQUIRED, or OPTIONAL for cardio), then
//    "Secondary stimulus" and "+ ADD MUSCLE". Each muscle is a
//    `MuscleWeightRow`.
//  - The optional image, then "Delete exercise" when editing.
//  - A status footer, pinned below the scroll view: "VALID · 2 PRIMARY
//    MAPPED" and READY TO SAVE, or what is still missing and CAN'T SAVE
//    YET, by the draft's `isValid` rules.
//
//  ## Muscle order
//
//  Primary muscles always sit above secondary ones, and each section
//  lists its muscles by weight, heaviest first; ties keep the order the
//  muscles were added. A copy's muscles come from the store in no set
//  order, so the sections are what keep a bench press copy's Chest above
//  its Triceps and Shoulders. A role chip tap moves the muscle to the
//  other section.
//
//  ## First muscle vs later ones
//
//  `appendMuscle(_:)` checks whether the draft already contains a
//  primary muscle. If not, the new row is `role = .primary` with
//  `weight = 1.0`; otherwise `role = .secondary` with `weight = 0.5`.
//  A muscle that is already mapped is not added twice. "+ ADD MUSCLE"
//  reads "Add Primary Muscle" or "Add Another Muscle" to VoiceOver, so
//  the spoken label says which role the next muscle gets.
//
//  ## Header actions
//
//  - CANCEL dismisses at once if !isDirty, else presents the "Discard
//    Changes?" dialog. A swipe-down is blocked while the draft is dirty.
//  - SAVE stays tappable; on an invalid draft it shows the inline errors
//    ("Enter an exercise name." and the primary muscle error) instead of
//    saving. It reads in signal orange once the draft can be saved.
//
//  ## Discard / Delete confirmations (UI-SPEC verbatim)
//
//  - "Discard Changes?" `.confirmationDialog` — "Discard" (destructive)
//    + "Keep editing" (a plain button, because iOS 26 hides a cancel-role
//    one). Only presented when the snapshot diff says the draft is dirty.
//  - "Delete \"{name}\"?" `.alert` — "Delete" (destructive) + "Cancel".
//    Message: "Logged session history for this exercise will be
//    preserved." (the cascade rule from
//    `CascadeRuleTests/exerciseToSessionExerciseNullifies`).
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

/// BRU authoring surface for a custom exercise.
///
/// Bind the editor to a fresh `CustomExerciseDraft()` for "New
/// Exercise" mode, or to a draft with `editingExisting` set to the
/// existing custom `Exercise` for "Edit Exercise" mode. The editor
/// expects to live inside a `NavigationStack`, whose bar it hides for
/// its own `BRUHeaderBar`.
struct CustomExerciseEditor: View {
    @Bindable var draft: CustomExerciseDraft

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Query(sort: \MuscleGroup.slug) private var allMuscles: [MuscleGroup]

    @State private var initialSnapshot: CustomExerciseDraft.Snapshot? = nil
    @State private var presentingMusclePicker = false
    @State private var presentingEquipmentPicker = false
    @State private var presentingTrackingPicker = false
    @State private var presentingCancelConfirmation = false
    @State private var presentingDeleteConfirmation = false
    @State private var persistenceError: String?
    @State private var showingValidation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                nameSection
                classificationSection
                primarySection
                secondarySection
                imageSection
                if isEditing {
                    deleteSection
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top, spacing: 0) {
            BRUHeaderBar(
                left: HeaderAction("Cancel", action: cancel),
                center: title,
                right: HeaderAction("Save", isSignal: draft.isValid, action: save)
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            statusFooter
        }
        .alert("Changes were not saved", isPresented: Binding(
            get: { persistenceError != nil },
            set: { if !$0 { persistenceError = nil } }
        )) {
            Button("OK", role: .cancel) { persistenceError = nil }
        } message: {
            Text(persistenceError ?? "Please try again.")
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
            // iOS 26 hides a cancel-role button, so the way back is a plain one.
            Button("Keep editing") {}
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
        // A swipe would skip the discard dialog that Cancel shows.
        .interactiveDismissDisabled(isDirty)
    }

    // MARK: - Sections

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Name")
            TextField(
                text: $draft.name,
                prompt: Text("e.g. Cambered Bar Bench Press").foregroundStyle(Color.bruMuted)
            ) {
                Text("Name")
            }
            .font(BRUFont.condensedHeading)
            // A long name, such as a copy's "... (Copy)", shrinks to fit the
            // line rather than ending in "…".
            .minimumScaleFactor(0.5)
            .foregroundStyle(Color.bruInk)
            .tint(Color.bruInk)
            .textInputAutocapitalization(.words)
            .frame(minHeight: BRUMetrics.touchTarget)
            .accessibilityIdentifier("customExercise.name")
            if showingValidation && isNameMissing {
                Text("Enter an exercise name.")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruSignalText)
                    .accessibilityIdentifier("customExercise.nameError")
            }
        }
        .padding(.horizontal, BRUMetrics.Spacing.gutter)
        .padding(.vertical, 14)
    }

    private var classificationSection: some View {
        VStack(spacing: 0) {
            BRUSectionHead("Classification")
            listCell(
                "Equipment", value: draft.equipment.displayName,
                hint: "Opens the equipment list", identifier: "customExercise.equipment"
            ) {
                presentingEquipmentPicker = true
            }
            .sheet(isPresented: $presentingEquipmentPicker) {
                ChoicePickerSheet(
                    title: "Equipment", options: Equipment.allCases, selection: $draft.equipment,
                    name: \.displayName, identifier: { "customExercise.equipment.\($0.rawValue)" }
                )
            }

            BRUDivider(.hair)

            // What a set records. It follows the equipment until it is picked.
            listCell(
                "Tracks", value: draft.effectiveTracking.displayName,
                hint: "Opens the list of what a set records", identifier: "customExercise.tracking"
            ) {
                presentingTrackingPicker = true
            }
            .sheet(isPresented: $presentingTrackingPicker) {
                ChoicePickerSheet(
                    title: "Tracks", options: Tracking.allCases,
                    selection: Binding(get: { draft.effectiveTracking }, set: { draft.tracking = $0 }),
                    name: \.displayName, identifier: { "customExercise.tracking.\($0.rawValue)" }
                )
            }

            // Cardio is neither compound nor isolation.
            if !draft.isCardio {
                BRUDivider(.hair)
                mechanicCell
            }
        }
    }

    /// A classification cell that opens a list: its label, the current
    /// choice and a chevron.
    private func listCell(
        _ label: String, value: String, hint: String, identifier: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: BRUMetrics.Spacing.group) {
                VStack(alignment: .leading, spacing: 2) {
                    fieldLabel(label)
                    Text(value)
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruInk)
                }
                Spacer(minLength: BRUMetrics.Spacing.related)
                Text("›")
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruMuted)
            }
            .padding(.horizontal, BRUMetrics.Spacing.gutter)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: BRUMetrics.touchTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bruRow)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityHint(hint)
        .accessibilityIdentifier(identifier)
    }

    /// MECHANIC beside its control when the row fits, else above it. At the
    /// largest text sizes the control stops growing at AX2 when its full
    /// size would run past the screen, as it does on a 390pt phone at AX3.
    private var mechanicCell: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: BRUMetrics.Spacing.group) {
                fieldLabel("Mechanic")
                Spacer(minLength: 0)
                mechanicControl
            }
            VStack(alignment: .leading, spacing: BRUMetrics.Spacing.related) {
                fieldLabel("Mechanic")
                ViewThatFits(in: .horizontal) {
                    mechanicControl
                    mechanicControl
                        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, BRUMetrics.Spacing.gutter)
        .padding(.vertical, 10)
    }

    private var mechanicControl: some View {
        BRUSegmentedControl(
            "Mechanic",
            options: Mechanic.allCases,
            selection: $draft.mechanic
        ) { $0.rawValue.capitalized }
    }

    private var primarySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            BRUSectionHead("Primary muscle stimulus", right: draft.isCardio ? "Optional" : "Required")
            VStack(alignment: .leading, spacing: 0) {
                let primaries = assignments(for: .primary)
                if primaries.isEmpty {
                    Text(draft.isCardio
                         ? "Cardio needs no muscle. Without one it adds no muscle volume."
                         : "No primary muscle yet. The next muscle you add is primary.")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                        .padding(.vertical, BRUMetrics.Spacing.group)
                }
                muscleRows(primaries)
                if showingValidation, let problem = primaryProblem {
                    Text(problem)
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruSignalText)
                        .padding(.vertical, BRUMetrics.Spacing.related)
                }
            }
            .padding(.horizontal, BRUMetrics.Spacing.gutter)
            .padding(.vertical, BRUMetrics.Spacing.tight)
        }
    }

    private var secondarySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            BRUSectionHead("Secondary stimulus")
            VStack(alignment: .leading, spacing: 0) {
                muscleRows(assignments(for: .secondary))
                BRUDashedSlot(label: "Add muscle") {
                    presentingMusclePicker = true
                }
                .accessibilityLabel(addMuscleLabel)
                .accessibilityInputLabels(["Add muscle", addMuscleLabel])
                .padding(.vertical, BRUMetrics.Spacing.group)
            }
            .padding(.horizontal, BRUMetrics.Spacing.gutter)
            .padding(.top, BRUMetrics.Spacing.tight)
        }
    }

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            BRUSectionHead("Image", right: "Optional")
            CustomExerciseImagePicker(draft: draft)
                .padding(.horizontal, BRUMetrics.Spacing.gutter)
                .padding(.vertical, BRUMetrics.Spacing.group)
        }
    }

    private var deleteSection: some View {
        VStack(spacing: 0) {
            BRUDivider(.ink)
            BRUButton("Delete exercise", kind: .ghost) {
                presentingDeleteConfirmation = true
            }
            .padding(BRUMetrics.Spacing.gutter)
        }
    }

    /// The design's status strip: signal when the draft can be saved,
    /// amber while something is missing.
    private var statusFooter: some View {
        let status = self.status
        let fill = draft.isValid ? Color.bruSignal : Color.bruAmber
        return VStack(spacing: 0) {
            BRUDivider(.ink)
            statusLayout {
                Text(status.summary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(status.readiness)
            }
            .font(BRUFont.labelSmall)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.bruOnSignal)
            .padding(.horizontal, BRUMetrics.Spacing.gutter)
            .padding(.vertical, 10)
        }
        .background(fill.ignoresSafeArea(edges: .bottom))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(status.summary.replacingOccurrences(of: " · ", with: ", ")). \(status.readiness).")
        .accessibilityIdentifier("customExercise.status")
    }

    @ViewBuilder
    private func muscleRows(_ rows: [CustomExerciseDraft.MuscleAssignment]) -> some View {
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, assignment in
            if index > 0 {
                BRUDivider(.hair)
            }
            MuscleWeightRow(
                assignment: binding(for: assignment),
                displayName: displayName(for: assignment.slug),
                onDelete: { remove(assignment) }
            )
        }
    }

    /// A small muted uppercase field label, such as NAME or EQUIPMENT.
    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(BRUFont.labelSmall)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.bruMuted)
            .accessibilityHidden(true)
    }

    // MARK: - Derived

    private var isEditing: Bool { draft.editingExisting != nil }

    private var title: String {
        isEditing ? "Edit exercise" : "New exercise"
    }

    private var addMuscleLabel: String {
        hasPrimary ? "Add Another Muscle" : "Add Primary Muscle"
    }

    private var isDirty: Bool {
        guard let initial = initialSnapshot else { return false }
        return initial != draft.snapshot()
    }

    private var isNameMissing: Bool {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasPrimary: Bool {
        draft.muscles.contains { $0.role == .primary }
    }

    /// The `isValid` muscle rule: a primary muscle at 0.5 or more.
    private var hasQualifyingPrimary: Bool {
        draft.muscles.contains { $0.role == .primary && $0.weight >= 0.5 }
    }

    /// The inline muscle error a failed SAVE shows, or nil.
    private var primaryProblem: String? {
        if hasQualifyingPrimary || draft.isCardio { return nil }
        return hasPrimary
            ? "A primary muscle needs a weight of 0.5 or more to save."
            : "At least one primary muscle is required to save."
    }

    /// The footer's text, in normal case: whether the draft can be saved,
    /// and what is missing while it cannot.
    private var status: (summary: String, readiness: String) {
        guard !draft.isValid else {
            let primaries = draft.muscles.filter { $0.role == .primary }.count
            return (primaries == 0 ? "Valid · no muscle mapped" : "Valid · \(primaries) primary mapped", "Ready to save")
        }
        var missing: [String] = []
        if isNameMissing { missing.append("a name") }
        if !hasQualifyingPrimary && !draft.isCardio {
            missing.append(hasPrimary ? "a primary at 0.5 or more" : "a primary muscle")
        }
        return ("Needs " + missing.joined(separator: " and "), "Can't save yet")
    }

    /// One section's muscles, heaviest first; ties keep the order they
    /// were added.
    private func assignments(
        for role: CustomExerciseDraft.MuscleAssignment.Role
    ) -> [CustomExerciseDraft.MuscleAssignment] {
        draft.muscles.enumerated()
            .filter { $0.element.role == role }
            .sorted { lhs, rhs in
                lhs.element.weight == rhs.element.weight
                    ? lhs.offset < rhs.offset
                    : lhs.element.weight > rhs.element.weight
            }
            .map(\.element)
    }

    /// The row's binding into `draft.muscles`, found by id because the
    /// sections show the muscles in a different order.
    private func binding(
        for assignment: CustomExerciseDraft.MuscleAssignment
    ) -> Binding<CustomExerciseDraft.MuscleAssignment> {
        Binding(
            get: { draft.muscles.first { $0.id == assignment.id } ?? assignment },
            set: { updated in
                guard let index = draft.muscles.firstIndex(where: { $0.id == updated.id }) else { return }
                draft.muscles[index] = updated
            }
        )
    }

    private var statusLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: BRUMetrics.Spacing.tight))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: BRUMetrics.Spacing.group))
    }

    // MARK: - Helpers

    private func displayName(for slug: String) -> String {
        allMuscles.first(where: { $0.slug == slug })?.displayName
            ?? slug.capitalized
    }

    // MARK: - Mutations

    private func cancel() {
        if isDirty {
            presentingCancelConfirmation = true
        } else {
            dismiss()
        }
    }

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
        showingValidation = true
        guard draft.isValid else { return }
        do {
            try draft.persist(in: modelContext, allMuscles: allMuscles)
            dismiss()
        } catch {
            persistenceError = (error as? ExercisePhotoError)?.errorDescription
                ?? "Your changes could not be stored. They are still in this form; try saving again."
        }
    }

    private func deleteCustom() {
        guard let target = draft.editingExisting else { return }
        do {
            try ExerciseDeletion.delete(target, context: modelContext)
            dismiss()
        } catch {
            SessionSetActions.rollBack(modelContext)
            persistenceError = "The exercise could not be deleted. Try again."
        }
    }
}

// MARK: - Choice list

/// A classification cell's BRU list: one row per choice, the current one
/// marked. A tap picks it and closes the sheet; CANCEL keeps the current
/// one.
private struct ChoicePickerSheet<Value: Hashable>: View {
    let title: String
    let options: [Value]
    @Binding var selection: Value
    let name: (Value) -> String
    /// A row's accessibility identifier.
    let identifier: (Value) -> String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            BRUHeaderBar(
                left: HeaderAction("Cancel") { dismiss() },
                center: title
            )
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        row(option)
                    }
                }
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())
    }

    private func row(_ option: Value) -> some View {
        let isSelected = option == selection
        return Button {
            selection = option
            dismiss()
        } label: {
            HStack(spacing: BRUMetrics.Spacing.group) {
                // BRU radio: a filled signal square marks the current choice.
                Rectangle()
                    .fill(isSelected ? Color.bruSignal : Color.clear)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Rectangle().strokeBorder(isSelected ? Color.bruSignal : Color.bruInk, lineWidth: 2)
                    )
                Text(name(option))
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruInk)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, BRUMetrics.Spacing.gutter)
            .padding(.vertical, BRUMetrics.Spacing.related)
            .frame(minHeight: BRUMetrics.primaryActionHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { BRUDivider(.hair) }
        .accessibilityLabel(name(option))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier(option))
    }
}

#Preview("New Exercise") {
    NavigationStack {
        CustomExerciseEditor(draft: CustomExerciseDraft())
    }
    .modelContainer(PreviewModelContainer.make())
}
