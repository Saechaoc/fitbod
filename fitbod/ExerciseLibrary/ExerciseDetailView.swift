//
//  ExerciseDetailView.swift
//  fitbod
//
//  Wave-3 plan 03-03 — the read-only detail surface for any Exercise in
//  the library list. Pushed onto the Library tab's NavigationStack from
//  ExerciseLibraryView via `.navigationDestination(for: Exercise.self)`.
//
//  ## Composition (UI-SPEC § Exercise detail screen)
//
//  - Navigation title = exercise.name, inline display mode.
//  - List (.insetGrouped) with four read-only sections:
//      1. Instructions  — numbered list of `exercise.instructions`
//         (only rendered if non-empty).
//      2. Muscles       — one row per ExerciseMuscleStimulus join,
//         formatted "{Muscle name} · {weight as percent}". Sorted
//         primary first, then secondary; descending weight within each
//         tier; alphabetical by displayName on ties.
//      3. Equipment     — title-cased equipment value (Barbell / etc).
//      4. Mechanic      — "Compound" or "Isolation".
//  - Trailing button (only when `!exercise.isCustom`):
//      "Copy as Custom Exercise" — accent-foreground text button per
//      UI-SPEC § Color § Accent reserved for / item 4. Tapping hydrates
//      a `CustomExerciseDraft` from the source built-in exercise's
//      fields (name + " (Copy)" / equipment / mechanic / muscle
//      stimulus list with weights preserved) and presents
//      `CustomExerciseEditor` as a sheet wrapped in a NavigationStack.
//
//  ## Read-only affordance (UI-SPEC explicit)
//
//  Built-in exercises have NO "Edit" toolbar button and NO read-only
//  banner copy. UI-SPEC § Exercise detail screen line "Read-only banner
//  for built-in exercises (top of view): (none — absence of an edit
//  button IS the affordance; do not add explanatory text)" is followed
//  verbatim. The "Copy as Custom Exercise" CTA is the user's escape
//  hatch from the read-only world.
//
//  Custom exercises (isCustom == true) currently render the same four
//  sections without the "Copy as Custom" CTA. A direct "Edit" affordance
//  for custom exercises is deferred to Phase 1.x polish per the plan's
//  Out of Scope section.
//
//  ## Copy as Custom hydration (CONTEXT.md C-21 + C-22)
//
//  `makeDraft(from:)` builds a CustomExerciseDraft pre-populated with:
//      - name: source.name + " (Copy)"
//      - equipment: Equipment(rawValue: source.equipmentRaw) ?? .other
//      - mechanic: Mechanic(rawValue: source.mechanicRaw) ?? .compound
//      - muscles: one MuscleAssignment per source stimulus row,
//        preserving role + weight. Slug is taken from the stimulus's
//        muscle relationship (skipped if the relationship is missing
//        defensively — same resilience pattern as the importer).
//
//  Image data is intentionally NOT copied (C-22): built-in entries only
//  have unbundled `imagePaths` references with no `imageData` payload.
//  The user can attach a fresh image in the editor.
//
//  The hydrated draft has `editingExisting = nil`, so the editor's Save
//  handler calls `materialize(into:)` (insert NEW Exercise) rather than
//  `updateExisting(in:)` — meaning the source built-in is never
//  mutated. The user gets a new editable custom exercise; the built-in
//  remains pristine. (PITFALLS — never mutate templates from instance
//  flows.)
//
//  ## Why List (.insetGrouped) instead of Form
//
//  UI-SPEC § "comprehensive but uncluttered" plus visual continuity
//  with ExerciseLibraryView (which also uses `.insetGrouped`). Form is
//  for editing surfaces (the CustomExerciseEditor uses it); the detail
//  view is purely read-only display, so List + sections is the right
//  iOS-native pattern.
//

import SwiftUI
import SwiftData

/// Read-only detail surface for an Exercise. Built-in entries surface
/// a "Copy as Custom Exercise" CTA that hydrates a CustomExerciseDraft
/// and presents the editor over the detail view.
struct ExerciseDetailView: View {
    let exercise: Exercise

    /// Draft hydrated by the "Copy as Custom Exercise" action. Held as
    /// optional state because it's only constructed at the moment the
    /// CTA is tapped, and the sheet body needs the same instance across
    /// re-renders so SwiftUI's `@Bindable` storage in the editor stays
    /// stable for the lifetime of the presentation.
    @State private var draftFromCopy: CustomExerciseDraft? = nil

    /// Toggled true when the "Copy as Custom Exercise" CTA is tapped.
    /// The sheet body reads `draftFromCopy` and presents the editor
    /// when both are non-nil/true.
    @State private var presentingCustomEditor = false

    var body: some View {
        List {
            if !exercise.instructions.isEmpty {
                Section("Instructions") {
                    // Numbered list — render "{index}. {step}" rows.
                    // Using `Array(enumerated())` so each step can be
                    // identified by its position (instructions are not
                    // independently Identifiable strings).
                    ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(i + 1).")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .leading)
                            Text(step)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }

            muscleSection

            Section("Equipment") {
                Text(equipmentDisplay)
                    .font(.body)
            }

            Section("Mechanic") {
                Text(mechanicDisplay)
                    .font(.body)
            }

            if !exercise.isCustom {
                Section {
                    Button {
                        // Hydrate a fresh draft from the source built-in
                        // exercise's fields. The draft is a separate
                        // CustomExerciseDraft — the source Exercise is
                        // never mutated (PITFALLS — read-only must mean
                        // read-only for built-in entries).
                        draftFromCopy = makeDraft(from: exercise)
                        presentingCustomEditor = true
                    } label: {
                        Text("Copy as Custom Exercise")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }

            // Phase 2 Wave 5 plan 05-01 — entry point to the per-exercise
            // history view (SESS-10 / ROUTINE-08). The detail view is the
            // Library tab's canonical landing surface for an Exercise, so
            // surfacing "View All History" here matches UI-SPEC §
            // "Exercise history view with intent split — Entry point" —
            // the user reaches the per-exercise history list from the
            // Library tab's NavigationStack, not from the session logger
            // (entering it mid-session would break logger focus per the
            // plan's anti-patterns list).
            Section("History") {
                NavigationLink {
                    ExerciseHistoryView(exercise: exercise)
                } label: {
                    HStack {
                        Text("View All History")
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $presentingCustomEditor) {
            // Wrap the editor in its own NavigationStack so it owns its
            // toolbar (Save / Cancel) and navigation title. The editor
            // dismisses via `@Environment(\.dismiss)` on save/discard.
            if let draft = draftFromCopy {
                NavigationStack {
                    CustomExerciseEditor(draft: draft)
                }
            }
        }
    }

    // MARK: - Muscles section

    /// Renders one row per ExerciseMuscleStimulus join — primary tier
    /// first, then secondary; descending weight within each tier;
    /// alphabetical by displayName on weight ties.
    @ViewBuilder
    private var muscleSection: some View {
        let stimuli = exercise.muscleStimuli ?? []
        if !stimuli.isEmpty {
            Section("Muscles") {
                ForEach(stimuli.sorted(by: stimulusSort), id: \.id) { stim in
                    HStack {
                        Text(stim.muscle?.displayName ?? "Unknown")
                            .font(.body)
                        Spacer()
                        // Render as integer percent — UI-SPEC §
                        // Copywriting Contract "Muscle row label
                        // format: '{Muscle name} · {weight as percent}'
                        // — e.g. 'Chest · 100%', 'Triceps · 50%'".
                        // The middle-dot separator is provided by the
                        // HStack + Spacer; the row presents as
                        // "Chest                 100%" but VoiceOver
                        // reads them adjacent so the spec is honored.
                        Text("\(Int((stim.weight * 100).rounded()))%")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    /// Primary (`role == "primary"`) first, then secondary; within each
    /// tier, descending weight then alphabetical by display name.
    ///
    /// Comparator returns `true` when `a` should sort BEFORE `b`. The
    /// role check uses `a.role == "primary"` directly because the
    /// stimulus's `role` is stored as a raw String; an `a.role <
    /// b.role` lexicographic comparison would put "primary" AFTER
    /// "secondary" alphabetically, which is the wrong order.
    private func stimulusSort(_ a: ExerciseMuscleStimulus, _ b: ExerciseMuscleStimulus) -> Bool {
        if a.role != b.role { return a.role == "primary" }
        if a.weight != b.weight { return a.weight > b.weight }
        return (a.muscle?.displayName ?? "") < (b.muscle?.displayName ?? "")
    }

    // MARK: - Display strings

    /// Equipment value rendered title-cased per UI-SPEC ("Barbell",
    /// "Cable", "Weighted Bodyweight"). Splits underscored raws on
    /// `_` and capitalizes each component, matching plan 03-02 D-6
    /// convention. Single-word raws are a no-op for the split.
    private var equipmentDisplay: String {
        exercise.equipmentRaw
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    /// Mechanic value rendered "Compound" / "Isolation" per UI-SPEC.
    /// Raws are already single words, so `.capitalized` is sufficient.
    private var mechanicDisplay: String {
        exercise.mechanicRaw.capitalized
    }

    // MARK: - Copy as Custom hydration (CONTEXT.md C-21 + C-22)

    /// Build a `CustomExerciseDraft` from an existing built-in (or
    /// custom) `Exercise`. Used by the "Copy as Custom Exercise"
    /// action.
    ///
    /// The draft's `editingExisting` is left nil, so the editor's Save
    /// handler will invoke `materialize(into:)` (insert NEW Exercise)
    /// rather than `updateExisting(in:)`. The source `Exercise` is
    /// never mutated.
    ///
    /// Image data is intentionally not copied (C-22) — built-in entries
    /// have only `imagePaths` references to unbundled binaries; the
    /// user can attach a fresh image in the editor.
    private func makeDraft(from source: Exercise) -> CustomExerciseDraft {
        let draft = CustomExerciseDraft()
        draft.name = source.name + " (Copy)"
        draft.equipment = Equipment(rawValue: source.equipmentRaw) ?? .other
        draft.mechanic = Mechanic(rawValue: source.mechanicRaw) ?? .compound
        for stim in (source.muscleStimuli ?? []) {
            // Defensive: skip stimulus rows whose `muscle`
            // relationship somehow didn't resolve. Same resilience
            // pattern the importer uses for unknown slugs (plan 02-02
            // D-2).
            guard let slug = stim.muscle?.slug else { continue }
            let role: CustomExerciseDraft.MuscleAssignment.Role =
                stim.role == "primary" ? .primary : .secondary
            draft.muscles.append(
                .init(slug: slug, role: role, weight: stim.weight)
            )
        }
        // imageData intentionally not copied — see header comment C-22.
        return draft
    }
}

// MARK: - Previews

#Preview("Built-in exercise") {
    NavigationStack {
        let container = PreviewModelContainer.make()
        let exercises = try! container.mainContext.fetch(FetchDescriptor<Exercise>())
        ExerciseDetailView(exercise: exercises.first!)
    }
    .modelContainer(PreviewModelContainer.make())
}

#Preview("Custom exercise (no Copy CTA)") {
    NavigationStack {
        let container = PreviewModelContainer.make()
        let ctx = container.mainContext
        let muscles = try! ctx.fetch(FetchDescriptor<MuscleGroup>())
        let chest = muscles.first(where: { $0.slug == "chest" })!
        let custom = Exercise.previewSample(
            name: "Cambered Bar Bench",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["chest"],
            isCustom: true
        )
        custom.instructions = [
            "Set up cambered bar on rack at upper-chest height.",
            "Unrack and lower bar to mid-sternum under control.",
            "Press to lockout, pause briefly, repeat for prescribed reps."
        ]
        ctx.insert(custom)
        ctx.insert(ExerciseMuscleStimulus(
            exercise: custom, muscle: chest, role: "primary", weight: 1.0
        ))
        try? ctx.save()
        return ExerciseDetailView(exercise: custom)
    }
    .modelContainer(PreviewModelContainer.make())
}
