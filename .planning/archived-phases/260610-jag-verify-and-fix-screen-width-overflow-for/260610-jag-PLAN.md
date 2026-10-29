---
phase: quick-260610-jag
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - fitbod/Periodization/BlockBuilderView.swift
  - fitbod/Sessions/SetRow.swift
  - fitbod/Routines/PrescriptionEditorRow.swift
  - fitbod/Periodization/ProgramView.swift
  - fitbod/Periodization/BlockReviewView.swift
  - fitbod/Sessions/WhyThisWeightSheet.swift
  - fitbod/Settings/PlateCalculatorSheet.swift
autonomous: true
requirements:
  - "QUICK-260610-jag: Support iPhone 15+ (min 390pt logical width); verify no overflow, fix only confirmed breakage"
must_haves:
  truths:
    - "All primary screens render without horizontal clipping/overflow at 390pt logical width (iPhone 16e)"
    - "Dense HStack rows (BlockBuilderView phase rows, SetRow, PrescriptionEditorRow, etc.) lay out cleanly at 390pt without truncating critical numeric/text content"
    - "No regression on iPhone 17 Pro Max (~440pt) — screens that were fine before remain fine"
    - "Verification produces a concrete written list of which screens were checked, which broke, and what was fixed (or, if none broke, an explicit 'all clear' report)"
  artifacts:
    - path: ".planning/quick/260610-jag-verify-and-fix-screen-width-overflow-for/screenshots/"
      provides: "390pt screenshots of each verified screen (named per-screen, before/after if fixes applied)"
    - path: ".planning/quick/260610-jag-verify-and-fix-screen-width-overflow-for/SUMMARY.md"
      provides: "Verification report: per-screen pass/fail at 390pt, arithmetic checks, fixes applied (or 'no fixes needed'), guardrail test results"
  key_links:
    - from: "narrow simulator screenshots"
      to: "fix decisions"
      via: "executor reads screenshot via Read tool, identifies clipping, only then edits the corresponding view"
      pattern: "no edit without first capturing a 390pt screenshot showing the break"
---

<objective>
Verify which screens (if any) overflow at 390pt logical width on iPhone 16e / 15 / 16 simulator, then fix ONLY the confirmed overflows with SwiftUI-idiomatic flexible layouts. Re-verify at 390pt and 440pt to confirm fix + no regression. Run New Block guardrail tests if BlockBuilderView is touched.

Purpose: All UI to date was visually validated on iPhone 17 Pro Max (~440pt). User now commits to supporting iPhone 15+ (min 390pt). Audit identified candidate risk files but cannot prove breakage without on-device rendering. Don't fix what isn't broken — verify first.

Output:
- 390pt screenshots of each candidate screen (in `.planning/quick/260610-jag-verify-and-fix-screen-width-overflow-for/screenshots/`)
- SUMMARY.md with the verification table + fix log (or "all clear, zero fixes" if applicable)
- Code edits ONLY where a screenshot confirms clipping/overflow
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md

# Audit findings (already established by parent session — do NOT re-audit):

## Confirmed safe — DO NOT plan or modify
- `fitbod/Design/BRUPhoneFrame.swift` — its 390×844 frame is a DEBUG preview-only wrapper, zero production impact
- Rest timer 200×200pt circles — fit comfortably at 390pt
- Small fixed atoms: icons 18-44pt, dividers 1pt, row heights 52-56pt, 44pt tap targets — width-independent by design
- Dynamic Type / `relativeTo:` is OUT OF SCOPE — point sizes don't change with device width, so it doesn't address this problem. Do NOT add Dynamic Type work.

## Candidate risk files (verify before touching)
1. Dense HStack rows with multiple fixed-width stat columns competing for flexible label space at 390-393pt:
   - `fitbod/Periodization/BlockBuilderView.swift` — 32 fixed `.frame(width:)` calls; phase rows near lines ~1656-1732 stack 32/36/52pt-wide columns with 56pt-tall rows + dividers (highest suspicion)
   - `fitbod/Sessions/SetRow.swift` — 7 fixed frames
   - `fitbod/Routines/PrescriptionEditorRow.swift` — 5 fixed frames
   - `fitbod/Periodization/ProgramView.swift` — 9 fixed frames
   - `fitbod/Periodization/BlockReviewView.swift` — 9 fixed frames
   - `fitbod/Sessions/WhyThisWeightSheet.swift` — 8 fixed frames
   - `fitbod/Settings/PlateCalculatorSheet.swift` — 7 fixed frames
2. `BRUFont.displayHero = 56pt` fixed — check usages for clipping at 390pt

The fixed widths sum differently per row; many may be fine since 390 vs 440 is only ~50pt difference. Visual verification on a narrow simulator must come BEFORE fixing.

# Verification tooling (use this exact workflow)
- List simulators: `xcrun simctl list devices available | grep -E "iPhone (15|16|17)"`. Pick narrowest available: iPhone 16e (390pt) > iPhone 15/16 (393pt). Any of these acceptable.
- Build: `xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,name=<device>' -configuration Debug build 2>&1 | tail -50` (MUST pipe to tail — full output exhausts context per project memory)
- Boot + install + launch: `xcrun simctl boot <udid>` (idempotent), `xcrun simctl install <udid> <app_path>`, `xcrun simctl launch <udid> <bundle_id>`
- Screenshot: `xcrun simctl io <udid> screenshot <path.png>` then use the Read tool to view the image
- Navigate to each screen by tapping via `xcrun simctl ui <udid> ...` if available, OR by seeding state and using the deep-link/scheme + tab bar via `xcrun simctl openurl` if the app supports it. If neither is reliable, use repeated screenshots after manually launching to a known root state and rely on launch-args / debug menu to jump to specific screens (BlockBuilderView is accessible via Periodization tab → New Block).
- Arithmetic cross-check (cheaper than screenshots for borderline cases): for any dense HStack, sum: `column widths + inter-column spacing + horizontal padding`. If sum > 390pt minus needed flexible-label minimum (≥80pt for an exercise name), it overflows. Use `rg -n "\.frame\(width:" <file>` and `rg -n "spacing:" <file>` to extract values.

# Test guardrails (project memory)
- If ANY file under `BlockBuilder*` or anything matching `New Block` screens is edited, run ALL THREE source-introspection suites. Find them:
  `rg -l "BlockBuilder" fitbodTests/ --type swift`
  Includes `NewBlockBuilderFidelityTests.swift` and siblings. Run each suite — past executor ran only one and left a sibling red.
- Run full unit test suite before declaring done:
  `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=<device>' 2>&1 | tail -100`

# SwiftUI conventions (CLAUDE.md)
- No `GeometryReader` sprawl — prefer `.frame(minWidth:maxWidth:)`, `.layoutPriority(_:)`, or letting content size itself
- `minimumScaleFactor` ONLY as a last-resort for display-numeral views (e.g. `displayHero` numerics); do NOT use it as a blanket overflow band-aid on body text
- Replace `.frame(width: N)` with `.frame(minWidth: N)` or `.frame(maxWidth: .infinity, alignment: .trailing)` where the column can flex
- Use `Spacer(minLength:)` instead of fixed-width spacers when the row needs to compress
- Honor existing `BRUFont` / `Color+BRU` tokens — don't introduce ad-hoc fonts or colors

<interfaces>
<!-- Executor extracts these on demand via rg before touching a file. Examples of patterns: -->
<!--   rg -n "\.frame\(width:" fitbod/Periodization/BlockBuilderView.swift -->
<!--   rg -n "HStack\(spacing:" fitbod/Periodization/BlockBuilderView.swift -->
<!--   rg -n "BRUFont\." fitbod/Design/ | head -30 -->
<!-- Confirm the named BRUFont tokens (displayHero, etc.) and Color+BRU tokens already exist before assuming. -->
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Verify all candidate screens at 390pt — produce concrete broken-screens list</name>
  <files>
    .planning/quick/260610-jag-verify-and-fix-screen-width-overflow-for/screenshots/*.png (new),
    .planning/quick/260610-jag-verify-and-fix-screen-width-overflow-for/SUMMARY.md (new, verification section)
  </files>
  <action>
    Pick narrowest available iPhone 16e / 15 / 16 simulator via `xcrun simctl list devices available | grep -E "iPhone (15|16|16e|17)" | head -10`. Record the device + udid + logical width in SUMMARY.md.

    Build the app for that simulator with `xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,name=<device>' -configuration Debug build 2>&1 | tail -50`. If build fails, fix only what blocks the build (do not start width work on a broken build). Install + launch.

    For EACH candidate screen listed below, navigate to it (tab + button taps; if a screen needs seeded data, log it in SUMMARY.md and use a known reachable variant), capture a screenshot to `.planning/quick/260610-jag-verify-and-fix-screen-width-overflow-for/screenshots/<screen-name>-390pt.png`, then READ each PNG via the Read tool and visually classify:
      - PASS: nothing truncated, no horizontal scroll, no clipped text/numbers, columns separated
      - FAIL: list specific overflow (which element, what's clipped)

    Screens to verify (must hit every one or document why unreachable):
      1. Periodization tab → BlockBuilderView (New Block flow) — dense phase rows ~1656-1732 are highest suspicion; capture at least one screenshot with phase rows visible
      2. Periodization tab → ProgramView (existing program list/grid)
      3. Periodization tab → BlockReviewView
      4. Sessions tab → live session showing SetRow rows
      5. Routines tab → routine editor showing PrescriptionEditorRow rows
      6. Sessions → WhyThisWeightSheet (open the sheet from a working set)
      7. Settings → PlateCalculatorSheet
      8. Anywhere `BRUFont.displayHero` (56pt) is used — find with `rg -n "displayHero" fitbod/` and screenshot one of those views

    Augment screenshots with arithmetic checks: for each dense HStack, run `rg -n "\.frame\(width:" <file>` and `rg -n "HStack\(spacing:" <file>` to extract column widths + spacing + padding, sum them, subtract from 390pt. If the remainder for flexible labels < 80pt, mark as arithmetic-fail even if the screenshot looks OK (likely fails with longer real strings like "Bulgarian Split Squat — Left Leg").

    Write the verification section of SUMMARY.md as a table:
      | # | Screen | File | Screenshot | Visual result | Arithmetic check | Verdict |
      |---|--------|------|------------|---------------|------------------|---------|

    STOP CONDITION: If every screen + every arithmetic check PASSES, write a clear "ALL CLEAR — zero overflow at 390pt, no fixes required" conclusion in SUMMARY.md, skip Task 2, jump to Task 3 (re-verify only). Do NOT invent fix work to look productive.
  </action>
  <verify>
    <automated>test -d .planning/quick/260610-jag-verify-and-fix-screen-width-overflow-for/screenshots && ls .planning/quick/260610-jag-verify-and-fix-screen-width-overflow-for/screenshots/*.png | wc -l | awk '$1 >= 7 {exit 0} {exit 1}' && grep -q "Verdict" .planning/quick/260610-jag-verify-and-fix-screen-width-overflow-for/SUMMARY.md</automated>
  </verify>
  <done>
    At least 7 unique 390pt screenshots exist (one per candidate screen, marked unreachable in SUMMARY if a screen couldn't be navigated to). SUMMARY.md contains the verification table with PASS/FAIL verdict per screen. The set of "FAIL" screens (possibly empty) is the input to Task 2.
  </done>
</task>

<task type="auto">
  <name>Task 2: Fix confirmed overflows with flexible SwiftUI layouts (skip entirely if Task 1 found none)</name>
  <files>
    Subset of: fitbod/Periodization/BlockBuilderView.swift, fitbod/Sessions/SetRow.swift, fitbod/Routines/PrescriptionEditorRow.swift, fitbod/Periodization/ProgramView.swift, fitbod/Periodization/BlockReviewView.swift, fitbod/Sessions/WhyThisWeightSheet.swift, fitbod/Settings/PlateCalculatorSheet.swift — ONLY files whose screens FAILED in Task 1.
  </files>
  <action>
    SKIP THIS TASK ENTIRELY if Task 1's SUMMARY.md concludes "ALL CLEAR — zero overflow at 390pt". Document the skip in SUMMARY.md and proceed to Task 3.

    Otherwise, for each FAIL screen from Task 1, edit ONLY the specific HStack / row containing the clipped element. Do NOT bulk-replace all 32 `.frame(width:)` calls in BlockBuilderView — only the rows that broke.

    Fix patterns (apply per CLAUDE.md SwiftUI conventions, in order of preference):
      1. **First choice: let content size itself.** Remove the fixed-width frame; if the column needs a minimum, use `.frame(minWidth: N)`. For trailing-aligned stat columns, `.frame(maxWidth: .infinity, alignment: .trailing)` lets the column flex.
      2. **Second choice: layout priority.** If a flexible label is being squeezed by adjacent fixed columns, add `.layoutPriority(1)` on the label to make it claim space first.
      3. **Third choice: convert fixed spacers.** Replace `Spacer().frame(width: N)` with `Spacer(minLength: M)` where M < N.
      4. **Last resort, displayHero numerics only:** `.minimumScaleFactor(0.85)` on a single line of large display digits. Do NOT scatter `minimumScaleFactor` across body text — it hides the real problem.

    Forbidden patterns (do not introduce):
      - `GeometryReader` wrapping the whole row (sprawl per CLAUDE.md)
      - `.fixedSize()` to force the column to its natural size (defeats the fix)
      - `Text(...).truncationMode(.tail)` as the primary fix (acceptable as a belt-and-suspenders companion AFTER the layout flexes)
      - Any new font sizes — keep `BRUFont.*` tokens

    After EACH fix, rebuild and re-screenshot the same screen at 390pt, save as `<screen-name>-390pt-after.png`, READ it, and confirm the clip is gone. If a fix doesn't resolve the clip, iterate before moving to the next screen. Append a "Fixes applied" section to SUMMARY.md listing: file, line range, before/after screenshot pair, fix pattern used (1/2/3/4 from above).
  </action>
  <verify>
    <automated>if grep -q "ALL CLEAR" .planning/quick/260610-jag-verify-and-fix-screen-width-overflow-for/SUMMARY.md; then echo "skip"; else grep -q "Fixes applied" .planning/quick/260610-jag-verify-and-fix-screen-width-overflow-for/SUMMARY.md && ls .planning/quick/260610-jag-verify-and-fix-screen-width-overflow-for/screenshots/*-after.png; fi</automated>
  </verify>
  <done>
    Either: SUMMARY.md says "ALL CLEAR" and no code edits were made (skip path), OR: every FAIL screen from Task 1 has a paired `<screen-name>-390pt-after.png` showing the clip resolved, plus a "Fixes applied" log section listing file/pattern per fix.
  </done>
</task>

<task type="auto">
  <name>Task 3: Re-verify at 390pt + 440pt, run guardrail tests if BlockBuilder touched, finalize SUMMARY.md</name>
  <files>
    .planning/quick/260610-jag-verify-and-fix-screen-width-overflow-for/SUMMARY.md (append),
    .planning/quick/260610-jag-verify-and-fix-screen-width-overflow-for/screenshots/*-440pt.png (new)
  </files>
  <action>
    Regardless of whether Task 2 ran, do a final pass:

    1. **Regression check on iPhone 17 Pro Max** (~440pt logical width). Build + install + launch on iPhone 17 Pro Max simulator. Screenshot every screen that was either modified in Task 2 OR (if no fixes ran) at minimum the top 3 highest-arithmetic-risk screens from Task 1 (BlockBuilderView phase rows + 2 others). Save as `<screen-name>-440pt.png`. READ each to confirm: nothing was made worse at 440pt — columns still aligned, no over-stretched flex frames, no awkward whitespace.

    2. **If any file under `BlockBuilder*` was edited in Task 2, run the New Block guardrail tests.** Find suites with `rg -l "BlockBuilder" fitbodTests/ --type swift`. Run EACH suite (do not stop at the first):
       `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16e' -only-testing:fitbodTests/<SuiteName> 2>&1 | tail -50`
       per project memory — past executor ran one suite and left a sibling red. Confirm all pass.

    3. **Run the full unit test suite** (Swift Testing — `@Test` / `#expect` per CONVENTIONS) regardless of which files were touched:
       `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16e' 2>&1 | tail -100`
       Confirm green. If any unrelated test was already red before this work (git log), note the pre-existing state — do not blame this plan.

    4. **Finalize SUMMARY.md.** Make sure it has, in order:
       - Verification table from Task 1 (with simulator device + width recorded)
       - Fixes applied log from Task 2 (or "Skipped — all clear" line)
       - 440pt regression results table
       - Guardrail test results (which suites ran, all pass)
       - Full unit test results (pass/fail summary)
       - Final conclusion sentence: either "Fixed N screens to support iPhone 15+ (390pt min)" or "Verified all candidate screens render correctly at 390pt — no code changes required"
  </action>
  <verify>
    <automated>grep -q "Final conclusion" .planning/quick/260610-jag-verify-and-fix-screen-width-overflow-for/SUMMARY.md && grep -q "440pt" .planning/quick/260610-jag-verify-and-fix-screen-width-overflow-for/SUMMARY.md && grep -qE "(test.*pass|All tests pass|Test Suite.*passed)" .planning/quick/260610-jag-verify-and-fix-screen-width-overflow-for/SUMMARY.md</automated>
  </verify>
  <done>
    SUMMARY.md is complete with all five sections (verification, fixes-or-skip, 440pt regression, guardrail tests if applicable, full unit tests, final conclusion). All test runs are green. Either no code changed (verification-only outcome) OR every modified file has confirmed before/after screenshots and passing tests.
  </done>
</task>

</tasks>

<verification>
- All 7+ candidate screens have a 390pt screenshot under `.planning/quick/260610-jag-verify-and-fix-screen-width-overflow-for/screenshots/`
- SUMMARY.md verification table covers every candidate screen with PASS/FAIL verdict
- For each FAIL: a paired `-after.png` screenshot proves the clip is gone, AND the fix uses an allowed pattern from Task 2 (flex frames / layoutPriority / Spacer minLength / displayHero minimumScaleFactor)
- For each modified screen: 440pt screenshot confirms no regression
- If any `BlockBuilder*` file was touched: ALL guardrail suites under `fitbodTests/` matching `BlockBuilder` pass
- Full unit test suite passes
- No `GeometryReader` or `.fixedSize()` overflow band-aids were introduced
- No Dynamic Type / `relativeTo:` work was added (out of scope)
</verification>

<success_criteria>
- Verified outcome is documented: SUMMARY.md states clearly either "X screens were broken at 390pt and have been fixed" or "All candidate screens render correctly at 390pt — no code changes required"
- All commits (if any) follow the conventional `fix(quick-260610-jag-NN):` or `verify(quick-260610-jag-NN):` prefix
- If no code changed, a single docs commit captures the SUMMARY.md verification report
- The app builds and runs cleanly on the narrowest available iPhone 15+ simulator (iPhone 16e 390pt preferred)
- The user can decide based on the SUMMARY.md whether more screens/edge cases warrant a follow-up quick task
</success_criteria>

<output>
After completion, ensure `.planning/quick/260610-jag-verify-and-fix-screen-width-overflow-for/SUMMARY.md` exists with:
- Simulator device + udid + logical width used
- Verification table (Task 1) — every candidate screen with screenshot path + verdict
- Fixes applied log (Task 2) — or "Skipped: all clear"
- 440pt regression check (Task 3)
- Guardrail + full test results
- Final conclusion line
</output>
