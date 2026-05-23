# 04-02 Summary - Block Builder Core

Implemented:
- `fitbod/Periodization/BlockDraft.swift` — `@Observable @MainActor`
  block builder draft. Fields: `id: UUID? = nil` (round-trips with
  the persisted Block.id), `name: String`, `startDate: Date`,
  `isActive: Bool = false`, `phases: [BlockPhaseDraft]`.
  Three initializers:
    - `init()` — empty draft for create-blank.
    - `init(template: BlockTemplate)` — seeds name + phases from a
      `BlockTemplates` stock template.
    - `init(block: Block)` — edit-mode round-trip from a persisted
      Block.
  Computed: `isValid` (non-empty name + non-empty phases),
  `totalWeeks` (sum of `phase.weeks`), `computedEndDate` (startDate
  + totalWeeks * 7 days).
  `save(into: ModelContext)` — three-way merge per the Phase 2
  RoutineDraft precedent. Single transactional write:
    1. Single-active invariant (D-05): if `draft.isActive == true`,
       fetch every other active block (`isActive == true`, `id !=
       draft.id`) and deactivate them.
    2. Match-or-insert by id; backfill draft.id from the inserted
       Block.id so subsequent saves edit in place.
    3. Write name + startDate + endDate + isActive to the Block row.
    4. Delete every BlockPhase row owned by the Block (cascade is
       set up at the schema, but the migration is from
       BlockPhaseDraft -> BlockPhase 1:1 by orderIndex).
    5. Insert one BlockPhase per `BlockPhaseDraft`, copying kind /
       weeks / volume + intensity multipliers.
    6. `try context.save()`.
- `fitbod/Periodization/BlockPhaseDraft.swift` — `@Observable @MainActor`
  per-phase draft. Fields: `id: UUID? = nil`, `kind: BlockPhaseKind`,
  `weeks: Int`, `volumeMultiplier: Double`, `intensityMultiplier:
  Double`. Two initializers: `init(kind:weeks:vol:int:)` and
  `init(phase: BlockPhase)` for edit-mode round-trip.
- `fitbod/Periodization/BlockPhaseEditorRow.swift` — per-phase
  inline editor inside `BlockBuilderView`. Renders:
    - Phase kind picker (`Picker` over `BlockPhaseKind.allCases`).
    - Weeks stepper (1...12 range).
    - Volume multiplier text field (decimal, 0.0...1.5 range).
    - Intensity multiplier text field (decimal, 0.0...1.0 range).
  Uses `LabeledContent + .menu` style matching Phase 3-fix layout
  for visual coherence with `RoutineBuilderView` header pickers.
- `fitbod/Periodization/BlockBuilderView.swift` — the single-screen
  builder. Top of Form: block name TextField + start-date
  DatePicker + active-block Toggle. Below: ordered list of
  `BlockPhaseEditorRow` with drag-handle reorder
  (`.environment(\.editMode, .constant(.active))` + `.onMove`
  rewriting orderIndex). Bottom: "Add Phase" + "Delete Phase"
  controls. Toolbar: Cancel (with dirty-check confirmation if the
  draft snapshot differs from the initial snapshot) + Save (calls
  `draft.save(into: ctx)` + `dismiss()`).

Test suites turning GREEN:
- `BlockDraftSaveTests` — pins the three-way merge save behavior:
  new draft creates Block + BlockPhase rows; existing draft updates
  in place; removing a phase from the draft deletes the matching
  BlockPhase row; adding a phase inserts a new one. 4 @Test functions.
- `SingleActiveBlockInvariantTests` — pins D-05 single-active
  invariant: saving a draft with `isActive = true` deactivates
  every other active Block in the same transaction. Tests the
  invariant against multiple pre-existing active blocks (each gets
  flipped to false). 4 @Test functions.
- `BlockBuilderViewCopyTests` — source-anchor tests for the verbatim
  UI-SPEC copy (toolbar labels, picker labels, footnote copy). 5
  @Test functions.

Verification:
- `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/BlockDraftSave -only-testing:fitbodTests/SingleActiveBlockInvariant -only-testing:fitbodTests/BlockBuilderViewCopy` -> all GREEN.
- `xcodebuild build -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'` -> BUILD SUCCEEDED.
- Regression run: `RoutineDraftValidation`, `RoutineBuilderCopy`,
  `RoutinesListCopy` -> all GREEN.

Notes:
- The single-active-block transactional sweep (D-05) is enforced
  at the `BlockDraft.save(...)` boundary inside
  `try context.transaction { ... }`. Activating block X first
  fetches every other `Block.isActive == true` row and flips
  `.isActive = false` BEFORE writing draft.isActive = true. One
  transaction, one save.
- `Block.reviewedAt` (D-26) is NOT written by `BlockDraft.save`
  even though Plan 04-02 introduces the editor that owns activation
  toggles. The reviewedAt field lands in SchemaV5 / Plan 04-08
  alongside `BlockReviewView`'s acknowledge action which is the
  ONLY legitimate writer of `reviewedAt`.
- `BlockBuilderView`'s drag-handle reorder uses the same Phase 2
  `RoutineBuilderView` pattern (`.environment(\.editMode,
  .constant(.active))` + `.onMove` rewriting orderIndex) for
  visual + behavioral coherence.

Commit: 761c78f (Wave 0..04-06 combined commit — pre-3.1
reconciliation in-flight work).
