---
phase: quick-260522-jgo
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift
autonomous: true
requirements:
  - QUICK-260522-jgo-01
must_haves:
  truths:
    - "fitbod target builds cleanly under Swift 6 strict concurrency with no diagnostic on the modified `.onChange(of: selection)` block"
    - "Picking an image in the custom-exercise editor still writes the loaded `Data` to `draft.imageData` (behavior preserved)"
  artifacts:
    - path: "fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift"
      provides: "PhotosPicker-backed image attachment for the custom-exercise editor, Swift-6-concurrency-clean"
      contains: "Task { @MainActor in"
  key_links:
    - from: "fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift"
      to: "fitbod/ExerciseLibrary/CustomExerciseDraft.swift"
      via: "@Bindable var draft + draft.imageData = data on MainActor"
      pattern: "draft\\.imageData\\s*=\\s*data"
---

<objective>
Fix the Swift 6 strict-concurrency diagnostic in `CustomExerciseImagePicker.swift` at line ~92: the `Task {}` initiated from inside a `@MainActor` `View` body does NOT inherit MainActor isolation in Swift 6 — its closure is `@Sendable` and runs on the generic executor. Writing to `draft.imageData` (a property on a MainActor-isolated `@Observable` class — `CustomExerciseDraft`, bound via `@Bindable`) across the `await loadTransferable` suspension violates actor isolation.

Purpose: Unblock the build under Swift 6 language mode without introducing new abstractions or refactoring surrounding code.

Output: One annotated `Task` closure (`Task { @MainActor in ... }`) and a clean build.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@./CLAUDE.md
@fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift
@fitbod/ExerciseLibrary/CustomExerciseDraft.swift

<interfaces>
<!-- Key contracts the executor needs. No codebase exploration required. -->

From fitbod/ExerciseLibrary/CustomExerciseDraft.swift:
```swift
@Observable
public final class CustomExerciseDraft {
    public var imageData: Data? = nil
    // ... (other fields; only imageData is touched here)
}
```
- `CustomExerciseDraft` is `@Observable` and is consumed by SwiftUI views via `@Bindable`, so its properties are effectively MainActor-isolated when accessed from the view layer.
- Writing `draft.imageData = data` MUST happen on the MainActor.

From fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift (current, line 89–99):
```swift
.onChange(of: selection) { _, newValue in
    Task {
        if let data = try? await newValue?
            .loadTransferable(type: Data.self)
        {
            draft.imageData = data
        }
    }
}
```
- `Task { ... }` here inherits a `@Sendable` closure, NOT MainActor. This is the Swift 6 isolation gap.
- `PhotosPickerItem.loadTransferable(type:)` is `async`; suspension points are fine — what matters is which actor resumes after the `await`.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Annotate the `.onChange` Task with @MainActor</name>
  <files>fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift</files>
  <action>
In `fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift`, locate the `.onChange(of: selection)` modifier (currently at line ~89) and change the unstructured `Task {` on line ~92 to `Task { @MainActor in`. Preserve the rest of the block byte-for-byte — same `if let data = try? await newValue?.loadTransferable(type: Data.self) { draft.imageData = data }` body, same comment ("Async load — PhotosPickerItem.loadTransferable is async…"). The only edit is the closure attribute.

Before:
- `Task {`

After:
- `Task { @MainActor in`

Rationale (do NOT add to the source as a new comment — the existing header comment already covers `loadTransferable`'s async nature; keep the file diff minimal): In Swift 6, an unstructured `Task` initiated from a `@MainActor` context does not inherit the actor; its closure is `@Sendable` and runs on the generic executor. Adding `@MainActor` to the closure pins the entire body — including the resumption after `await loadTransferable` — to the MainActor, where `draft.imageData` access is safe. `loadTransferable` already does its work off the main thread internally and suspends, so no UI blocking is introduced.

Do NOT:
- Refactor the picker into a separate helper / method.
- Replace `Task { @MainActor in ... }` with `MainActor.run { ... }` (less ergonomic; nesting `await` inside `MainActor.run` is awkward and the `@MainActor` Task attribute is the idiomatic Swift 6 fix).
- Convert `draft` access to `await MainActor.run` or `DispatchQueue.main.async` (these are the wrong tools — the Task closure itself should be MainActor-isolated).
- Touch any other file, comment block, or property.
  </action>
  <verify>
    <automated>xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug build 2>&1 | tee /tmp/fitbod-build.log | tail -40 ; ! grep -E "(error:|Sending main actor-isolated|actor-isolated.*cannot be referenced from a Sendable closure|cannot be referenced from a Sendable closure)" /tmp/fitbod-build.log</automated>
  </verify>
  <done>
    1. Line ~92 of `fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift` reads `Task { @MainActor in` (verify with `grep -n "Task { @MainActor in" fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift` — must return exactly one match).
    2. `xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' build` completes with `** BUILD SUCCEEDED **` and no Swift 6 concurrency diagnostic referencing `CustomExerciseImagePicker.swift` lines 89–99.
    3. No other file in the repo has been modified (verify with `git diff --name-only` — should list only `fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift`).
  </done>
</task>

</tasks>

<verification>
- `git diff fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift` shows exactly one changed line: `Task {` → `Task { @MainActor in`.
- `xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' build` succeeds.
- No new warnings or diagnostics introduced elsewhere in the picker file.
- Functional smoke (optional, manual): in the simulator, opening the custom-exercise editor → "Add Photo" → selecting an image still populates the preview thumbnail (proves `draft.imageData = data` still runs and the binding still updates).
</verification>

<success_criteria>
- Build succeeds under Swift 6 strict concurrency with no diagnostic on lines 89–99 of `CustomExerciseImagePicker.swift`.
- Diff is a one-line change: `Task {` → `Task { @MainActor in`.
- `CustomExerciseImagePicker`'s observable behavior is preserved: selecting an image still writes the loaded `Data` to `draft.imageData`.
</success_criteria>

<output>
After completion, create `.planning/quick/260522-jgo-fix-swift-6-concurrency-error-in-custome/260522-jgo-01-SUMMARY.md` recording:
- The exact one-line diff.
- The build command used and its result.
- A one-sentence note on why `@MainActor` on the Task (vs. `MainActor.run`) is the idiomatic Swift 6 fix here (for future reference when the same pattern appears elsewhere).
</output>
