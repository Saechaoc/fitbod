# Milestone 1 companion — completed

Completed 2026-10-03. Continues the shared milestone task without committing or
rewriting Claude-owned planning state. No branch changes, pushes, blanket staging
or unrelated cleanup.

## Delivered

- Real DEBUG BRU component gallery in Settings, interactive sample feedback,
  normal/dark/accessibility previews and previews in every Design file.
- Semantic signal foregrounds, readable filled labels, muted contrast, centralized
  measurements, 44pt compact controls and constrained wrapping.
- Stable session draft ownership through nested exercise pickers, stable unsaved
  row identities, working Move up/down and shared prescription steppers.
- Custom validation/retry feedback, keyboard-aware library return, shared loaded
  and bodyweight completion validation, stacked accessibility inputs and
  accessible expanded rest controls.
- Native BRU icon generator/assets; design-system docs, source-to-native screen
  mapping, setup, requirement audit, evidence/screenshots and prioritized roadmap.
- Interactive review at `.lavish/milestone-1-design-review.html`, following the
  existing BRU project assets, not a new unrelated web identity.

## Observed verification

- Current native app and widget build: exit 0.
- `compact-ax3-07`: 967 passed, 0 unexpected failures, 1 expected failure
  (965 passing units + logger/gallery UI).
- `compact-journey-16`: complete authored journey passed at 375pt/default text.
- `large-default-journey-17`: 966 passed, 0 unexpected failures, 1 expected
  failure (965 passing units + complete authored journey at 440pt/default text).
- `large-ax3-11`: logger/gallery passed in dark appearance at accessibility text.
- Disk container close/reopen, snapshot mutation isolation, previous performance,
  bodyweight completion and timer recovery are covered by the unit suite.
- All 19 approved color-role pairs pass light/dark; `git diff --check` clean.
- GitNexus impacts checked before symbol changes; final whole-worktree detection:
  416 changed symbols, 75 affected processes, 93 tracked changed files, CRITICAL.
  This includes preserved user/Claude work. New unindexed files also received
  explicit source/build/runtime review; UNKNOWN graph results were not treated
  as safety guarantees.

Canonical results, commands, screenshots and caveats: `docs/VERIFICATION.md`.
Every original requirement is mapped in `docs/MILESTONE-1-AUDIT.md`.
Result bundles rechecked 2026-10-04: the expected failure is the deliberately
unexecuted SwiftData `.deny` runtime check, not a passing behavior test.
A fresh 2026-10-04 native app/widget build passed; current evidence and source
hashes are recorded in `docs/verification/AUDIT-20261004.json`.

## Handoff

Open `fitbod.xcodeproj`, scheme `fitbod`, and run an iPhone simulator. DEBUG gallery:
Today → Settings → Developer → Component gallery. Core logging requires no login
or backend. Use dedicated simulators for tests because initial test launch resets
their store; normal relaunch does not.

Physical VoiceOver, haptics, notification authorization and Live Activity lifecycle
are not claimed as demonstrated. Larger catalog categories, program scheduling
proof, richer analytics, populated backup round-trips and sync remain roadmap
work. Historical incompatible stores are preserved by move-aside, not migrated.
