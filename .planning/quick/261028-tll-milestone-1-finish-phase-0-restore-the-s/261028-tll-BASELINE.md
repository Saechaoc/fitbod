# Quick Task 261028-tll: Baseline run on the committed tip

## What was run

- Tip: `f60df5031ef2ae5325c45855804a56198bb74439` ("docs: record milestone evidence and open release flags"), the last of the seven group commits.
- Device: "sw6 iPhone 17 Pro Max", `79CAC9F7-95DE-4AEB-84F6-660A8F2E36EE`, iOS 26.5 runtime.
- Text size `large` (the default) and light appearance, both checked with `xcrun simctl ui` before the run.
- Xcode 26.5 (17F42).
- The scheme matched HEAD before the run, so UI tests ran serially (`parallelizable = "NO"`).
- Started 2026-10-28 21:56:30 PDT and finished 22:12:19 PDT, about 15.8 minutes including the build.

Command, from the repo root:

```sh
xcodebuild -project fitbod.xcodeproj -scheme fitbod \
  -destination 'platform=iOS Simulator,id=79CAC9F7-95DE-4AEB-84F6-660A8F2E36EE' \
  -derivedDataPath <scratchpad>/dd -parallel-testing-enabled NO \
  -resultBundlePath <scratchpad>/runs/m1-baseline-01.xcresult \
  test CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO
```

`<scratchpad>` is `/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/16ed754c-c321-4b68-8032-2fab24441b31/scratchpad`.
The result bundle is `<scratchpad>/runs/m1-baseline-01.xcresult`, and the full log is `<scratchpad>/runs/m1-baseline-01.log`.

## Build

- The app and the widget extension built from a clean DerivedData folder.
- `fitbod.app/PlugIns/` contains `FitbodWidgetsExtension.appex`.
- The build printed one compiler warning: `fitbod/Periodization/BlockBuilderView.swift:736:21`, "'+' was deprecated in iOS 26.0: Use string interpolation on `Text` instead".
- Phase 4 of the approved plan fixes that warning.

## Results

From `xcrun xcresulttool get test-results summary`:

| Measure | Count |
|---|---|
| Tests run | 1,026 |
| Passed | 1,023 |
| Failed | 2 |
| Skipped | 0 |
| Expected failures | 1 |

By target, from `get test-results tests`:

- `fitbodTests`: 974 tests, with 973 passed and 1 expected failure.
- `fitbodUITests`: 52 tests, with 50 passed and 2 failed.
- XCTest ran 55 UI test invocations, because some UI tests repeat across launch configurations.
- The device-level count is 1,103 passed, because it also expands parameterized unit tests.
  It must not be added to the top-level count.

The expected failure is `ProgramGraphDeleteRuleBehaviorTests.slottedTemplateDenyRuleRuntimeEnforcement`, which records a known issue on purpose.

## Failures

1. `fitbodUITests` `MilestoneOneJourneyUITests/testAuthorRoutineLogRelaunchFinishAndHistory()`.
   First line: `XCTAssertEqual failed: ("106") is not equal to ("10") - Text replacement must not retain a prefix or suffix` at `MilestoneOneJourneyUITests.swift:412`.
   This is review item 5: typing into a target reps field keeps the old digits.
   Codex's caret-based text helper does not avoid it.
2. `fitbodUITests` `WhyThisWeightSheetBRUUITests/testWhyThisWeightSectionHeadVisible()`.
   First line: `XCTAssertTrue failed - Expected a visible control: "Why this weight" StaticText` at `UITestNavigation.swift:54`.
   This is review item 4: the weight field stays focused, so the keyboard covers the sheet's section head on the large phone.

The store-recovery tests print CoreData migration errors in the log.
Those errors are the expected input of those tests, and the tests passed.

## Comparison with Codex's last full run

Codex's last full run, per `docs/VERIFICATION.md`, had 1,021 passed, 4 failed and 1 expected failure.
Codex prepared fixes for four tests but could not run them.
Their results on the committed tip:

| Test | Result now |
|---|---|
| `MilestoneOneJourneyUITests/testAuthorRoutineLogRelaunchFinishAndHistory` | Still fails ("106" for "10"). The app bug is item 5. |
| `SessionLoggerBRUUITests/testBRUHeaderBarMenuActionsAccessibleInActiveSession` | Passes. |
| `WhyThisWeightSheetBRUUITests/testWhyThisWeightHeroSlabAppearsAfterLongPress` | Passes. |
| `WhyThisWeightSheetBRUUITests/testWhyThisWeightSectionHeadVisible` | Still fails. The app bug is item 4. |

Both remaining failures are app bugs that Phase 1 of the approved plan fixes.
Nothing was fixed in this task.
