# Roadmap after the usable workout milestone

Priorities build on the native implementation. See [verification](VERIFICATION.md)
for the exact device and test coverage and [the closeout report](MILESTONE-1-CLOSEOUT.md)
for decisions and open flags.

## Finish the current milestone first

The latest complete suite has four UI failures. Prepared interaction fixes need
a rerun, followed by the full authored journey on both required phones at AX3,
the final full suite, staged GitNexus checks, grouped commits and main push.
The current sandbox blocks the required simulator and repository operations;
see [verification](VERIFICATION.md). Items below remain future work, not reasons
to mark those acceptance checks complete.

| Priority | Work | Starting point | Acceptance evidence |
| --- | --- | --- | --- |
| P1 | Reliable block-based programs | Routine/session graph, rotation/fixed-weekly resolver, block phases and lifecycle already exist. | Author a multiweek block, reorder sessions, change training days, complete rotations and end/archive it; prove schedule and historical prescription behavior across relaunch. |
| P1 | Weight provenance and conversion | Unit settings currently relabel numbers; exercise overrides win. | Store the unit of each logged load, convert explicitly, and reconcile mixed-unit history, PRs and tonnage before offering conversion. |
| P1 | Volume boundary and render audit | Weekly volume uses fixed-second week offsets; missing-target views create transient model fallbacks. | Prove both daylight-saving transitions, use calendar week boundaries, and prove rendering cannot insert a fallback relationship into SwiftData. |
| P1 | Catalog curation and safe import | 900 bundled records, 702 strength-oriented imports, stable upstream IDs and local machine additions. | Preserve custom exercises and history through an incremental import; validate missing equipment/muscles, duplicates, image fallback and all new filters. Add duration/distance models before expanding beyond supported workout types. |
| P2 | Richer analytics | Session history, exercise progress, PRs, weekly tonnage and muscle volume screens already exist. | Add clear trends over chosen periods, comparable intent/units, volume/frequency breakdowns and empty/sparse-data explanations; reconcile every aggregate against logged sets. |
| P2 | Logger density | Default set rows are approximately 143pt tall; accessibility sizes stack inputs. | Offer a compact default layout without reducing 44pt actions, losing Previous/RPE context, or clipping at accessibility sizes. |
| P2 | Live Activities release quality | Rest-timer ActivityKit bridge and widget extension already exist. | On a physical iPhone, verify lock screen/Dynamic Island, permission denied, timer adjustment, expiry, app termination and activity cleanup without duplicate activities. |
| P3 | Portable backup and restore confidence | CSV/JSON export and local backup UI exist. | Restore a real populated backup on a second installation, compare entities and history, recover interrupted operations and expose last-backup metadata. |
| P3 | Optional sync | No backend, accounts or cloud storage in milestone 1. | Define ownership/conflict rules, schema evolution and snapshot immutability; prove edits and deletions converge after offline changes on two devices without losing sets. Keep local use independent of connectivity. |

Accessibility remains part of each feature's acceptance: small and large phone,
larger text, light/dark contrast, VoiceOver and Reduce Motion. Preserve the small
design system; add a component only when multiple real screens need it.

## Decisions awaiting product direction

- **First logs and records:** the first logged set in each intent/rep-range/kind
  bucket establishes a PR, so a first workout can show `PR × 19`. Decide whether
  baseline records should count as celebrated new records. The badge counts
  record kinds, not exercises or sets.
- **Deload misses:** keep the locked D-14 rule, which counts misses below the
  top of the prescribed rep range. Decide whether only misses below the bottom
  should count. Signal 3 requires three finished sessions and excludes live
  workouts.
- **Today wording:** the fatigue summary's working-set total sums weighted
  muscle contributions; one compound set can contribute to multiple muscles.
  Decide whether to label that total “muscle sets” or show physical set count.
- **History range:** “Per week” is observed frequency, not adherence against a
  training schedule. Real adherence needs a defined denominator.

## Release checks and remaining surfaces

- Run physical-device VoiceOver traversal, haptics, notification permission
  denial, background/terminated timer delivery and lock-screen/Dynamic Island
  lifecycle. Simulator accessibility trees do not establish those behaviors.
- Prove populated backup/restore on a second installation. SchemaV7 recovery
  preserves incompatible stores separately; it does not migrate them.
- Resolve the SwiftData `.deny` runtime issue before promising hard-delete
  enforcement. Its known-issue test deliberately avoids the aborting operation.
- Finish the Block Review export and PR sections: the current `EXPORT` header
  text has no action, and the PR summary is a placeholder. Complete their
  interaction tests with the block-program journey.
- Audit secondary analytics accessibility: combined exercise-history/PR
  readouts, missing-value announcements in recap/block review, and clearer
  distinction between absent and below-MEV heatmap colors.
- Curate pattern metadata before restoring the hidden Pattern filter. Review
  the currently unwired `RoutinesListView` before reusing or removing it.
- Extend CI coverage deliberately: the existing workflow runs on `claude/**`,
  PRs and manual dispatch; a direct push to `main` does not trigger it.

## Removed in Milestone 1 closeout

- New Block's Off-Season preset, because it had no definition: picking it only
  renamed the block. Presets now come from the one block template catalog.
- New Block's Pre-Meet preset, because it had no definition: picking it only
  renamed the block. Presets now come from the one block template catalog.
- EDIT BLOCK's top SAVE, because the top save now saves a draft (SAVE DRAFT),
  which only a new block needs. EDIT BLOCK saves with its bottom SAVE CHANGES
  alone.
