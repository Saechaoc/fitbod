# Roadmap swarm, 2026-11-12 to 2026-11-16

Archived 2026-11-16.
The swarm finished every slice it planned; [ROADMAP.md](../../ROADMAP.md) owns current status, the open phone checks and the user's open calls.
These are historical notes, not a separate backlog, and nothing here records accepted behavior.
The plan itself lived outside the repository, at `~/.claude/plans/fitbod-swarm/`, so it never competed with the roadmap.

## How it ran

Two building agents worked at once (K = 2), each a Claude subagent in its own git worktree, on its own branch `swarm/<slice>` and its own lane's simulators.
The orchestrator session reviewed each slice with a `swift-reviewer` subagent, sent the findings back, rebased the slice on `main`, fast-forwarded and pushed `main`, installed the build on the phone and updated the roadmap index.
A two-token lock (`ui-lock.sh`) capped the simulator UI runs going at once; the full tier ran only before a large slice or a schema change landed.
Slices in one lane ran one at a time, and lane A kept the approved redesign order RM-010 to RM-018.

## Included scope

| Lane | Slice | Roadmap entry | Landed code commits |
|---|---|---|---|
| A | A1 | [RM-010](../../ROADMAP.md#rm-010) Volume deload advice | `81d7596f`, `ad6c74fb` |
| A | A2 | [RM-011](../../ROADMAP.md#rm-011) Program's Now, Planned and Past | `4b6c0bed`, `874d4ae5`, `a3902f22`, `fe05c084` |
| A | A3 | [RM-012](../../ROADMAP.md#rm-012) Program's resume and discard | `79b1da56`, `917cc1df`, `6bc5db15` |
| A | A4 | [RM-013](../../ROADMAP.md#rm-013) opt-in review notice | `affecf16`, `c615671b`, `461a49a3`, `76a75038` |
| A | A5 | [RM-014](../../ROADMAP.md#rm-014) next-session and next-day lines | `48abcb26`, `19866099` |
| A | A6 | [RM-015](../../ROADMAP.md#rm-015) Program's This week | `c4d12622`, `e9a5ea1a`, `64508339` |
| A | A7 | [RM-016](../../ROADMAP.md#rm-016) a review's origin and End's consequences | `e36b6c2e`, `a49b84ce`, `865bfef0` |
| A | A8 | [RM-017](../../ROADMAP.md#rm-017) readable volume | `300abd3f`, `716b793f` |
| A | A9 | [RM-018](../../ROADMAP.md#rm-018) empty routine picker | `e96b51f3` |
| B | B1 | [RM-022](../../ROADMAP.md#rm-022) slice 7, coverage fill | `e150ed0e`, `8affc314`, `bd49de4a`, `bdc3c43b`, `9f452ade` |
| B | B2 | [RM-022](../../ROADMAP.md#rm-022) slice 8, a sibling's estimate | `abdcd70f`, `a9d31e33` |
| B | B3 | [RM-027](../../ROADMAP.md#rm-027) first delivery, Library results | `58f6bac1`, `ddc7e271` |
| C | C1 | [RM-019](../../ROADMAP.md#rm-019) stalled exercises | `fd417eeb`, `e36ffd4f`, `2d6fe777`, `41062e0c`, `a2fc9ca7` |
| C | C2 | [RM-020](../../ROADMAP.md#rm-020) past weekly recaps | `ffc796c5`, `cd10bdb6` |
| C | C3a | [RM-023](../../ROADMAP.md#rm-023) comparable periods and intents | `91063401`, `68157e6b` |
| C | C3b | [RM-023](../../ROADMAP.md#rm-023) Compare and older records | `af4e9615`, `312f2d2d` |
| D | D1 | [RM-062](../../ROADMAP.md#rm-062) bouts out of set counts | `61028a70`, `2b00f598`, `e322f70f` |
| D | D2 | [RM-025](../../ROADMAP.md#rm-025) plate calculator from a set | `74b3dda6`, `1e352952`, `8f27b095`, `acbbafb4` |
| D | D3a | [RM-026](../../ROADMAP.md#rm-026) supersets | `f9095b5c`, `78aad181` |
| D | D3b | [RM-026](../../ROADMAP.md#rm-026) duplication | `797f71c3`, `eba20353` |
| D | D3c | [RM-026](../../ROADMAP.md#rm-026) ordered multi-select | `e8680c34` |
| D | D3d | [RM-026](../../ROADMAP.md#rm-026) progression eligibility | `a3c79cec`, `4e2bea1d` |
| D | D3e | [RM-026](../../ROADMAP.md#rm-026) archived routine inspection | `a61d64d7`, `5122079c` |
| E | E1 | [RM-053](../../ROADMAP.md#rm-053) nightly trigger | `fd56e9f2` |
| E | E2 | [RM-001](../../ROADMAP.md#rm-001), [RM-053](../../ROADMAP.md#rm-053) nightly failures | `5c7c4d47` |
| E | E3 | [RM-054](../../ROADMAP.md#rm-054) reveal's swipe | `ed5bac4a` |
| E | E4 | [RM-002](../../ROADMAP.md#rm-002) rollback after a failed save | `4cad5de0`, `90c7bf27` |
| E | E5 | [RM-004](../../ROADMAP.md#rm-004) launch actors' writes | `9f7d0fdc`, `3451d3cd` |

The orchestrator also landed `f3a67a71` (each test run gets its own folder) and `97b31b92` (no warm-up ramp for a lift with no weight yet).
Each slice's roadmap entry holds its test classes, counts, captures and limits; the `docs(roadmap)` commits between these record the index.

## Excluded scope

RM-029's populated restore proof was deprioritized by the user on 2026-11-12 and stayed out.
No slice changed the schema, so no store rehearsal ran.
Each slice kept its open product decisions as today's behavior and left them for the user in the roadmap's Needs input table.
VoiceOver, AX3 and two-phone checks stayed deferred to workflow stability, as the prototype stage asks.

## Results and limits

The last unit-target runs passed 1,367 of 1,370 (D3e) and 1,371 of 1,374 (B3), with 2 skipped and 1 expected failure.
The largest full tier, before A6 landed, ran 1,460 tests with 0 failures, 2 skipped and 1 expected failure.
After the last landing, a full tier on `main` (`62b84015`, app code as `faaff623`) ran 1,499 tests with 0 failures, 2 skipped and 1 expected failure, both UI shards clean and the widget build passing (`full-20261116-160324-93275`).
A throwaway 390pt tour of the swarm's screens in light and dark found two new layout and copy flaws, filed under [RM-035](../../ROADMAP.md#rm-035) and [RM-044](../../ROADMAP.md#rm-044); the store rehearsal passed on a copy of the phone's store pulled the same day.
Landings were installed on the user's iPhone 15 Pro Max as they went, often several at once, and test-only ones not at all; what only the phone can show stays open as rows in the roadmap's Needs input table.
Evidence lines that cited commits from rebased branches were corrected on 2026-11-16, so evidence that names a commit names the one on `main`.
`ui-lock.sh --all` held the first token while it waited for the second, so a full tier is started only when no slice is in its UI phase.
