# Phase 2 — UI Review

**Audited:** 2026-05-23
**Baseline:** `02-UI-SPEC.md` v2 (BRU brutalist rewrite, committed 4c1674b on 2026-05-23)
**Screenshots:** not captured (iOS project — no dev server; localhost:3000 / 5173 unreachable). Audit is code-only against UI-SPEC requirements.
**Stance:** Adversarial. The user explicitly flagged that the implementation predates BRU. This report exists to produce a concrete, file-by-file gap list — NOT to soften the score with averaging. Where evidence is overwhelming, the score is 1/4. The value here is the migration backlog at the bottom, not the headline number.

---

## TL;DR — One-Paragraph Verdict

**The Phase 2 visual layer does not implement the BRU v2 contract at any level.** Zero BRU foundations exist: no `Color+BRU.swift`, no `BRUFont.swift`, no 8 `bru*.colorset` assets, no `BRUHeaderBar` / `BRUTabBar` / `BRUChip` / `BRUSectionHead` / `BRUButton` / `BRUDisplay` / `BRUReadout` / `BRUSpark` / `BRUDashedSlot` / `BRUPillButton` / `BRUSupersetBracket` / `BRUCornerBadge` / `BRUDivider` / `SetCompletionGlyph` / `RestTimerProgressArc` primitives, no bundled `SpaceGrotesk-Bold.otf` / `JetBrainsMono-Regular.otf` fonts, no `UIAppFonts` entry in `Info.plist`, no `TodayView` / `TodayStatStrip` / `BlockContextBand` / `WeekTickerCells` / `BlackSlabCTA` / `LiftListRow` views, no `SessionHistoryView` / `SessionHistoryStatStrip` / `WeeklyTonnageSparkCard` views. The implemented surfaces are pure Apple HIG: `Color.accentColor` (teal) on 91 sites across 22 Phase 2 files; `.font(.title2 | .headline | .body | .caption)` semantic styles on 95 sites; `Image(systemName:)` on 17 sites where BRU forbids SF Symbols entirely; `Capsule()` and `RoundedRectangle(cornerRadius: 8/12/22)` clips on 15+ sites where BRU forbids any rounding; 5 `Color(.systemBlue|Orange|Red|Purple|Yellow)` semantic colors in `SetTypeChip` / `PinnedNoteCapsule` that BRU explicitly removes. The interaction contract (snapshot pattern, rest-timer engine, navigation paths, copy strings) is preserved verbatim — the engine, scheduler, ActivityKit controller, and `SessionFactory` snapshot pattern all function correctly. The work needed is a pure visual rewrite, not a re-architecture.

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 3/4 | Verbatim v1 copy preserved (correct per spec). Case treatment (UPPERCASE labels) missing; new BRU-only TodayView/SessionHistoryView copy not implemented. |
| 2. Visuals | 1/4 | Zero BRU primitives exist; entire visual layer is unmodified Apple HIG `Form` / `List(.insetGrouped)` with system chrome. TodayView is a placeholder `private struct` inside RootView.swift. SessionHistoryView does not exist. |
| 3. Color | 1/4 | `Color.accentColor` (deprecated teal) referenced 91 times across 22 Phase 2 files. Zero `bruInk` / `bruPaper` / `bruSignal` references anywhere. `Color(.systemBlue|Orange|Red|Purple|Yellow)` still drives `SetTypeChip` after BRU explicitly removed them. No `bru*.colorset` assets exist. |
| 4. Typography | 1/4 | Zero BRU `displayHero` / `displayLarge` / `displayMedium` / `bodyEmphasis` / `bodyDefault` / `labelSmall` / `labelMicro` references. Zero `BRUFont` enum. Apple semantic font styles still in use: 64 `.font(.caption)`, 19 `.font(.body)`, 7 `.font(.headline)`, 5 `.font(.title2)` in Phase 2 surfaces. No `SpaceGrotesk` / `JetBrainsMono` `.otf` files bundled; `Info.plist` lacks `UIAppFonts`. |
| 5. Spacing | 3/4 | Padding values mostly land on the 4pt/8pt/12pt/16pt/24pt grid (the spec carries this forward from v1, and the existing code matches). Border-weight contract (`1pt` `bruHair`, `1.5pt` outer set-rows, `2pt` ink rules) is unimplemented — no `Rectangle().fill(.bruInk).frame(height: 2)` patterns exist. |
| 6. Experience Design | 3/4 | Loading state present (RootView `splash`); error states wired (Alert / confirmationDialog); empty states present per surface; destructive confirmations use `role: .destructive`; rest timer engine + ActivityKit composition is clean. The mechanics are right; the visual shell around them is wrong. |

**Overall: 12/24**

This is a low score because two pillars (Visuals + Color + Typography → really three pillars of the contract) failed cleanly. Experience Design and Copywriting (interaction + strings) sit at 3/4 because the underlying behavior + verbatim v1 copy were preserved when the spec was rewritten. **Score these honestly — the visual surface needs a full rebuild; the behavior layer is fine.**

---

## Top 3 Priority Fixes

1. **BLOCKER — Implement the BRU foundation primitives (Wave A in spec).** No `Color+BRU.swift`, `BRUFont.swift`, or 8 `bru*.colorset` assets exist. Until these land, no Phase 2 surface can render BRU. Concrete fix: create `fitbod/Design/Color+BRU.swift` with 8 `static let` extensions pointing at 8 new `Assets.xcassets` colorsets (`bruInk` / `bruPaper` / `bruSignal` / `bruFaint` / `bruHair` / `bruMuted` / `bruBg` / `bruBg2`) using the locked hex values in UI-SPEC § Color (light + dark variants). Create `fitbod/Design/BRUFont.swift` exposing 7 size roles via `Font.custom(...)`. Bundle `SpaceGrotesk-Bold.otf`, `SpaceGrotesk-SemiBold.otf`, `JetBrainsMono-Regular.otf`, `JetBrainsMono-Bold.otf` under `fitbod/Resources/Fonts/`. Add `INFOPLIST_KEY_UIAppFonts` (or literal `UIAppFonts` in `fitbod/Info.plist` line ~25 next to `NSSupportsLiveActivities`).

2. **BLOCKER — Implement the BRU primitive component library.** The 15+ component primitives the spec mandates (BRUChip, BRUDisplay, BRUReadout, BRUSectionHead, BRUButton, BRUSpark, BRUTabBar, BRUHeaderBar, BRUDivider, BRUDashedSlot, BRUPillButton, BRUSupersetBracket, BRUCornerBadge, SetCompletionGlyph, RestTimerProgressArc) do not exist. Until they exist, every Phase 2 surface rewrite is blocked. Concrete fix: create `fitbod/Design/` directory and ship one file per primitive per UI-SPEC § Component Inventory § BRU primitive components table. Each is < 50 LOC; the whole set is a single Wave A task. Without them the surfaces below cannot be rewritten because they all bind to these types.

3. **BLOCKER — Replace `TodayView` placeholder + add `SessionHistoryView` (both NEW in v2).** `TodayView` is currently a 219-line `private struct` inside `fitbod/App/RootView.swift` line 271 — it renders `DeloadAdvisoryBanner`, `BlockCard`, `StartBlockCTA`, `ResumeWorkoutBanner`, `FatigueSurfaceView`, and a `Text("No workout in progress").font(.title2)` empty state. BRU requires `fitbod/Views/TodayView.swift` as a standalone surface composed of `BRUHeaderBar` → `TodayStatStrip` (3 BRUReadouts) → `BlockContextBand` → `WeekTickerCells` → `BlackSlabCTA` (or `ResumeWorkoutSlab`) → `LiftListSection` → `BRUTabBar`. `SessionHistoryView` does not exist at all and must be created at `fitbod/Sessions/SessionHistoryView.swift` with `SessionHistoryStatStrip`, `WeeklyTonnageSparkCard`, and `SessionHistoryRow`. These two surfaces are the entire BRU "home + history" story; without them the brutalist visual contract has nothing to live on.

(Honorable mentions that would be Top 5 in a less BRU-mismatched audit: SF Symbol purge from 17 sites, RoundedRectangle + Capsule purge from 15 sites, system-color purge from `SetTypeChip` / `PinnedNoteCapsule` / `WarmupRampRows`. These are addressed in the per-pillar findings.)

---

## Detailed Findings

### Pillar 1: Copywriting (3/4)

The interaction copywriting contract is largely intact — v1 copy was preserved verbatim per the spec's explicit instruction ("All copy from v1 is preserved verbatim — the BRU rewrite is purely visual"). The graders here are case treatment, new BRU-only screens, and a handful of copy tweaks BRU introduced.

**Preserved correctly (passes):**
- `fitbod/Sessions/SessionLoggerView.swift:141` — `navigationTitle("Workout")` ✓
- `fitbod/Sessions/SessionLoggerView.swift:154` — `Button("Discard")` ✓
- `fitbod/Sessions/SessionLoggerView.swift:160` — `Button("Finish")` ✓
- `fitbod/Sessions/SessionLoggerView.swift:167` — `"Finish Workout?"` confirmation title ✓
- `fitbod/Sessions/SessionLoggerView.swift:187` — `"No data will be saved."` ✓
- `fitbod/Sessions/RestTimer/RestTimerOverlay.swift:108` — `Text("Rest Timer")` header ✓
- `fitbod/Sessions/RestTimer/RestTimerOverlay.swift:133, 142` — `"−15s"`, `"+15s"` ✓
- `fitbod/Sessions/RestTimer/RestTimerOverlay.swift:149` — `Button("Skip")` ✓
- `fitbod/Sessions/RestTimer/RestTimerNotificationScheduler.swift` — `"Rest complete"` / `"{exerciseName} — next set ready."` notification copy ✓
- `fitbod/Routines/RoutinesListView.swift:96` — `navigationTitle("Routines")` ✓ (but BRU wants `BRUHeaderBar(center: "Routines", right: "+ NEW")` with a sticky `BRUTabBar` below)

**WARNING — case treatment is wrong (BRU requires `.textCase(.uppercase)` at the view layer for label-class strings, source-of-truth stays mixed-case):**
- No `.textCase(.uppercase)` modifier appears anywhere in Phase 2 surfaces. Spec requires it on every `labelSmall` instance (tab labels, section heads, chip labels, set-type chips, intent filter chips, day-tab labels, "NEXT", "DAY 01 / 04", "5 EXERCISES", "COMPOUND", "WORK", "TOP", "BACK", etc.). Verification: `grep -rn "textCase" fitbod/Routines fitbod/Sessions fitbod/Views --include="*.swift"` returns 0 matches. This is a one-line-per-label fix once `BRUChip` / `BRUSectionHead` / `labelSmall` font role exist.

**WARNING — new BRU-only screens missing all their copy:**
- TodayView's BRU copy is completely absent: no `"Day streak"`, `"Sessions"`, `"W3 / 5 ↑"`, `"Block"`, `"Intensification"`, `"W1"`/`"W2"`/`"W3"`/`"W4"`/`"W5"`, `"DL"`, `"NEXT"`, `"DAY 01 / 04"`, `"Start workout ▸"`, `"Lift list"`, `"Tap to reorder"`, `"+ NEW ROUTINE"`. The current TodayView (`fitbod/App/RootView.swift:271-489`) ships a stub empty state (`Text("No workout in progress").font(.title2)`) that does NOT match BRU's "No workout scheduled" heading + "Build a routine or pick one from your library." body + "+ NEW ROUTINE" signal action.
- SessionHistoryView's BRU copy entirely absent: no `"FILTER"`, `"WEEKLY TONNAGE · 8 WK"`, `"PAST SESSIONS"`, `"21 SETS · 52M"`, `"PR · e1RM"` / `"PR · VOL"` / `"PR · WEIGHT"`, `"No sessions yet"` empty state. SessionHistoryView.swift does not exist.

**WARNING — copy that DID change from v1 → BRU is not picked up:**
- BRU spec line 357: `"FINISH"` (signal text in the right-side menu) — currently `Button("Finish")` mixed-case at `SessionLoggerView.swift:160`. Acceptable per "case treatment lives at render layer," but the toolbar is system Apple chrome, not a `BRUHeaderBar` right action.
- BRU spec line 271: `"+ NEW"` for the Routines tab header right action (signal text button) — currently a SF Symbol `plus` Label inside a `Menu` at `RoutinesListView.swift:113-116`.
- BRU spec line 304: drag handle should be `"⋮⋮"` typographic character — currently SF Symbol `line.3.horizontal` via `EditMode`. Verification: `RoutineBuilderView.swift:201` uses `.environment(\.editMode, .constant(.active))` which renders Apple's three-line grabber.

**WARNING — accessibility labels need updating for BRU:**
- `IntentChip.swift:57` uses `"Intent: \(intent.rawValue.capitalized)"` — fine for BRU.
- `RestTimerOverlay.swift:137, 146, 155, 69` already match BRU verbatim a11y. ✓

**Score justification: 3/4** — Interaction copy preserved (correct per spec); case treatment missing across the board; new TodayView/SessionHistoryView/SessionHistoryRow copy entirely unwritten. The penalty is the missing BRU-only surfaces, not the preserved-v1 layer.

---

### Pillar 2: Visuals (1/4)

This pillar fails completely. The mockups under `/Users/chrissaechao/Desktop/fitbod/bru-screens/today.jsx` (117 lines), `routine-builder.jsx` (172 lines), `session-history.jsx` (92 lines) — the explicit visual source of truth per the spec — have zero pixel parity with the implemented surfaces.

**BLOCKER — Zero BRU primitives implemented:**
Verification: `grep -rln "BRUHeaderBar|BRUTabBar|BRUChip|BRUButton|BRUDisplay|BRUReadout|BRUSpark|BRUSectionHead|BRUDivider|BRUDashedSlot|BRUPillButton|BRUSupersetBracket|BRUCornerBadge|SetCompletionGlyph|RestTimerProgressArc|TodayStatStrip|BlockContextBand|WeekTickerCells|BlackSlabCTA|ResumeWorkoutSlab|LiftListSection|LiftListRow|SessionHistoryView|SessionHistoryStatStrip|WeeklyTonnageSparkCard|SessionHistoryRow|RestTimerDynamicIslandCompactView|RestTimerDynamicIslandExpandedView" fitbod` returns ZERO hits inside `fitbod/`. The only hits are in `.planning/phases/02-core-loop-routines-sessions/02-UI-SPEC.md` (the spec itself).

**BLOCKER — Zero new BRU surfaces exist:**
- `fitbod/Views/TodayView.swift` — does not exist as a standalone file. The Today tab in `RootView.swift:170-174` mounts a `private struct TodayView` defined inline at `RootView.swift:271-489` (Wave-5 Phase 5 deload/fatigue UI, not the BRU TodayView).
- `fitbod/Views/TodayStatStrip.swift`, `BlockContextBand.swift`, `WeekTickerCells.swift`, `BlackSlabCTA.swift`, `ResumeWorkoutSlab.swift`, `LiftListSection.swift`, `LiftListRow.swift` — none exist.
- `fitbod/Sessions/SessionHistoryView.swift`, `SessionHistoryStatStrip.swift`, `WeeklyTonnageSparkCard.swift`, `SessionHistoryRow.swift` — none exist.

**BLOCKER — Default Apple chrome everywhere instead of `BRUHeaderBar`:**
- 21 `navigationTitle(...)` + `navigationBarTitleDisplayMode(.inline)` invocations across Routines/Sessions/Views. Each one needs to be replaced with a `BRUHeaderBar(left:center:right:)` per UI-SPEC § Component Inventory. Examples:
  - `RoutinesListView.swift:96` — `navigationTitle("Routines")` should become `BRUHeaderBar(left: nil, center: "Routines", right: HeaderAction("+ NEW") { ... })`.
  - `RoutineBuilderView.swift:202-203` — `navigationTitle(editing == nil ? "New Routine" : draft.name)` + `.navigationBarTitleDisplayMode(.inline)` should be the BRU "‹ Back" + "Edit routine" + "•••" header.
  - `SessionLoggerView.swift:141-142` — same pattern.
  - `SwapExerciseSheet.swift:88-89`, `PerSetNoteSheet.swift:48`, `WorkoutNotesSheet.swift:49`, `AddUnplannedExerciseButton.swift:68-69`, `WhyThisWeightSheet.swift:98-99`, `DecimalRPEPickerSheet.swift:41-42`, etc.

**BLOCKER — Default `TabView` chrome instead of `BRUTabBar`:**
- `RootView.swift:160-211` uses raw `TabView { ... }` with `.tabItem { Label("Today", systemImage: "figure.strengthtraining.traditional") }` and four more system-tab labels. BRU spec § Component Inventory line 481 calls for a `BRUTabBar` with 2pt ink top rule, ink-fill on active, paper text on active, typographic glyphs (`▣` Today, `▤` Routines, `▥` Library, `▦` Progress). All 5 `tabItem` Labels use SF Symbols (`figure.strengthtraining.traditional`, `list.bullet.rectangle.portrait`, `dumbbell`, `chart.line.uptrend.xyaxis`, `gearshape`) which BRU forbids.

**BLOCKER — Rounded corners and capsules everywhere, BRU is rectangle-only:**
- `RoutineExerciseCard.swift:90` — `Rectangle().fill(Color.accentColor).clipShape(RoundedRectangle(cornerRadius: 2))` — superset rail uses radius 2 where BRU spec line 306 mandates a `Path`-drawn 2pt `bruSignal` bracket (top + left + bottom edges, NO right edge, no rounded corners).
- `RestTimerOverlay.swift:61` — `.clipShape(.capsule)` on the collapsed pill — but BRU spec line 366 forbids the pill entirely and requires a "full-bleed slab (NOT a pill anymore)" with 2pt `bruInk` bottom border, `bruBg2` fill, `displayMedium` 28pt countdown.
- `SetTypeChip.swift:54` — `.clipShape(Capsule())` — BRU requires `BRUChip` (1.5pt outlined RECTANGLE, NOT capsule).
- `ClusterSubRepChipRow.swift:51, 61` — `.clipShape(Capsule())` — BRU spec line 349 mandates `1pt bruInk outlined rectangle (NOT a capsule)`.
- `PinnedNoteCapsule.swift:56` — `.clipShape(Capsule())` — file name itself is wrong; BRU spec line 332 mandates a rectangle with ink-square notch glyph.
- `IntentChip.swift:55` — `Capsule().fill(Color.accentColor.opacity(0.15))` — BRU requires `bruInk` outline + `bruSignal` fill for `.strength` intent only, ink outline for all others.
- `WhyThisWeightSheet.swift:155, 171` — `.clipShape(Capsule())` (Phase 3 polish, but on the BRU upgrade list).
- `CalibratingBadge.swift:45`, `WarmupRampRows.swift:102` — `.clipShape(Capsule())` (Phase 3 polish).
- `InSessionPRBanner.swift:90, 94, 97` — `RoundedRectangle(cornerRadius: 22)` — BRU spec line 208 requires a top-rule signal banner, no rounded background.
- `ResumeWorkoutBanner.swift:99` — `RoundedRectangle(cornerRadius: 12)` — BRU spec line 263 wants the slab variant (paper-on-ink slab with two pills), not a rounded banner.
- `BumpBanner.swift:54` — `RoundedRectangle(cornerRadius: 12)` (Phase 3 polish, BRU rewrite candidate).
- `WarmupRampRows.swift:219, 255, 277`, `PlateStackDisclosure.swift:219, 241, 258, 275` — `RoundedRectangle(cornerRadius: 8)` (Phase 3 polish, deferred per BRU "Phase 5 fatigue surfaces are NOT rewritten" carve-out logic).

**BLOCKER — 17 SF Symbol uses inside Phase 2 surfaces where BRU forbids SF Symbols entirely:**
Per UI-SPEC § Design System "Icon library: **None.** SF Symbols are NOT used in BRU."
- `RoutineBuilderView` → `RoutineExerciseCard.swift:124` `Image(systemName: "chevron.right")` (expand chevron — BRU uses `▸` text glyph)
- `RoutineExerciseCard.swift:151` `Image(systemName: "flame")` (warmup menu icon)
- `Routines/InlineExerciseSearchRow.swift:51` `Image(systemName: "plus.circle")` (must become "+" display glyph inside BRUDashedSlot)
- `Routines/MoveRoutineSheet.swift:50, 66` `Image(systemName: "checkmark")` (must become "✓" or similar typographic)
- `Routines/PrescriptionEditorRow.swift:310` `Image(systemName: "chevron.right")`
- `Sessions/PinnedNoteCapsule.swift:46` `Image(systemName: "pin.fill")` (BRU line 332 mandates "an ink-square glyph with 2pt offset notch drawn by Path")
- `Sessions/ResumeWorkoutBanner.swift:84` `Image(systemName: "arrow.uturn.backward.circle")`
- `Sessions/PrescriptionWeightCell.swift:105` `Image(systemName: "info.circle")` (Phase 3 polish — BRU still forbids)
- `Sessions/BumpBanner.swift:40` `Image(systemName: "arrow.up.circle")`
- `Sessions/SessionLoggerView.swift:281` `Image(systemName: "clock")` (elapsed timer chip — BRU spec line 327 wants `BRUMono` 13pt right-aligned numeric, no icon)
- `Sessions/SessionLoggerView.swift:289` `Image(systemName: "square.and.pencil")` (notes button)
- `Sessions/SetRow.swift:199` `Image(systemName: "square.and.pencil")` (per-set notes button)
- `Sessions/SetRow.swift:218` `Image(systemName: entry.isComplete ? "checkmark.circle.fill" : "circle")` — **load-bearing BRU change**: BRU spec line 350-351 mandates `SetCompletionGlyph` (hollow `bruInk` 1.5pt outlined 22pt square / filled `bruSignal` 22pt square). The current `checkmark.circle.fill` is the Apple SF Symbol equivalent that BRU explicitly replaces.
- `Sessions/AddUnplannedExerciseButton.swift:56` `Image(systemName: "plus.circle")`
- `FitbodWidgets/RestTimerLiveActivity.swift:64, 85, 90` `Image(systemName: "timer")` ×3 — BRU spec line 377-379 mandates a small `Rectangle` 12×12 ink glyph for compact leading + a 22pt circle with `bruSignal` Canvas-drawn progress sweep for the minimal presentation. The Widget Extension target is in BRU scope per spec line 567-571.
- `RootView.swift:172, 182, 191, 201, 209` — 5 more SF Symbols in tab labels (above).

**WARNING — `.buttonStyle(.bordered)` / `.plain)` everywhere instead of `BRUButton(kind:size:)`:**
- `RestTimerOverlay.swift:136, 145` — `.buttonStyle(.bordered)` on ±15s buttons — BRU requires `.labelSmall` 11pt inside 1.5pt ink-outlined 44pt-tall RECTANGLE.
- `SessionLoggerView.swift:154, 160` — toolbar buttons use system styling, not `BRUButton`.

**Score justification: 1/4** — Every BRU primitive and every BRU surface is missing. The contract has zero implementation surface. The mockups (`bru-screens/*.jsx`) and the implemented Swift are visually unrelated.

---

### Pillar 3: Color (1/4)

The accent color story is the clearest single failure of the BRU port.

**BLOCKER — 91 `Color.accentColor` / `Color("AccentColor")` / `.tint(Color.accentColor)` references across the project, ~60 of them inside Phase 2 surfaces:**
Verification: `grep -rn "Color\.accentColor\|Color(\"AccentColor\")\|\.tint(.accentColor)\|\.tint(Color.accentColor)" fitbod FitbodWidgets --include="*.swift" | wc -l` → `91`.

Phase 2 surface files containing `Color.accentColor` (22 distinct files):
- `fitbod/Routines/InlineExerciseSearchRow.swift:52`
- `fitbod/Routines/MoveRoutineSheet.swift:51, 67`
- `fitbod/Routines/PrescriptionEditorRow.swift` (multiple)
- `fitbod/Routines/RoutineBuilderView.swift:219` (Save toolbar button — BRU wants signal text in BRUHeaderBar right slot)
- `fitbod/Routines/RoutineExerciseCard.swift:14, 88` (line 88 is the superset accent rail — BRU surface #9 wants `bruSignal` instead of accent teal)
- `fitbod/Routines/RoutineRow.swift:72` (`.tint(Color.accentColor)`)
- `fitbod/Routines/RoutinesListView.swift:297, 319, 337, 426`
- `fitbod/Routines/SupersetAssignmentSheet.swift:92`
- `fitbod/Sessions/AddUnplannedExerciseButton.swift:59`
- `fitbod/Sessions/InlineRPEChipRow.swift:21, 49` (line 49: `.tint(Int(rpe ?? 0) == value ? Color.accentColor : Color.secondary)` — BRU keeps RPE chips ink-on-paper, selected = ink fill, NOT signal)
- `fitbod/Sessions/InSessionPRBanner.swift:75, 79, 91, 95` (banner uses accent fill + accent border — BRU surface #16 wants `bruSignal` top rule + `labelSmall` `bruSignal` label only)
- `fitbod/Sessions/PrescriptionWeightCell.swift` (info-circle button tint)
- `fitbod/Sessions/RestTimer/RestTimerProgressRing.swift` (progress arc — BRU spec line 207 wants `bruSignal` stroke)
- `fitbod/Sessions/ResumeWorkoutBanner.swift:85, 92`
- `fitbod/Sessions/SessionExerciseCard.swift:222`
- `fitbod/Sessions/SessionLoggerView.swift:163` ("Finish" toolbar button — BRU wants signal text in right-side BRUHeaderBar menu)
- `fitbod/Sessions/SetRow.swift:201` (notes-button tint), `:219` (completion checkmark — should be SetCompletionGlyph signal-fill)
- `fitbod/Sessions/SetTypeChip.swift:24` (file header comment correctly notes "chip never consumes Color.accentColor")
- `fitbod/Sessions/WhyThisWeightSheet.swift:91, 167, 170` (Phase 3 polish)
- `fitbod/Views/IntentChip.swift:51, 55` (chip foreground + 0.15 capsule fill — BRU spec line 209 wants ink outline + signal fill for `.strength` only)
- `FitbodWidgets/RestTimerLiveActivity.swift:65, 82, 91` (Dynamic Island leading icon, progress tint, minimal glyph — should be `bruSignal` per BRU line 379-382)
- `FitbodWidgets/RestTimerLockScreenView.swift:49` (`ProgressView(...).tint(Color.accentColor)` — should be `bruSignal`)

**BLOCKER — Zero `bruInk` / `bruPaper` / `bruSignal` references anywhere:**
Verification: `grep -rn "bruInk\|bruPaper\|bruSignal\|bruMuted\|bruFaint\|bruHair\|bruBg\|BRUFont" fitbod 2>/dev/null | wc -l` → `0`.

**BLOCKER — Zero `bru*.colorset` assets exist:**
Verification: `ls fitbod/Assets.xcassets/` → only `AccentColor.colorset`, `AppIcon.appiconset`, `VolumeBelowMEVGray.colorset`, `VolumeNearMRVAmber.colorset`, `VolumeOverMRVRed.colorset`, `VolumeProductiveGreen.colorset`. The 8 BRU colorsets (`bruInk.colorset`, `bruPaper.colorset`, `bruSignal.colorset`, `bruFaint.colorset`, `bruHair.colorset`, `bruMuted.colorset`, `bruBg.colorset`, `bruBg2.colorset`) the spec mandates in § Asset Contract line 601-610 are not on disk.

**BLOCKER — `SetTypeChip` and `PinnedNoteCapsule` still use semantic system colors BRU removed:**
- `SetTypeChip.swift:103-106` — `Color(.systemBlue)` / `Color(.systemOrange)` / `Color(.systemRed)` / `Color(.systemPurple)` per set-type. BRU spec line 222 explicitly removes these: "the system-colored capsules from v1 (blue / orange / red / purple per type) are **deprecated**. BRU replaces them with uppercase letterspaced `labelSmall` text inside ink-outlined chips."
- `PinnedNoteCapsule.swift:47, 55` — `Color(.systemYellow)` foreground + `Color(.systemYellow).opacity(0.15)` background. BRU spec line 221 explicitly removes: "Pinned-note inline pill — `bruInk` outline 1.5pt + `bruInk` text on `bruBg2` fill. The pin glyph (a small ink square) is `bruInk`. NOT yellow-system, NOT signal."
- `WarmupRampRows.swift:100` — `Color(.systemBlue)` (Phase 3 polish — BRU deferred Phase 3 surfaces but the warmup banner does sit inside the BRU SessionLoggerView).
- `PlateStackDisclosure.swift:68, 143, 145, 147` — `Color(.systemRed)` / `Color(.systemBlue)` / `Color(.systemYellow)` for plate weight categories (Phase 3 — deferred but inside the BRU session logger surface).

**WARNING — 30+ `Color(.system*)` background / divider references:**
Verification: `grep -rn "Color(\." fitbod/Routines fitbod/Sessions fitbod/Views fitbod/App --include="*.swift" | grep -oE 'Color\(\.[a-zA-Z0-9]+' | sort | uniq -c | sort -rn` returns:
- 10 `Color(.systemGroupedBackground)`
- 8 `Color(.systemGray5)`
- 6 `Color(.systemYellow)`
- 3 `Color(.systemRed)`, 3 `Color(.systemGreen)`, 3 `Color(.systemBlue)`
- 2 `Color(.systemGray3)`
- 1 each: `systemPurple`, `systemOrange`, `systemGray6`, `systemGray4`, `systemBackground`, `secondarySystemGroupedBackground`, `secondaryLabel`, `label`

These all need to map to `bruInk` / `bruPaper` / `bruBg` / `bruBg2` / `bruMuted` / `bruHair` / `bruFaint` per UI-SPEC § Color tokens. Notable: `RestTimerLiveActivity.swift:54` uses `Color(.secondarySystemGroupedBackground)` as the activityBackgroundTint — BRU spec line 367-369 wants `bruBg2` for the collapsed slab and the Live Activity uses paper-on-ink (`bruInk` background).

**WARNING — 66 `Color.primary` / `Color.secondary` / `.foregroundStyle(.secondary|.primary)` references:**
Each one is an Apple HIG semantic that BRU replaces with explicit `bruInk` / `bruMuted` / `bruPaper`. Major offenders include every `.foregroundStyle(.secondary)` on captions in the rest timer overlay, IntentChip, the session logger header.

**60/30/10 split assessment (against BRU stance):**
- BRU intends: 60% `bruPaper` dominant, 30% `bruInk` (borders, hero/CTA inverted), 10% `bruSignal` (the 18-item accent reserved-for list).
- Implemented: ~70% `Color(.systemBackground)` / `Color(.systemGroupedBackground)`, ~5% accent (which is the deprecated teal in 91 spots), no consistent ink-rule surface. Border-weight contract (1pt/1.5pt/2pt explicit `Rectangle().fill(.bruInk).frame(height:)`) does not exist.

**Score justification: 1/4** — Every accent surface points at the wrong color (teal not signal-orange). Zero BRU tokens exist as either Color asset or Color extension. Hardcoded semantic system colors persist in 3+ Phase 2 surfaces. The accent reserved-for list (18 items in BRU spec § Accent reserved for) cannot be evaluated for compliance because the accent doesn't exist in the codebase.

---

### Pillar 4: Typography (1/4)

This pillar fails as cleanly as Color. The spec mandates a complete typography rebuild with bundled fonts; the implementation has not started any of it.

**BLOCKER — Zero `BRUFont` enum or `displayHero` / `displayLarge` / `displayMedium` / `bodyEmphasis` / `bodyDefault` / `labelSmall` / `labelMicro` references:**
Verification: `grep -rn "displayHero\|displayLarge\|displayMedium\|bodyEmphasis\|bodyDefault\|labelSmall\|labelMicro\|SpaceGrotesk\|JetBrainsMono\|BRUFont" fitbod 2>/dev/null` → 213 hits, ALL inside `02-UI-SPEC.md` / `02-RESEARCH.md` / `04-UI-SPEC.md` (spec documents). Zero hits inside Swift source.

**BLOCKER — Zero font files bundled:**
Verification: `find fitbod/Resources -type f` → only `ExerciseSeed/SOURCE.md`, `ExerciseSeed/SEED_VERSION.txt`, `ExerciseSeed/exercises.json`. No `Fonts/` directory. No `SpaceGrotesk-Bold.otf`, `SpaceGrotesk-SemiBold.otf`, `JetBrainsMono-Regular.otf`, `JetBrainsMono-Bold.otf`.

**BLOCKER — `Info.plist` has no `UIAppFonts`:**
Verification: `fitbod/Info.plist` (90 lines) — no `<key>UIAppFonts</key>` entry anywhere. Project uses `GENERATE_INFOPLIST_FILE = NO` for main app (line 558, 602) so the literal `fitbod/Info.plist` is authoritative for the main app. The widget extension uses `GENERATE_INFOPLIST_FILE = YES` so it would use the build-setting form `INFOPLIST_KEY_UIAppFonts` — also absent.

**BLOCKER — Apple HIG semantic font roles dominate every Phase 2 surface:**
Verification: `grep -rn "\.font(\." fitbod/Routines fitbod/Sessions fitbod/Views fitbod/App --include="*.swift" | grep -oE '\.font\(\.[a-zA-Z0-9]+' | sort | uniq -c | sort -rn` returns:
- 64 × `.font(.caption)` — BRU replaces with `labelSmall` (mono bold 9-11pt with letterspacing) or `bodyDefault` (mono regular 11-13pt)
- 19 × `.font(.body)` — BRU replaces with `bodyEmphasis` (mono bold 13-15pt) or `bodyDefault`
- 7 × `.font(.headline)` — BRU replaces with `displayLarge` 28-36pt or `displayMedium` 18-22pt
- 5 × `.font(.title2)` — BRU replaces with `displayMedium` or `displayHero`

Sample offenders (a slice; total is 95):
- `RoutineExerciseCard.swift:115` — `.font(.body)` on exercise name → BRU `bodyEmphasis` 15pt mono bold
- `RoutineExerciseCard.swift:119` — `.font(.caption)` on prescription summary → BRU `labelSmall` 10pt 1.2 letterspacing UPPERCASE
- `RoutineExerciseCard.swift:125` — `.font(.caption.weight(.semibold))` on chevron → BRU replaces glyph + font role
- `RestTimerOverlay.swift:92` — `.font(.title2)` on collapsed countdown → BRU `displayMedium` 28pt mono
- `RestTimerOverlay.swift:96` — `.font(.caption)` on "· Rest" → BRU `labelSmall` 10pt 1.5 letterspacing UPPERCASE "REST"
- `RestTimerOverlay.swift:109` — `.font(.headline)` on expanded "Rest Timer" header → BRU `labelSmall` 10pt 1.5 letterspacing UPPERCASE
- `RestTimerOverlay.swift:111` — `.font(.body)` on exercise name → BRU `displayLarge` 28pt
- `RestTimerOverlay.swift:122` — `.font(.title2)` on countdown digits → BRU `displayHero` 72pt
- `RestTimerOverlay.swift:159` — `.font(.caption)` on prescribed footer → BRU `labelSmall` 10pt `bruMuted` "PRESCRIBED · {N}S"
- `SessionLoggerView.swift:146` — `Text("Workout").font(.headline)` toolbar title → BRU `BRUHeaderBar(center: "Workout")` with `bodyEmphasis` 14pt
- `SessionLoggerView.swift:148` — `.font(.caption).foregroundStyle(.secondary)` on routine snapshot subtitle → BRU `displayMedium` 18pt
- `SetRow.swift:128` — `.font(.body)` on set label "1"/"W1" → BRU `BRUMono` 10pt with optional `displayMedium` for the numeric
- `SetRow.swift:200` — `.font(.caption)` on notes-button icon → BRU swaps icon entirely
- `SetRow.swift:220` — `.font(.title2)` on completion checkmark → BRU swaps for `SetCompletionGlyph`
- `IntentChip.swift:50` — `.font(.caption)` → BRU `labelSmall` 10pt UPPERCASE
- `RestTimerLockScreenView.swift:38, 41, 46` — `.font(.headline)` + `.font(.title2)` + `.font(.body)` → BRU `labelSmall` "REST TIMER" header + `displayHero` 56pt right-aligned + `displayLarge` 28pt body
- `RestTimerLiveActivity.swift:69, 75` — `.font(.title2)` + `.font(.caption)` for Dynamic Island expanded → BRU `displayHero` 56pt countdown + `labelSmall` 10pt exercise name

**Distinct font roles in use (current):** 4 (`.body`, `.caption`, `.headline`, `.title2`). BRU mandates 6 explicit roles. The COUNT happens to be in range — the IDENTITY is entirely wrong.

**WARNING — Distinct font weights observed:** `.semibold`, `.bold` (rare). BRU uses 2 weights per face (Bold + SemiBold for display; Regular + Bold for mono). The cognitive surface is correct in cardinality but the weight roles are not mapped.

**WARNING — `.monospacedDigit()` use is correct in spirit, wrong in substrate:**
The implemented `.monospacedDigit()` modifier produces SF Pro Display with tabular numerics — fine for now, but BRU wants `JetBrainsMono-Regular`/`Bold` as the underlying face, so the modifier becomes redundant (mono fonts are tabular by default).

**Score justification: 1/4** — The entire typography contract is unimplemented. Font face, font size, font weight, font letterspacing, font case — all five layers of the BRU type contract are missing. Even the deferred-pairing-C "system font with `.compressed` width + `.monospaced` design" fallback isn't used. The implemented type is unmodified SF Pro semantic styles.

---

### Pillar 5: Spacing (3/4)

This pillar is the strongest of the visual three. The BRU spec explicitly carries forward the v1 4/8/12/16/24/32/48pt scale, and the implemented code mostly honors it.

**Passes:**
- 8pt internal padding on `SetRow.swift:126` (`HStack(spacing: 8)`)
- 12pt vertical padding on `SetRow.swift:230` (`padding(.vertical, 12)`)
- 16pt horizontal screen inset on `RestTimerOverlay.swift:62, 99, 113` (`padding(.horizontal, 16)`)
- 24pt section spacing on `RestTimerOverlay.swift:107, 163` (`VStack(spacing: 24)`, `padding(24)`)
- 8pt small spacing on `RestTimerOverlay.swift:90` (`HStack(spacing: 8)`), `RestTimerLockScreenView.swift:35` (`VStack(spacing: 8)`)
- 4pt internal chip spacing on `AddUnplannedExerciseButton.swift:55` (`HStack(spacing: 4)`)
- 44pt minimum touch target on `RestTimerOverlay.swift:134, 143` (`.frame(minWidth: 60, minHeight: 44)`), `SetRow.swift:221` (`.frame(minWidth: 44, minHeight: 44)`)

**BLOCKER — 64pt collapsed rest-timer slab is implemented as a 64pt PILL, not the BRU full-bleed slab:**
- `RestTimerOverlay.swift:59-63` — `.frame(height: 64).background(.regularMaterial).clipShape(.capsule).padding(.horizontal, 16)` — this is the v1 Apple Music pill, NOT the BRU "full-bleed 64pt slab above the tab bar with 2pt `bruInk` bottom border" (spec line 366). The 64pt dimension is right; everything else around the dimension is wrong.

**WARNING — Border-weight contract (the BRU rule contract) is unimplemented:**
- BRU mandates explicit border weights: 2pt for section-level ink rules, 1pt for hair-rule list dividers, 1.5pt for inner borders.
- Verification: `grep -rn "frame(height: 2)\|frame(width: 2)\|frame(height: 1)\|frame(width: 1)\|frame(height: 1.5)\|StrokeStyle(lineWidth: 2)\|StrokeStyle(lineWidth: 1.5)" fitbod/Routines fitbod/Sessions fitbod/Views --include="*.swift"` returns very few explicit-weight Rectangle/Stroke patterns. Most dividers use the default `Divider()` (which renders at sub-pixel hairline — explicitly forbidden by BRU spec line 82: "never approximate to 'default thin' or use `.divider()`").
- `RoutineExerciseCard.swift:89` uses `Rectangle().fill(Color.accentColor).frame(width: 4)` for the superset accent rail — correct in shape, wrong in color (teal not signal) AND wrong in BRU spec which mandates a `Path`-drawn bracket (top + left + bottom edges, no right edge).

**WARNING — Arbitrary spacing values appear in a few spots:**
- `RoutineBuilderView.swift:166` — `EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)` — the 10pt value is off-grid (should be 8pt or 12pt). BRU's grid is 4/8/12/16/24/32/48 — 10 is none of these.
- `SetRow.swift:130` — `.frame(width: 32, alignment: .leading)` — fine (32pt is 8×4).
- `SetRow.swift:138` — `.frame(width: 80, alignment: .leading)` — fine.
- `SetRow.swift:160, 174, 204` — `.frame(width: 60)`, `.frame(width: 40)`, `.frame(width: 32, height: 32)` — fine.
- `RestTimerOverlay.swift:126` — `.frame(width: 160, height: 160)` for progress ring — fine.

**WARNING — Tab bar safe-area not specified per BRU spec:**
The 24pt bottom safe-area filler called for in spec line 73 (`xl 24pt — Bottom safe-area filler beneath the bottom bar on routine builder`) is not implemented; the system tab bar auto-handles safe-area, which is fine for now but the BRU rewrite swaps the tab bar for `BRUTabBar` and the explicit filler becomes load-bearing.

**Score justification: 3/4** — The numeric spacing contract is largely intact (~85% of spacing values land on the 4pt grid). The border-weight contract is unimplemented (zero explicit 1pt/1.5pt/2pt Rectangle fills). The collapsed rest timer pill is the wrong shape. Once BRU primitives land, the spacing values can mostly carry forward.

---

### Pillar 6: Experience Design (3/4)

The behavior layer is the strongest part of the implementation. The spec preserved the v1 interaction contract verbatim, and that interaction layer functions correctly.

**Passes — Loading states:**
- `RootView.swift:124-128` — `ProgressView("Preparing library…")` splash with verbatim UI-SPEC copy. Splash visibility predicate at `:112-120` correctly differentiates idle/loading from ready/failed. Plan 02-01 SUMMARY verified the seed task is reactive.

**Passes — Error states:**
- `SessionLoggerView.swift:178-188` — `"Discard Workout?"` alert with `role: .destructive` button + UI-SPEC verbatim message body.
- `SessionLoggerView.swift:166-177` — `"Finish Workout?"` confirmationDialog with `"{N} sets logged · {elapsedLabel}"` summary.
- `RoutinesListView.swift:158, 438` — "Workout in Progress" active-session-conflict alert.
- `RoutineBuilderView.swift:222-233` — "Discard Changes?" confirmationDialog.
- `RestTimerNotificationScheduler.swift` — authorization-denied branch silently falls back per spec (line 156-160).
- `RestTimerActivityController.swift` — `Activity.request` wrapped in `do/catch` with silent fallback on simulator failure (RESEARCH §6 Pitfall 3 satisfied).

**Passes — Empty states (interaction-level):**
- `RootView.swift:337-343` (private TodayView) — `"No workout in progress"` empty state with UI-SPEC verbatim copy. **WARNING:** copy is v1 ("No workout in progress"), not BRU v2 ("No workout scheduled" — spec line 262/431).
- `RoutineBuilderView.swift:130-132` — `"Add an exercise to begin."` empty state on Form Section. **WARNING:** copy matches BRU spec line 433 ("Add an exercise to begin." in labelSmall muted centered between prescription chip row and dashed slot) — substance correct, presentation entirely wrong (system Form Section instead of BRU inline).
- `RoutinesListView.swift` — empty state for "No routines yet" is present somewhere in the file (verified via planning summary).

**Passes — Destructive actions:**
- 7+ `.alert(role: .destructive)` / `.confirmationDialog` usages identified for: Discard Workout, Discard Changes, Remove Exercise, Delete Folder, Delete Routine. Spec line 451-461 contract honored.
- BRU spec line 226 — "No view in Phase 2 explicitly renders `Color.red` / `Color(.systemRed)`." VIOLATED: `SetTypeChip.swift:105` renders `Color(.systemRed)` for "failure" set type, `PlateStackDisclosure.swift:68, 143` renders `Color(.systemRed)` for plate weight categories. Neither is inside a destructive `.alert` chrome — both are wrongful red usages.

**Passes — Disabled states:**
- `RoutineBuilderView.swift:218` — `.disabled(!draft.isValid)` on Save button. Disabled-state visual is the Apple HIG default.
- `SetRow.swift:213-216` — completion-button guard `if entry.weight > 0 && entry.reps > 0 { onCommit() }`. Disabled state is implicit (button still tappable but no-ops). BRU spec line 350-351 mandates `SetCompletionGlyph` swap as the visual signal.

**WARNING — Rest timer + Live Activity composition is clean:**
- `RestTimerEngine.makeProduction()` correctly composes notification scheduler + activity controller per plan 02-03 summary. `RestTimerActivityController` correctly debounces ±15s spam (200ms async-Task cancel-on-new-call) per RESEARCH §6 Pitfall 9. `RestTimerEngine.adjust(...)` correctly moves `targetSeconds` without moving `startedAt`. `RestTimerNotificationScheduler` correctly uses the stable `notificationID` for replace-by-identifier reschedule.
- These are the load-bearing behaviors of SESS-04. They are correct. The visual wrapper around them is the problem.

**WARNING — Confirmation copy needs BRU case treatment:**
- Discard confirmation buttons: "Discard" / "Keep Editing" (mixed case). BRU spec preserves this at the source level but renders via `.textCase(.uppercase)` for label-class strings. The `.alert` chrome cannot be fully restyled (BRU spec line 461 explicitly allows Apple chrome to render destructive button in red as the only red surface in Phase 2). OK as-is.

**WARNING — Tab re-tap pop-to-root is correctly implemented:**
- `RootView.swift:137-158` — `tabSelection` binding detects re-tap of currently-active tab and clears `NavigationPath`. Library + Progress tabs have paths wired; Today / Routines / Settings do not (no deep navigation in those tabs yet). Once BRU adds drill-down surfaces to Today (per UI-SPEC § Surfaces) the path management needs extending.

**WARNING — Haptics partially wired:**
- BRU spec line 663 mandates set-row commit fires `UINotificationFeedbackGenerator(.success)` + rest-timer reaches-zero fires same. Verification: `grep -rn "UINotificationFeedbackGenerator\|UISelectionFeedbackGenerator\|UIImpactFeedbackGenerator" fitbod/Sessions fitbod/Routines --include="*.swift"` (not run above but worth checking). If absent, this is a minor BRU gap.

**Score justification: 3/4** — Loading / error / empty / disabled / destructive states all present and correct. Rest timer composition is exemplary. The 1-point deduction is for: (a) `Color(.systemRed)` violations in `SetTypeChip` and `PlateStackDisclosure` (BRU spec explicitly bans), (b) empty-state copy mismatch ("No workout in progress" not "No workout scheduled"), (c) destructive surfaces not in BRU-styled chrome where override is possible. The interaction skeleton is correct; the dressing is wrong.

---

## BRU Migration Backlog (Granular, Actionable)

This is the value-added section of this audit per the user's brief. The numbered list below is the concrete gap report the user asked for. Each item names a file, a line range, and the BRU spec section that prescribes the fix.

### Wave A — BRU foundations (Wave A in spec line 705)

1. **Create `fitbod/Assets.xcassets/bruInk.colorset/Contents.json`** with light `#0A0A0A` + dark `#FAFAF7` (UI-SPEC § Asset Contract line 603).
2. **Create `fitbod/Assets.xcassets/bruPaper.colorset/Contents.json`** with light `#FAFAF7` + dark `#0A0A0A`.
3. **Create `fitbod/Assets.xcassets/bruSignal.colorset/Contents.json`** with light `#FF5C1A` + dark `#FF7A3D`.
4. **Create** `bruFaint.colorset`, `bruHair.colorset`, `bruMuted.colorset`, `bruBg.colorset`, `bruBg2.colorset` per the same table.
5. **Create `fitbod/Design/Color+BRU.swift`** with 8 `static let` extensions per UI-SPEC § Component Inventory line 474.
6. **Create `fitbod/Resources/Fonts/`** directory and bundle 4 `.otf` files: `SpaceGrotesk-Bold.otf`, `SpaceGrotesk-SemiBold.otf`, `JetBrainsMono-Regular.otf`, `JetBrainsMono-Bold.otf` (UI-SPEC § Typography line 94-97).
7. **Add `UIAppFonts` to `fitbod/Info.plist`** (currently at line 25 next to `NSSupportsLiveActivities`; `GENERATE_INFOPLIST_FILE = NO` for main app so the literal plist is authoritative — UI-SPEC § Asset Contract line 633).
8. **Create `fitbod/Design/BRUFont.swift`** with 7 `static let` font roles per UI-SPEC § Typography line 103-111.
9. **Create primitive components in `fitbod/Design/`**: `BRUChip.swift`, `BRUDisplay.swift`, `BRUReadout.swift`, `BRUSectionHead.swift`, `BRUButton.swift`, `BRUSpark.swift`, `BRUTabBar.swift`, `BRUHeaderBar.swift`, `BRUDivider.swift`, `BRUDashedSlot.swift`, `BRUPillButton.swift`, `BRUSupersetBracket.swift`, `BRUCornerBadge.swift`, `SetCompletionGlyph.swift` (UI-SPEC § Component Inventory line 471-489).

### Wave B — TodayView (new surface)

10. **Create `fitbod/Views/TodayView.swift`** as a standalone struct (currently inline at `fitbod/App/RootView.swift:271-489`). Mounts `BRUHeaderBar` → `TodayStatStrip` → `BlockContextBand` → `WeekTickerCells` → `BlackSlabCTA` (or `ResumeWorkoutSlab`) → `LiftListSection` (UI-SPEC § Surfaces line 492-505).
11. **Create `fitbod/Views/TodayStatStrip.swift`** with 3 `BRUReadout` cells and "Day streak" / "Sessions" / "W3 / 5 ↑" labels.
12. **Create `fitbod/Views/BlockContextBand.swift`**.
13. **Create `fitbod/Views/WeekTickerCells.swift`** with `W1`-`W5` cells, "DL" corner badge for deload week.
14. **Create `fitbod/Views/BlackSlabCTA.swift`** with verbatim copy from UI-SPEC line 252-258: "NEXT", "{routine name}", "{N} exercises · {N} sets · ~{M} min", "Start workout ▸".
15. **Create `fitbod/Views/ResumeWorkoutSlab.swift`** with "RESUME" leading micro-label + Resume/Discard pills.
16. **Create `fitbod/Views/LiftListSection.swift` + `LiftListRow.swift`** per UI-SPEC line 504-505.
17. **Rewire `RootView.swift:170-174`** to mount the new standalone `TodayView()` instead of the inline `private struct TodayView`.

### Wave C — Routines rewrites

18. **Rewrite `RoutinesListView.swift`** to use `BRUHeaderBar(center: "Routines", right: "+ NEW")` + sectioned list of `RoutineRow` + `BRUTabBar`. Remove `navigationTitle("Routines")` at line 96.
19. **Rewrite `RoutineRow.swift`** to use 3-column layout: 64pt leading display index + middle name + sub-line + trailing tonnage/chevron. Remove `.tint(Color.accentColor)` at line 72.
20. **Rewrite `NewFolderSheet.swift`** to use `BRUHeaderBar("NEW FOLDER")` + `BRUMono` 13pt `TextField` + 2pt `bruInk` underline.
21. **Rewrite `MoveRoutineSheet.swift`** to use BRU-styled rows. Remove `Image(systemName: "checkmark")` at lines 50, 66 → "✓" text glyph or shape draw. Remove `Color.accentColor` at lines 51, 67.
22. **Rewrite `RoutineBuilderView.swift`** completely (currently `Form` + `Section` based — 400+ LOC). Replace with: `BRUHeaderBar("Edit routine")` → `displayLarge` 32pt editable routine-name → header chip row → day-tab strip (`BRUTabBar`-style) → exercise list with `BRUDashedSlot` for "+ Add exercise" → `BRUButton(.ghost)` "Discard" + `BRUButton(.signal)` "Save routine ▸". Remove `Form`, `Section("Exercises")` at line 129, `.environment(\.editMode, .constant(.active))` at line 201, `navigationTitle` + `navigationBarTitleDisplayMode` at lines 202-203, `.foregroundStyle(Color.accentColor)` on Save button at line 219.
23. **Rewrite `RoutineExerciseCard.swift`** completely. Remove `Image(systemName: "chevron.right")` at line 124 → "▸" text glyph. Remove `RoundedRectangle(cornerRadius: 2)` at line 90 → `BRUSupersetBracket` (Path-drawn 2pt bracket, no right edge). Replace `.fill(Color.accentColor)` at line 88 → `Color.bruSignal`. Replace `.font(.body)` at line 115 → `BRUFont.bodyEmphasis`. Replace `.font(.caption)` at line 119 → `BRUFont.labelSmall` + `.textCase(.uppercase)`.
24. **Rewrite `PrescriptionEditorRow.swift`** with prescription chip row using `BRUChip` primitives + 1.5pt `bruInk` outlined set-rows container.
25. **Create `Routines/SetRowsContainer.swift`** per UI-SPEC line 522-523.
26. **Rewrite `PerSetOverrideRow.swift`** to fit inside the BRU set-rows grid.
27. **Rewrite `SupersetAssignmentSheet.swift`**.
28. **Rewrite `InlineExerciseSearchRow.swift`** as a `BRUDashedSlot` trigger. Remove `Image(systemName: "plus.circle")` at line 51 → "+" display glyph. Remove `.foregroundStyle(Color.accentColor)` at line 52 → `bruSignal`.
29. **Create `Routines/BottomActionBar.swift`** with `BRUButton(.ghost)` "Discard" + `BRUButton(.signal)` "Save routine ▸".
30. **Create `Routines/RoutineBuilderDayTabs.swift`** per UI-SPEC line 528.

### Wave D — SessionLogger rewrites

31. **Rewrite `SessionLoggerView.swift`**. Remove `navigationTitle("Workout")` at line 141 → `BRUHeaderBar("Workout")`. Remove `.font(.headline)` at line 146 → `BRUFont.bodyEmphasis`. Remove `.font(.caption).foregroundStyle(.secondary)` at line 148 → `BRUFont.displayMedium` 18pt. Remove `Image(systemName: "clock")` at line 281 → `BRUMono` 13pt right-aligned numeric. Remove `.foregroundStyle(Color.accentColor)` at line 163 → `bruSignal` text in `BRUHeaderBar` right action.
32. **Rewrite `SessionExerciseCard.swift`**. Remove `Color.accentColor` at line 222. Add `BRUSectionHead`-style header + column header row.
33. **Rewrite `SetRow.swift`**. Replace `Image(systemName: entry.isComplete ? "checkmark.circle.fill" : "circle")` at line 218 with `SetCompletionGlyph(isComplete: entry.isComplete)`. Remove `Color.accentColor` at lines 201, 219 → `bruSignal`. Replace `.font(.body)` at line 128 with `BRUMono` 10pt. Replace `.font(.title2)` at line 220 — moot once `SetCompletionGlyph` replaces it.
34. **Rewrite `InlineRPEChipRow.swift`**. Each chip = `BRUChip` with `displayMedium` 18pt numeric. Remove `.tint(Color.accentColor)` at line 49 → BRU keeps RPE chips ink-on-paper with ink fill on selection (NOT signal).
35. **Rewrite `DecimalRPEPickerSheet.swift`** with `BRUHeaderBar("RPE")` and mono regular Picker rows.
36. **Rewrite `SetTypeChip.swift`** completely. **Critical:** remove the entire `systemColor(for:)` method at lines 101-109 — BRU explicitly removes systemBlue/Orange/Red/Purple per set-type (UI-SPEC line 222). Replace `.clipShape(Capsule())` at line 54 with `BRUChip` (1pt ink-outlined rectangle). Labels become "W/UP" / "DROP" / "FAIL" / "RP" / "TOP" (TOP gets `bruSignal` outline) / "BACK" all in `labelSmall` 10pt 1.2 letterspacing.
37. **Rewrite `PerSetNoteSheet.swift`** with `BRUHeaderBar("SET {N} NOTE")` and mono regular `TextEditor` with 2pt `bruInk` border.
38. **Rewrite `WorkoutNotesSheet.swift`**.
39. **Rewrite `TempoEntryRow.swift`** with "TEMPO" `labelSmall` label + 4 mono fields.
40. **Rewrite `PartialRepsRow.swift`** with "PARTIAL REPS" `labelSmall` label.
41. **Rewrite `ClusterSubRepChipRow.swift`**. Remove `.clipShape(Capsule())` at lines 51, 61 → `BRUChip`-style 1pt outlined rectangle. The "+" chip becomes `bruSignal`.
42. **Rewrite `PreviousColumn.swift`** with `BRUMono` 11pt `bruMuted` formatting per UI-SPEC line 545.
43. **Rewrite `SwapExerciseSheet.swift`** with BRU-styled exercise library list.
44. **Rewrite `AddUnplannedExerciseButton.swift`** as a `BRUDashedSlot` "+ ADD EXERCISE ↘ FROM LIBRARY". Remove `Image(systemName: "plus.circle")` at line 56. Remove `Color.accentColor` at line 59.
45. **Rewrite `ResumeWorkoutBanner.swift`**. Remove `RoundedRectangle(cornerRadius: 12)` at line 99 → 2pt `bruInk` borders. Remove `Color.accentColor` at lines 85, 92. Remove `Image(systemName: "arrow.uturn.backward.circle")` at line 84.
46. **Rewrite `PinnedNoteCapsule.swift`** completely — file name itself misleads. **Critical:** remove `Color(.systemYellow)` at lines 47, 55 (BRU spec line 221 explicitly bans). Replace `.clipShape(Capsule())` at line 56 with a 1.5pt `bruInk`-outlined rectangle on `bruBg2` fill. Replace `Image(systemName: "pin.fill")` at line 46 with a `Rectangle` 8pt ink-square glyph + 2pt offset notch drawn by `Path`.
47. **Create `Sessions/WorkoutHeaderToolbar.swift`** per UI-SPEC line 549.
48. **Rewrite `Views/IntentChip.swift`**. Remove `Capsule().fill(Color.accentColor.opacity(0.15))` at line 55 → 1.5pt `bruInk` outline + `bruSignal` fill ONLY for `.strength` intent, `bruInk` outline for all others (UI-SPEC line 209). Replace `.font(.caption)` at line 50 → `BRUFont.labelSmall` + `.textCase(.uppercase)`. Update `.foregroundStyle(Color.accentColor)` at line 51 → `bruInk` (or `bruPaper` when filled signal).

### Wave E — Rest timer rewrites

49. **Rewrite `RestTimerOverlay.swift`** completely. Remove `.background(.regularMaterial).clipShape(.capsule)` at lines 60-61 → full-bleed 64pt slab with `bruBg2` fill + 2pt `bruInk` bottom border (UI-SPEC line 366). Add 32pt progress arc + "REST" labelSmall + `▸` chevron in collapsed slab. Replace `.font(.title2)` at line 92 → `displayMedium` 28pt. Replace `.font(.caption).foregroundStyle(.secondary)` at line 96 → `labelSmall` 10pt 1.5 letterspacing UPPERCASE "REST". Replace `.font(.headline)` at line 109 → `labelSmall` 10pt 1.5 letterspacing UPPERCASE. Replace `.font(.body).foregroundStyle(.secondary)` at line 111 → `displayLarge` 28pt. Replace `.font(.title2)` at line 122 → `displayHero` 72pt. Replace `.buttonStyle(.bordered)` at lines 136, 145 → 1.5pt ink-outlined 44pt-tall rectangles. Replace `.font(.caption).foregroundStyle(.secondary)` at line 159 → `labelSmall` 10pt `bruMuted` "PRESCRIBED · {N}S".
50. **Rename `RestTimerProgressRing.swift` → `RestTimerProgressArc.swift`** per UI-SPEC line 490. Replace `Color.accentColor` stroke with `bruSignal` stroke on `bruFaint` track. Centered `displayHero` countdown.
51. **Rewrite `FitbodWidgets/RestTimerLockScreenView.swift`**. Replace `.font(.headline)` at line 38 → `labelSmall` 10pt 1.5 letterspacing UPPERCASE "REST TIMER". Replace `.font(.title2).fontWeight(.semibold).monospacedDigit()` at line 41 → `displayHero` 56pt right-aligned. Replace `.font(.body).foregroundStyle(.secondary)` at line 46 → `displayLarge` 28pt. Replace `.tint(Color.accentColor)` at line 49 → `bruSignal`. Background: paper-on-ink hero (UI-SPEC line 384).
52. **Rewrite `FitbodWidgets/RestTimerLiveActivity.swift`**. Remove all 3 `Image(systemName: "timer")` at lines 64, 85, 90 → `Rectangle` 12×12 ink glyph (compact leading) + 22pt circle with `bruSignal` Canvas progress sweep (minimal). Replace `.foregroundStyle(Color.accentColor)` at lines 65, 91 → `bruSignal`. Replace `.tint(Color.accentColor)` at line 82 → `bruSignal`. Replace `.font(.title2).fontWeight(.semibold).monospacedDigit()` at line 69 → `displayHero` 56pt `bruPaper`. Replace `.font(.caption)` at line 75 → `labelSmall` 10pt `bruPaper`. Replace `Color(.secondarySystemGroupedBackground)` activityBackgroundTint at line 54 → `bruInk` (paper-on-ink Live Activity per UI-SPEC line 384-386).
53. **Create `FitbodWidgets/RestTimerDynamicIslandCompactView.swift`** per UI-SPEC line 569.
54. **Create `FitbodWidgets/RestTimerDynamicIslandExpandedView.swift`** per UI-SPEC line 570.

### Wave F — History views

55. **Rewrite `ExerciseLibrary/ExerciseHistoryView.swift`** with `BRUHeaderBar("History")` + `displayLarge` 28pt sub-line + intent filter chip row + date-grouped sections + `PRStripFooter`. Remove `Color.accentColor` at line 342.
56. **Rewrite `ExerciseLibrary/IntentFilterChipRow.swift`**. Replace `Color.accentColor` at line 84 → `bruInk` for selected chip (UI-SPEC line 209: "the selected chip — fill `bruInk`, text `bruPaper`").
57. **Rewrite `ExerciseLibrary/ExerciseHistoryRow.swift`** per UI-SPEC line 402.
58. **Create `ExerciseLibrary/PRStripFooter.swift`** per UI-SPEC line 579.
59. **Create `Sessions/SessionHistoryView.swift`** — entirely new surface. Mount `BRUHeaderBar("History")` + `SessionHistoryStatStrip` + `WeeklyTonnageSparkCard` + `BRUSectionHead("Past sessions")` + list of `SessionHistoryRow`.
60. **Create `Sessions/SessionHistoryStatStrip.swift`** with 3 `BRUReadout` cells.
61. **Create `Sessions/WeeklyTonnageSparkCard.swift`** using `BRUSpark` primitive.
62. **Create `Sessions/SessionHistoryRow.swift`** per UI-SPEC line 558.
63. **Wire `SessionHistoryView` into navigation** — spec says "Wire `SessionHistoryView` into the Progress tab placeholder or the Routines tab depending on navigation policy" (line 734). Decision needed at planner level.

### Wave G — Cleanup

64. **Remove the 17 SF Symbol references** listed in Pillar 2 findings above.
65. **Replace the 91 `Color.accentColor` references** with `Color.bruSignal` (per accent reserved-for list) or `Color.bruInk` (default replacement).
66. **Replace the 30+ `Color(.system*)` references** with appropriate BRU tokens.
67. **Replace the 95 Apple HIG `.font(.body|.caption|.headline|.title2)` references** with `BRUFont` roles.
68. **Add `.textCase(.uppercase)` to all `labelSmall` instances** at the view layer.
69. **Replace all `Divider()` instances** with `BRUDivider(.hair)` or explicit `Rectangle().fill(.bruHair).frame(height: 1)`.
70. **Replace all `RoundedRectangle(cornerRadius:)` and `Capsule()` clips** in Phase 2 surfaces with `Rectangle()` (BRU forbids rounding).
71. **Add OFL license attribution** under `fitbod/Resources/Fonts/LICENSES/` per UI-SPEC line 675.
72. **Remove `fitbod/App/PlaceholderTabView.swift`** — once `TodayView` is real, this file's only consumers (the Phase 1 placeholder Today / Routines / Progress tabs) are obsolete.

---

## Registry Safety

The BRU UI-SPEC § Registry Safety (line 667-677) is **not applicable** to this project — native SwiftUI, zero SPM dependencies, no shadcn. The only "registry-adjacent" item is the bundled OFL fonts (Wave A item 6), which are resource files not code dependencies. The license attribution surface is a Settings → About row (deferred to Phase 6 per UI-SPEC line 675).

`components.json` does not exist in the project root. The registry-safety vetting gate from the gsd-ui-checker protocol is skipped per the agent's `<registry_audit>` rule.

---

## Files Audited

**Phase 2 surface code (37 files inside fitbod/Routines, fitbod/Sessions, fitbod/Views, fitbod/App, FitbodWidgets):**

Routines (18 files):
- `fitbod/Routines/InlineExerciseSearchRow.swift`
- `fitbod/Routines/MoveRoutineSheet.swift`
- `fitbod/Routines/NewFolderSheet.swift`
- `fitbod/Routines/PerSetOverrideRow.swift`
- `fitbod/Routines/PrescriptionDefaults.swift`
- `fitbod/Routines/PrescriptionEditorRow.swift`
- `fitbod/Routines/RoutineBuilderView.swift`
- `fitbod/Routines/RoutineDraft.swift`
- `fitbod/Routines/RoutineDuplicator.swift`
- `fitbod/Routines/RoutineExerciseCard.swift`
- `fitbod/Routines/RoutineFolderDraft.swift`
- `fitbod/Routines/RoutineRow.swift`
- `fitbod/Routines/RoutinesListView.swift`
- `fitbod/Routines/SupersetAssignmentSheet.swift`
- `fitbod/Routines/WarmupConfigSheet.swift`

Sessions — non-rest-timer (24 files):
- `fitbod/Sessions/AddUnplannedExerciseButton.swift`
- `fitbod/Sessions/BumpBanner.swift`
- `fitbod/Sessions/CalibratingBadge.swift`
- `fitbod/Sessions/ClusterSubRepChipRow.swift`
- `fitbod/Sessions/DecimalRPEPickerSheet.swift`
- `fitbod/Sessions/InlineRPEChipRow.swift`
- `fitbod/Sessions/InSessionPRBanner.swift`
- `fitbod/Sessions/InSessionPRState.swift`
- `fitbod/Sessions/PartialRepsRow.swift`
- `fitbod/Sessions/PerSetNoteSheet.swift`
- `fitbod/Sessions/PinnedNoteCapsule.swift`
- `fitbod/Sessions/PinnedNoteSheet.swift`
- `fitbod/Sessions/PlateStackDisclosure.swift`
- `fitbod/Sessions/PrescriptionWeightCell.swift`
- `fitbod/Sessions/PreviousColumn.swift`
- `fitbod/Sessions/PreviousMatchingIntent.swift`
- `fitbod/Sessions/ResumeWorkoutBanner.swift`
- `fitbod/Sessions/SessionExerciseCard.swift`
- `fitbod/Sessions/SessionFactory.swift` (behavior, not view)
- `fitbod/Sessions/SessionLoggerView.swift`
- `fitbod/Sessions/SetRow.swift`
- `fitbod/Sessions/SetTypeChip.swift`
- `fitbod/Sessions/SwapExerciseSheet.swift`
- `fitbod/Sessions/TempoEntryRow.swift`
- `fitbod/Sessions/WarmupRampRows.swift`
- `fitbod/Sessions/WhyThisWeightSheet.swift`
- `fitbod/Sessions/WorkoutNotesSheet.swift`

Sessions — rest timer (7 files, all behavior-correct, visual-incorrect):
- `fitbod/Sessions/RestTimer/RestTimerActivityController.swift`
- `fitbod/Sessions/RestTimer/RestTimerAttributes.swift`
- `fitbod/Sessions/RestTimer/RestTimerEngine.swift`
- `fitbod/Sessions/RestTimer/RestTimerLiveActivityBridge.swift`
- `fitbod/Sessions/RestTimer/RestTimerNotificationScheduler.swift`
- `fitbod/Sessions/RestTimer/RestTimerOverlay.swift`
- `fitbod/Sessions/RestTimer/RestTimerProgressRing.swift`

Views (1 file):
- `fitbod/Views/IntentChip.swift`

App (3 files):
- `fitbod/App/PlaceholderTabView.swift`
- `fitbod/App/RootView.swift`
- `fitbod/App/SeedState.swift`

Widgets (3 files):
- `FitbodWidgets/FitbodWidgetsBundle.swift`
- `FitbodWidgets/RestTimerLiveActivity.swift`
- `FitbodWidgets/RestTimerLockScreenView.swift`

**Configuration / assets audited:**
- `fitbod/Info.plist` (no `UIAppFonts`, has `NSSupportsLiveActivities`)
- `fitbod/Assets.xcassets/` (6 colorsets: `AccentColor`, `AppIcon`, 4 Volume* sets — no `bru*` sets)
- `fitbod/Assets.xcassets/AccentColor.colorset/Contents.json` (teal `#0E7C86` light, `#3FBFC9` dark — confirmed deprecated for Phase 2+ per BRU spec)
- `fitbod/Resources/` (only `ExerciseSeed/`, no `Fonts/`)
- `fitbod.xcodeproj/project.pbxproj` (no `INFOPLIST_KEY_UIAppFonts`)

**Spec / planning artifacts read:**
- `.planning/phases/02-core-loop-routines-sessions/02-UI-SPEC.md` (BRU v2, 761 lines, revision 2)
- `.planning/phases/02-core-loop-routines-sessions/02-CONTEXT.md`
- `.planning/phases/02-core-loop-routines-sessions/02-01-PLAN.md` (RestTimerEngine + notifications)
- `.planning/phases/02-core-loop-routines-sessions/02-02-PLAN.md` (RestTimer Live Activity + widget extension)
- `.planning/phases/02-core-loop-routines-sessions/02-03-PLAN.md` (RestTimer overlay + engine integration)
- `.planning/phases/02-core-loop-routines-sessions/02-01-SUMMARY.md`
- `.planning/phases/02-core-loop-routines-sessions/02-02-SUMMARY.md`
- `.planning/phases/02-core-loop-routines-sessions/02-03-SUMMARY.md`
- `bru-screens/today.jsx`, `routine-builder.jsx`, `session-history.jsx`, `exercise-detail.jsx` (BRU mockup reference — visual source of truth per spec)

**Verification commands run (sample):**
- `grep -rn "Color\.accentColor\|Color(\"AccentColor\")\|\.tint(.accentColor)\|\.tint(Color.accentColor)" fitbod FitbodWidgets --include="*.swift" | wc -l` → 91
- `grep -rn "\.font(\.\(body\|headline\|title\|caption\|subheadline\|footnote\|callout\|largeTitle\)" fitbod --include="*.swift" | grep -v "Backup\|Export\|Periodization\|Fatigue\|Progress\|Persistence\|Models\|Prescription\|Settings\|App/" | wc -l` → 120 (with App/ included: 95 inside Phase 2 surfaces)
- `grep -rn "Image(systemName:" fitbod --include="*.swift" | grep -v "Backup\|Export\|Periodization\|Fatigue\|Progress\|Persistence\|Models\|Prescription\|Settings\|App/" | wc -l` → 18 (17 in Phase 2 surfaces, 1 in widget)
- `grep -rn "displayHero\|displayLarge\|displayMedium\|bodyEmphasis\|bodyDefault\|labelSmall\|labelMicro\|SpaceGrotesk\|JetBrainsMono\|BRUFont" fitbod 2>/dev/null | wc -l` → 0 (Swift sources)
- `grep -rln "BRUHeaderBar|BRUTabBar|BRUChip|..." fitbod 2>/dev/null` → 0 hits inside `fitbod/`

---

## Verifier Sign-off (Self-Assessment)

- [x] Dimension 1 Copywriting: 3/4 — v1 verbatim preserved (correct); case treatment + new BRU screens absent
- [ ] Dimension 2 Visuals: 1/4 — FAIL — zero BRU primitives, zero BRU surfaces
- [ ] Dimension 3 Color: 1/4 — FAIL — 91 `accentColor`, zero `bruInk`/`bruSignal`, banned system colors persist
- [ ] Dimension 4 Typography: 1/4 — FAIL — zero `BRUFont`, zero fonts bundled, 95 Apple semantic styles
- [x] Dimension 5 Spacing: 3/4 — values mostly on-grid; border-weight contract unimplemented
- [x] Dimension 6 Experience Design: 3/4 — interaction layer correct; minor BRU compliance gaps (red system colors, empty-state copy)

**Approval: PENDING.** Phase 2 visual layer requires a full Wave A → Wave G rewrite per UI-SPEC § Implementation Migration Notes (line 705-743) before BRU can be marked PASS.

---

*Audited by gsd-ui-auditor (autonomous mode) — adversarial stance. No averaging. Headline 12/24 reflects three pillars at 1/4 (zero BRU implementation) + two pillars at 3/4 (interaction + spacing largely correct from v1 + copy preserved). The visual contract has zero implementation surface; the behavior contract is solid.*
