---
phase: quick-260525-gop
plan: 01
type: quick
date: 2026-05-25
files_modified:
  - fitbod/Design/BRUDashedSlot.swift
autonomous: true
tags: [build, warnings, swift-concurrency]
---

<objective>
Fix build warnings without changing runtime behavior.
</objective>

<findings>
- `xcodebuild -project fitbod.xcodeproj -scheme fitbod -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/fitbod-deriveddata-codex CODE_SIGNING_ALLOWED=NO build` currently emits a Swift concurrency warning in `BRUDashedSlot.swift`.
- The same build is blocked by a pre-existing compile error in `RootView.swift`: `ProgramView` is referenced but no matching type exists in the target.
</findings>

<approach>
Keep the code change limited to the warning root cause: make the positional `BRUDashedSlot` action parameter match the stored `@Sendable` action contract.
</approach>
