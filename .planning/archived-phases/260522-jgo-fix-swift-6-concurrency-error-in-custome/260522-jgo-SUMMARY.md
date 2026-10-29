---
phase: quick-260522-jgo
plan: 01
subsystem: ExerciseLibrary / image attachment
status: complete
tags: [swift6, concurrency, mainactor, image-picker, bugfix]
requires: []
provides:
  - "Swift 6 concurrency-clean .onChange Task in CustomExerciseImagePicker.swift"
affects: []
tech-stack:
  added: []
  patterns:
    - "Task { @MainActor in ... } for unstructured Tasks spawned from MainActor views that touch @Observable models after await"
key-files:
  created: []
  modified:
    - fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift
decisions:
  - "Use `Task { @MainActor in }` (closure attribute) rather than `MainActor.run { }` — wrapping nested async work in `MainActor.run` is awkward and the closure attribute is the idiomatic Swift 6 fix for a MainActor-spawned Task that must stay on the MainActor across `await`."
metrics:
  duration_seconds: 168
  completed: 2026-05-22T21:06:59Z
  tasks: 1
  files_modified: 1
commit: dd79f12
---

# Quick Task 260522-jgo: Fix Swift 6 Concurrency Error in CustomExerciseImagePicker Summary

One-line `@MainActor`-on-Task fix in `CustomExerciseImagePicker.swift` that pins the `.onChange(of: selection)` async-loader Task to the MainActor so the post-`await` write to `draft.imageData` (a property on the `@Observable` `CustomExerciseDraft`) no longer triggers Swift 6's "actor-isolated cannot be referenced from a Sendable closure" diagnostic.

## Tasks Completed

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | Annotate the `.onChange` Task with `@MainActor` | `dd79f12` | `fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift` |

## Diff

```diff
diff --git a/fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift b/fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift
index 5e72649..10a79b3 100644
--- a/fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift
+++ b/fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift
@@ -89,7 +89,7 @@ struct CustomExerciseImagePicker: View {
         .onChange(of: selection) { _, newValue in
             // Async load — PhotosPickerItem.loadTransferable is async
             // by design (the picker may return a remote-fetched asset).
-            Task {
+            Task { @MainActor in
                 if let data = try? await newValue?
                     .loadTransferable(type: Data.self)
                 {
```

Single-line change: `Task {` → `Task { @MainActor in` on line 92. No other lines, files, or comments touched.

## Verification

### Grep check (exactly one match required)

```
$ grep -n 'Task { @MainActor in' fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift
92:            Task { @MainActor in
```

Match count: **1** — passes the gate.

### Build verification

```
$ xcodebuild -scheme fitbod \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build
```

(Plan called for `iPhone 16`; this Mac only has iPhone 17 family simulators installed, so per the constraint's fallback clause — "or whichever destination is available on this Mac — fall back to the latest iPhone Simulator the project supports" — `iPhone 17` was used.)

Exit code: **0**

Last lines of build output:

```
ValidateEmbeddedBinary /Users/.../fitbod.app/PlugIns/FitbodWidgetsExtension.appex (in target 'fitbod' from project 'fitbod')
    cd /Users/chrissaechao/Desktop/fitbod/.claude/worktrees/agent-a84416648f1617a10
    /Applications/Xcode.app/Contents/Developer/usr/bin/embeddedBinaryValidationUtility /Users/.../fitbod.app/PlugIns/FitbodWidgetsExtension.appex -signing-cert - -info-plist-path /Users/.../fitbod.app/Info.plist

** BUILD SUCCEEDED **
```

Errors: **0**

No diagnostic on `CustomExerciseImagePicker.swift` lines 89–99 (the edited `.onChange` block).

### Why `@MainActor` on the Task (vs. `MainActor.run`)

In Swift 6 an unstructured `Task { ... }` spawned from a `@MainActor` context does **not** inherit MainActor isolation — its closure is `@Sendable` and resumes on the generic executor after every `await`. The idiomatic fix is to attach `@MainActor` to the Task closure itself so the entire body (including the resumption after `await loadTransferable`) is MainActor-isolated. This is preferable to `MainActor.run { ... }` because (a) nesting `await loadTransferable` inside `MainActor.run` is awkward and would push the long async load onto the MainActor when it should suspend off-actor, and (b) `Task { @MainActor in }` mirrors the actor of the surrounding view code and reads naturally. `loadTransferable` still hops off the MainActor internally during its async work; only the resumption is pinned, which is exactly what is needed for the `draft.imageData = data` write.

## Deviations from Plan

None — plan executed exactly as written. Single-line edit, build succeeded, behavior preserved.

### Auth gates encountered

None.

## Deferred Issues

- **Pre-existing line-84 warning (out of scope):** `CustomExerciseImagePicker.swift:84:21: warning: main actor-isolated property 'draft' can not be referenced from a Sendable closure`. This is a **separate** Swift-6 isolation issue on the `PhotosPicker` label closure (`Label(draft.imageData == nil ? "Add Photo" : "Change Photo", ...)`) — different block from the `.onChange` Task this plan targets. It is a pre-existing warning (not error), unrelated to this edit, and within the executor's scope-boundary rules it must NOT be auto-fixed by this task. Logged here for a future quick task. Suggested fix: read `draft.imageData == nil` into a local before the `PhotosPicker(...)` `label:` parameter, or annotate the label closure (likely needs the broader picker view annotation handled at the SwiftUI-View level — needs investigation, not a blind 1-line fix).

## Known Stubs

None introduced.

## Threat Flags

None — no new network endpoints, auth paths, file access, or schema changes.

## Self-Check: PASSED

- File modified exists: `fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift` — **FOUND**
- Commit exists in branch history: `dd79f12` — **FOUND** in `git log --oneline -1`
- Grep returns exactly one `Task { @MainActor in` match — **PASSED**
- Build exit code 0, `** BUILD SUCCEEDED **` in log — **PASSED**
- No diagnostic on edited lines 89–99 — **PASSED**
- `git diff --name-only HEAD~1 HEAD` lists only the picker — **PASSED**
