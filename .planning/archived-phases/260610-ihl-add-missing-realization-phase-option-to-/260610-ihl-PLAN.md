---
phase: quick-260610-ihl
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - fitbod/Models/Enums/BlockPhaseKind.swift
  - fitbod/Periodization/BlockBuilderView.swift
  - fitbod/Periodization/BlockPhaseColors.swift
  - fitbod/Periodization/BlockPhaseDraft.swift
  - fitbod/Periodization/BlockTemplates.swift
  - fitbod/Periodization/BlockOverviewScreen.swift
  - fitbod/Prescription/PeriodizationEngine.swift
  - fitbodTests/EnumTests.swift
  - fitbodTests/BlockTemplatesTests.swift
  - fitbodTests/PeriodizationEngineTests.swift
autonomous: true
requirements:
  - QUICK-260610-ihl

must_haves:
  truths:
    - "BlockPhaseKind.allCases has 5 cases in declaration order: accumulation, intensification, peak, realization, deload."
    - "The New Block Add Phase sheet shows 5 selectable rows including a 'Realization' row distinct from 'Peak'."
    - "On a phase row, .peak renders title 'Peak' / subtitle 'SHARPEN OUTPUT' (the prior .realization identity)."
    - "On a phase row, .realization renders title 'Realization' / subtitle 'TEST MAXES' with a distinct color from .peak and from .deload."
    - "BlockPhaseDraft.defaultMultipliers(for: .peak) returns (0.8, 0.95); .realization remains (0.6, 0.97)."
    - "PeriodizationEngine.recommendedNextKind cycles accumulation→intensification→peak→realization→deload→accumulation."
    - "Adding the `.peak` case does NOT regress: existing Generic / Hypertrophy / PowerliftingPeak stock template phase arrays remain bit-identical."
    - "The 7-week design-fidelity preview fixture (sevenWeekPhases) contains 5 distinct phase rows matching final-design-2.png."
    - "All source-introspection guardrail suites (NewBlockBuilderFidelityTests, BlockBuilderViewCopyTests, NewBlockProgressionChartTests, BRUPeriodizationAuditTests, BRUPeriodizationRegressionTests) plus EnumTests, BlockTemplatesTests, PeriodizationEngineTests, BlockDraftSaveTests, DeloadVolumeApplicationTests are GREEN."
  artifacts:
    - path: "fitbod/Models/Enums/BlockPhaseKind.swift"
      provides: "Enum with 5 cases in order: accumulation, intensification, peak, realization, deload"
      contains: "case peak"
    - path: "fitbod/Periodization/BlockPhaseColors.swift"
      provides: ".peak arm in all four switches (badgeColor, color, badgeLabelColor, phaseLabelInk) + new distinct .realization palette"
      contains: "case .peak"
    - path: "fitbod/Periodization/BlockPhaseDraft.swift"
      provides: "defaultMultipliers .peak → (0.8, 0.95); .realization unchanged at (0.6, 0.97)"
      contains: "case .peak"
    - path: "fitbod/Periodization/BlockTemplates.swift"
      provides: "template(for: .peak) → powerliftingPeak; stock template phase arrays unchanged"
      contains: "case .peak"
    - path: "fitbod/Periodization/BlockBuilderView.swift"
      provides: "NewBlockPhaseText .peak/.realization copy split + updated sevenWeekPhases fixture + stale comment removed"
      contains: "case .peak"
    - path: "fitbod/Periodization/BlockOverviewScreen.swift"
      provides: "kindDescriptor .peak → 'PEAK · −20% VOL'; .realization → 'REALIZATION · −40% VOL'"
      contains: "case .peak"
    - path: "fitbod/Prescription/PeriodizationEngine.swift"
      provides: "recommendedNextKind 5-case cycle including .peak between .intensification and .realization"
      contains: "case .peak"
    - path: "fitbod/fitbodTests/EnumTests.swift"
      provides: "BlockPhaseKind 5-case assertion"
      contains: "\"peak\""
    - path: "fitbod/fitbodTests/BlockTemplatesTests.swift"
      provides: "template(for: .peak) → 'Powerlifting Peak' parameterized row"
      contains: "BlockPhaseKind.peak"
    - path: "fitbod/fitbodTests/PeriodizationEngineTests.swift"
      provides: ".intensification successor is .peak; .peak successor is .realization"
      contains: "BlockPhaseKind.peak"
  key_links:
    - from: "NewBlockAddPhaseTypeSheet"
      to: "BlockPhaseKind.allCases"
      via: "ForEach iteration"
      pattern: "BlockPhaseKind\\.allCases"
    - from: "BlockPhaseColors switches"
      to: "BlockPhaseKind"
      via: "Swift exhaustive switch (compiler enforces all cases)"
      pattern: "case \\.peak"
    - from: "NewBlockPhaseText (title/subtitle/abbreviation)"
      to: "BlockPhaseKind"
      via: "Swift exhaustive switch"
      pattern: "\"SHARPEN OUTPUT\"|\"TEST MAXES\""
---

<objective>
Add the missing **Realization** phase option to the New Block Add Phase sheet so all five phases from the design (final-design-2.png) are selectable: Accumulation, Intensification, **Peak**, **Realization**, Deload. Today the code has only 4 enum cases and `.realization` cosmetically renders as "Peak/SHARPEN OUTPUT" — a documented shortcut.

Purpose: Restore design fidelity. The Add Phase sheet iterates `BlockPhaseKind.allCases`, so introducing a new `.peak` case (which takes over the existing Peak identity) and re-purposing `.realization` for its true "Test maxes" semantics automatically adds the missing row.

Output: 5-case `BlockPhaseKind` enum with `.peak` inserted between `.intensification` and `.realization`; updated copy, colors, default multipliers, next-phase cycle, design-fidelity preview fixture; updated tests that pin enum shape; all guardrail + periodization test suites GREEN.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@./CLAUDE.md
@.planning/STATE.md
@fitbod/Models/Enums/BlockPhaseKind.swift
@fitbod/Periodization/BlockPhaseColors.swift
@fitbod/Periodization/BlockPhaseDraft.swift
@fitbod/Periodization/BlockTemplates.swift
@fitbod/Periodization/BlockOverviewScreen.swift
@fitbod/Prescription/PeriodizationEngine.swift
@bru-screens/New-block/final-design-2.png

<interfaces>
<!-- Key contracts already extracted by orchestrator + this read pass -->

From fitbod/Models/Enums/BlockPhaseKind.swift (current 4-case shape):
```swift
public enum BlockPhaseKind: String, CaseIterable, Sendable {
    case accumulation
    case intensification
    case realization
    case deload
    public static let `default`: BlockPhaseKind = .accumulation
}
```

From fitbod/Periodization/BlockBuilderView.swift:1577–1603 (NewBlockPhaseText) — current "Peak/SHARPEN OUTPUT" lives on `.realization`. After the change, `.peak` owns "Peak/SHARPEN OUTPUT/Peak" and `.realization` becomes "Realization/TEST MAXES/Real.".

From fitbod/Periodization/BlockPhaseColors.swift — FOUR switches need a `.peak` arm: `color(for:)` ~14–22, `badgeColor(for:)` ~57–66, `badgeLabelColor(for:)` ~72–81, `phaseLabelInk(for:)` ~88–101. `.peak` inherits the current `.realization` values verbatim (bruInk 0.25 / bruGreen / white / forest-green ink #22603C). `.realization` gets a NEW palette distinct from `.peak`, `.deload`, `.clear`, `.bruMuted`.

From fitbod/Periodization/BlockPhaseDraft.swift:53–64 — `.peak` returns (0.8, 0.95) matching design row-04 "VOL −20%, INT 95%". `.realization` stays (0.6, 0.97).

From fitbod/Prescription/PeriodizationEngine.swift:90–101 — new cycle: accumulation → intensification → peak → realization → deload → accumulation.

From fitbod/Periodization/BlockOverviewScreen.swift:489–496 — `.peak` → "PEAK · −20% VOL"; `.realization` → "REALIZATION · −40% VOL".

From fitbod/Periodization/BlockTemplates.swift:60–71 — `template(for: .peak)` returns `powerliftingPeak`. Static `generic`/`hypertrophy`/`powerliftingPeak` phase arrays (lines 29–56) are UNCHANGED — stock template tests depend on the existing `.realization` rows.

From fitbod/Periodization/BlockBuilderView.swift:2081–2092 — replace the stale `// (BlockPhaseKind has 4 cases; ... covered by .realization)` comment block AND restructure `sevenWeekPhases()` so the 7-week mockup has 5 distinct phases:
  - .accumulation, weeks 2, (1.2, 0.70)
  - .intensification, weeks 2, (1.0, 0.85)
  - .peak, weeks 1, (0.8, 0.95)
  - .realization, weeks 1, (0.6, 0.97)
  - .deload, weeks 1, (0.5, 0.60)

Test guardrails (orchestrator-confirmed must-update):
- fitbodTests/EnumTests.swift:117–123 → 5-case assertion + rename test to "BlockPhaseKind has exactly 5 cases".
- fitbodTests/BlockTemplatesTests.swift:50–61 → add `(BlockPhaseKind.peak, "Powerlifting Peak")` row to the parameterized `template for phase kind mapping` test; lines 71–93 `d10MultipliersVerbatim` needs a `case .peak:` arm (templates don't contain .peak, so default a no-op `break` arm or restructure — see action).
- fitbodTests/PeriodizationEngineTests.swift:117–126 cycle table → add `(.intensification, .peak)` and `(.peak, .realization)`; replace existing `(.intensification, .realization)` row.

Project memory guardrail (MUST run all): NewBlockBuilderFidelityTests, BlockBuilderViewCopyTests, NewBlockProgressionChartTests, BRUPeriodizationAuditTests, BRUPeriodizationRegressionTests. Running only one and leaving a sibling red is the documented executor failure mode.

SwiftData migration: BlockPhaseKind is String-backed; adding a case is additive and migration-safe. No `nameRaw == "peak"` rows can exist yet, so no SchemaMigrationPlan change required.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add .peak case + update all exhaustive switches + design-fidelity preview</name>
  <files>fitbod/Models/Enums/BlockPhaseKind.swift, fitbod/Periodization/BlockPhaseColors.swift, fitbod/Periodization/BlockPhaseDraft.swift, fitbod/Periodization/BlockTemplates.swift, fitbod/Periodization/BlockOverviewScreen.swift, fitbod/Prescription/PeriodizationEngine.swift, fitbod/Periodization/BlockBuilderView.swift</files>
  <behavior>
    - `BlockPhaseKind.allCases.count == 5` and `.map(\.rawValue) == ["accumulation","intensification","peak","realization","deload"]` (declaration order matters — the Add Phase sheet renders in this order).
    - `NewBlockPhaseText.title(for: .peak) == "Peak"`, `.subtitle == "SHARPEN OUTPUT"`, `.abbreviation == "Peak"`.
    - `NewBlockPhaseText.title(for: .realization) == "Realization"`, `.subtitle == "TEST MAXES"`, `.abbreviation == "Real."`.
    - `BlockPhaseColors.phaseLabelInk(for: .peak)` returns the deepened forest green `Color(red: 34/255, green: 96/255, blue: 60/255)` (verbatim transfer from current `.realization`).
    - `BlockPhaseColors.phaseLabelInk(for: .realization)` returns a NEW value distinct from `.clear`, `.bruMuted`, the new `.peak` ink, and the `.deload` ink — use deep plum `Color(red: 78/255, green: 38/255, blue: 70/255)` (dark muted plum/ink that reads on a 0.18 plum tint band, matches design row-05 swatch).
    - `BlockPhaseColors.badgeColor(for: .peak) == .bruGreen` (verbatim transfer from current `.realization`).
    - `BlockPhaseColors.badgeColor(for: .realization)` returns a new color distinct from existing badges — use `Color(red: 122/255, green: 60/255, blue: 110/255)` (saturated plum complementing bruGreen).
    - `BlockPhaseColors.color(for: .peak) == Color.bruInk.opacity(0.25)` (verbatim transfer); `.color(for: .realization)` returns a new translucent plum band `Color(red: 122/255, green: 60/255, blue: 110/255).opacity(0.18)`.
    - `BlockPhaseColors.badgeLabelColor(for: .peak) == .white`; `.realization == .white` (both badges are dark fills).
    - `BlockPhaseDraft.defaultMultipliers(for: .peak) == (volume: 0.8, intensity: 0.95)`.
    - `BlockPhaseDraft.defaultMultipliers(for: .realization) == (volume: 0.6, intensity: 0.97)` (unchanged).
    - `BlockTemplates.template(for: .peak).name == "Powerlifting Peak"`.
    - `BlockTemplates.generic.phases`, `BlockTemplates.hypertrophy.phases`, `BlockTemplates.powerliftingPeak.phases` are bit-identical to current values (no `.peak` insertion in stock templates).
    - `PeriodizationEngine.recommendedNextKind(after: .intensification) == .peak`; `.peak → .realization`; `.realization → .deload`; `.deload → .accumulation`; `.accumulation → .intensification`.
    - `BlockOverviewScreen` kindDescriptor: `.peak → "PEAK · −20% VOL"`, `.realization → "REALIZATION · −40% VOL"`.
    - `sevenWeekPhases()` preview fixture in BlockBuilderView returns 5 entries totaling 7 weeks: `[.accumulation×2, .intensification×2, .peak×1, .realization×1, .deload×1]`; the stale `// (BlockPhaseKind has 4 cases ...)` comment at lines 2082–2083 is removed.
  </behavior>
  <action>
    Implement the 5-case enum end-to-end. Use `let` over `var` per Swift style rules; no new imports needed.

    1. **fitbod/Models/Enums/BlockPhaseKind.swift** — insert `case peak` between `case intensification` and `case realization`. Final declaration order: accumulation, intensification, peak, realization, deload. Keep `public static let \`default\`: BlockPhaseKind = .accumulation` unchanged.

    2. **fitbod/Periodization/BlockPhaseColors.swift** — update all four switches. Pattern for each: keep accumulation/intensification/deload arms unchanged; transfer the current `.realization` value to a new `.peak` arm; assign a NEW value to `.realization`.
       - `color(for:)`: `.peak → Color.bruInk.opacity(0.25)`; `.realization → Color(red: 122/255, green: 60/255, blue: 110/255).opacity(0.18)`.
       - `badgeColor(for:)`: `.peak → .bruGreen`; `.realization → Color(red: 122/255, green: 60/255, blue: 110/255)`.
       - `badgeLabelColor(for:)`: `.peak → .white`; `.realization → .white`.
       - `phaseLabelInk(for:)`: `.peak → Color(red: 34/255, green: 96/255, blue: 60/255)` (forest green, was `.realization`); `.realization → Color(red: 78/255, green: 38/255, blue: 70/255)` (deep plum). Add a brief `//` comment on each line stating the design intent (e.g., `// Deep plum — passes contrast on 0.18 plum tint band, distinct from .peak forest green.`).
       - Do NOT modify `rowTint(for:)` (default arm catches everything) or `drawDeloadStripes` / `phaseLabel`.

    3. **fitbod/Periodization/BlockPhaseDraft.swift:53–64** — add `case .peak: return (0.8, 0.95)` between intensification and realization. Leave `.realization → (0.6, 0.97)` unchanged. Compiler exhaustiveness will flag if missed.

    4. **fitbod/Periodization/BlockTemplates.swift:60–71** — add `case .peak: return powerliftingPeak` arm to `template(for:)`. Do NOT touch the static `generic`, `hypertrophy`, `powerliftingPeak`, or `blank` template literal arrays — their `.realization` entries stay as-is (preset behavior unchanged, BlockTemplatesTests depend on this).

    5. **fitbod/Periodization/BlockOverviewScreen.swift:489–496** — update the `kindDescriptor` switch: add `case .peak: return "PEAK · −20% VOL"`; change `.realization → "REALIZATION · −40% VOL"` (was "PEAK · −20% VOL").

    6. **fitbod/Prescription/PeriodizationEngine.swift:90–101** — restructure `recommendedNextKind(after:)`:
       ```
       case .accumulation: return .intensification
       case .intensification: return .peak
       case .peak: return .realization
       case .realization: return .deload
       case .deload: return .accumulation
       ```

    7. **fitbod/Periodization/BlockBuilderView.swift:1577–1603 (NewBlockPhaseText)** — update three switches. New `.peak` arms own the current `.realization` strings; `.realization` arms get new design copy:
       - `title(for:)`: `.peak → "Peak"`; `.realization → "Realization"`.
       - `subtitle(for:)`: `.peak → "SHARPEN OUTPUT"`; `.realization → "TEST MAXES"`.
       - `abbreviation(for:)`: `.peak → "Peak"`; `.realization → "Real."`.

    8. **fitbod/Periodization/BlockBuilderView.swift:2081–2092 (sevenWeekPhases preview)** — delete the stale two-line comment at 2082–2083. Replace the body so the fixture is 5 entries totaling 7 weeks matching the 5-row mockup:
       ```
       BlockPhaseDraft(kind: .accumulation, weeks: 2, volumeMultiplier: 1.2, intensityMultiplier: 0.70),
       BlockPhaseDraft(kind: .intensification, weeks: 2, volumeMultiplier: 1.0, intensityMultiplier: 0.85),
       BlockPhaseDraft(kind: .peak, weeks: 1, volumeMultiplier: 0.8, intensityMultiplier: 0.95),
       BlockPhaseDraft(kind: .realization, weeks: 1, volumeMultiplier: 0.6, intensityMultiplier: 0.97),
       BlockPhaseDraft(kind: .deload, weeks: 1, volumeMultiplier: 0.5, intensityMultiplier: 0.60),
       ```
       Keep the leading comment, but replace it with: `// 7-week fixture for chart-proportion checks against final-design-2.png — 5 distinct phases.`

    Compiler-driven completeness: after step 1, run `xcodebuild build` and chase every "switch must be exhaustive" error to its file. The recon list above is authoritative — any extra switch the compiler surfaces (e.g., `BlockPhaseEditorRow.swift:199` or `MesocycleWeekPage.swift:86` which use multi-case patterns like `.intensification, .deload`) does NOT need a `.peak` arm unless the compiler complains; those `default`-style patterns are not exhaustive over `BlockPhaseKind`. If a switch elsewhere DOES require an arm, default `.peak`'s behavior to mirror what `.realization` does today (they're visually paired), and surface the decision in the SUMMARY.

    Run all source-introspection guardrail suites + periodization tests together (the project memory mandate — running one and leaving siblings red is the documented executor failure).
  </action>
  <verify>
    <automated>xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:fitbodTests/NewBlockBuilderFidelityTests -only-testing:fitbodTests/BlockBuilderViewCopyTests -only-testing:fitbodTests/NewBlockProgressionChartTests -only-testing:fitbodTests/BRUPeriodizationAuditTests -only-testing:fitbodTests/BRUPeriodizationRegressionTests test 2>&1 | rg -e 'Test Suite.*(passed|failed)' -e '^\s+✘' -e 'error:' | tail -40</automated>
  </verify>
  <done>Build succeeds (zero compiler errors). All 5 source-introspection guardrail suites GREEN. BlockPhaseKind has 5 cases in the prescribed order. NewBlockPhaseText splits Peak/Realization copy per design. BlockPhaseColors has distinct palettes for `.peak` (forest-green inherited) and `.realization` (deep plum new). sevenWeekPhases preview is 5 entries with the stale comment removed. Stock template literal arrays are bit-identical to pre-change. No `git add -A` performed.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Update enum/template/cycle assertions for the new 5-case shape</name>
  <files>fitbodTests/EnumTests.swift, fitbodTests/BlockTemplatesTests.swift, fitbodTests/PeriodizationEngineTests.swift</files>
  <behavior>
    - `EnumTests.blockPhaseKindHasFourCases` is renamed to assert 5 cases including "peak" in the rawValue set.
    - `BlockTemplatesTests.templateForKindMappingDeterministic` parameterized table includes `(BlockPhaseKind.peak, "Powerlifting Peak")`.
    - `BlockTemplatesTests.d10MultipliersVerbatim` switch is exhaustive over the 5-case enum (adds a `.peak: break` arm because no stock template currently inserts `.peak` — the test iterates phases inside templates, and templates have no `.peak` rows).
    - `PeriodizationEngineTests` cycle table replaces `(.intensification, .realization)` with `(.intensification, .peak)` and adds `(.peak, .realization)`; the `.realization → .deload` and `.deload → .accumulation` rows remain.
    - All three test files compile without "switch must be exhaustive" errors and tests pass GREEN.
  </behavior>
  <action>
    Use Swift Testing (`@Test`, `#expect`, `arguments:`) per project test rules. Do not introduce XCTest.

    1. **fitbodTests/EnumTests.swift:117–123** — rename the test to `"BlockPhaseKind has exactly 5 cases"` (annotation string + function name `blockPhaseKindHasFiveCases`) and update assertions:
       ```
       #expect(BlockPhaseKind.allCases.count == 5)
       #expect(Set(BlockPhaseKind.allCases.map(\.rawValue)) == [
           "accumulation", "intensification", "peak", "realization", "deload",
       ])
       ```
       Also add an order-sensitive assertion to lock declaration order (the Add Phase sheet renders in `allCases` order):
       ```
       #expect(BlockPhaseKind.allCases.map(\.rawValue) == [
           "accumulation", "intensification", "peak", "realization", "deload",
       ])
       ```

    2. **fitbodTests/BlockTemplatesTests.swift:50–61** — extend the `arguments:` array on `templateForKindMappingDeterministic` with `(BlockPhaseKind.peak, "Powerlifting Peak")` (inserted between intensification and realization to mirror enum order):
       ```
       arguments: [
           (BlockPhaseKind.accumulation, "Generic Strength Meso"),
           (BlockPhaseKind.intensification, "Hypertrophy Meso"),
           (BlockPhaseKind.peak, "Powerlifting Peak"),
           (BlockPhaseKind.realization, "Powerlifting Peak"),
           (BlockPhaseKind.deload, "Generic Strength Meso"),
       ]
       ```

    3. **fitbodTests/BlockTemplatesTests.swift:71–93** — `d10MultipliersVerbatim` iterates `allPhases` (entries inside templates) and switches on `phase.kind`. Stock templates contain no `.peak` rows, but the Swift compiler will still demand an exhaustive switch. Add `case .peak: break` (with a `//` comment: `// No stock template currently inserts .peak; defaults are exercised by BlockPhaseDraft tests instead.`). Leave the other four arms unchanged.

    4. **fitbodTests/PeriodizationEngineTests.swift:117–126** — update the parameterized cycle table:
       ```
       (BlockPhaseKind.accumulation, BlockPhaseKind.intensification),
       (BlockPhaseKind.intensification, BlockPhaseKind.peak),
       (BlockPhaseKind.peak, BlockPhaseKind.realization),
       (BlockPhaseKind.realization, BlockPhaseKind.deload),
       (BlockPhaseKind.deload, BlockPhaseKind.accumulation),
       ```
       If only 3 rows existed, add the missing `.deload → .accumulation` row too. The single `#expect(PeriodizationEngine.recommendedNextKind(after: input) == expected)` body line stays unchanged.

    Stage ONLY the three test files you touch in this task plus the source files from Task 1. Never run `git add -A` (repo has unrelated uncommitted WIP per orchestrator recon).
  </action>
  <verify>
    <automated>xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:fitbodTests/EnumTests -only-testing:fitbodTests/BlockTemplatesTests -only-testing:fitbodTests/PeriodizationEngineTests -only-testing:fitbodTests/BlockDraftSaveTests -only-testing:fitbodTests/DeloadVolumeApplicationTests test 2>&1 | rg -e 'Test Suite.*(passed|failed)' -e '^\s+✘' -e 'error:' | tail -40</automated>
  </verify>
  <done>EnumTests, BlockTemplatesTests, PeriodizationEngineTests, BlockDraftSaveTests, DeloadVolumeApplicationTests all GREEN. New cycle row `.peak → .realization` is asserted. Template mapping for `.peak` returns "Powerlifting Peak". 5-case rawValue assertion + order-sensitive assertion both present. No XCTest imports introduced.</done>
</task>

</tasks>

<verification>
Full guardrail + periodization sweep — must be GREEN end-to-end before SUMMARY:

```
xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:fitbodTests/NewBlockBuilderFidelityTests \
  -only-testing:fitbodTests/BlockBuilderViewCopyTests \
  -only-testing:fitbodTests/NewBlockProgressionChartTests \
  -only-testing:fitbodTests/BRUPeriodizationAuditTests \
  -only-testing:fitbodTests/BRUPeriodizationRegressionTests \
  -only-testing:fitbodTests/EnumTests \
  -only-testing:fitbodTests/BlockTemplatesTests \
  -only-testing:fitbodTests/PeriodizationEngineTests \
  -only-testing:fitbodTests/BlockDraftSaveTests \
  -only-testing:fitbodTests/DeloadVolumeApplicationTests \
  test 2>&1 | rg -e 'Test Suite.*(passed|failed)' -e '^\s+✘' -e 'error:'
```

Also confirm visually (sanity-only, not a blocker):
- Open `BlockBuilderView` 7-week meso preview in Xcode Canvas; the progression chart shows 5 distinct bands (accumulation 2w → intensification 2w → peak 1w → realization 1w → deload 1w).
- Open `NewBlockAddPhaseTypeSheet` in the running simulator; tap "+ Add phase"; verify 5 rows render with distinct title/subtitle copy and badge colors.

Repo hygiene:
```
git status --short
```
Verify only the 10 files in this plan's `files_modified` (plus the pre-existing unrelated WIP) are listed. Never run `git add -A`.
</verification>

<success_criteria>
- `BlockPhaseKind` has 5 cases in order accumulation/intensification/peak/realization/deload.
- The Add Phase sheet shows a distinct "Realization" row (TEST MAXES) separate from "Peak" (SHARPEN OUTPUT).
- `.peak` inherits the prior `.realization` visuals (bruGreen badge, forest-green ink, bruInk 0.25 band).
- `.realization` has a NEW distinct plum palette (badge + ink + band) that passes existing contrast assertions.
- `BlockPhaseDraft.defaultMultipliers(.peak) == (0.8, 0.95)`; `.realization` unchanged at (0.6, 0.97).
- `PeriodizationEngine.recommendedNextKind` cycle includes `.peak` between intensification and realization.
- Stock templates (`generic`, `hypertrophy`, `powerliftingPeak`) are bit-identical — no `.peak` insertion.
- `sevenWeekPhases()` design-fidelity preview fixture has 5 distinct phases; stale 4-case comment removed.
- All 10 test suites listed in `<verification>` pass GREEN.
- Build succeeds with zero compiler errors and zero new warnings.
- Only files in `files_modified` are staged for commit (preserve unrelated WIP).
</success_criteria>

<output>
After completion, create `.planning/quick/260610-ihl-add-missing-realization-phase-option-to-/260610-ihl-SUMMARY.md` with:
- Truths satisfied (5 cases visible, Realization row distinct from Peak, etc.)
- Files touched (with line ranges)
- Test results (suite-by-suite pass count)
- Any "extra" exhaustive-switch sites the compiler surfaced beyond the recon list, plus the decision made for `.peak` in each
- Confirmation that stock template arrays are unchanged
- Confirmation that no `git add -A` was used
</output>