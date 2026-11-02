# Round 3 (Codex): experience lens on draft v3

You were dispatched to review draft v1 of the Today/Program redesign bundle and hit the ChatGPT usage limit before writing a report.
This round you take the experience lens: does every state tell the lifter what to do, and do the rules behave as a lifter expects?
Discard any notes you kept on v1; the bundle has changed twice since.
Bundle: `/Users/chrissaechao/Desktop/fitbod/docs/design-map/redesign/` (draft v3).
Repository: `/Users/chrissaechao/Desktop/fitbod` at commit 0ef702ea (unchanged since your first dispatch).
Read `index.md`, `changelog.md` and `review-log.md` first.
The log maps every round-1 and round-2 finding of the interim Claude reviewers to a resolution or an accepted-with-reason entry; nobody has reviewed v3 itself.

Your job is to break draft v3 for the lifter who uses it mid-workout.

1. Pick the ten claims in `review-log.md` with the widest blast radius (the seven blockers B-1 to B-5, B2-1, B2-2 and three fix-soon items of your choice) and say for each whether the leaves really close it, naming the leaf and the line.
2. Attack v3 fresh with the experience lens:
   - Do `hierarchy.md`, `today-layouts.md`, `program-layouts.md`, `functionality-map.md` and `evaluation.md` agree on every state, label, precedence rule and example value? Name every contradiction with both lines.
   - Walk the precedence T-RESUME > T-DONE > T-READY > T-FIX > T-ATTACH > T-REST > T-TODAY > T-PICK > T-FIRST for: the day after a block ends; a rest day with a ready block waiting; a finished workout followed by a second session; a ready block saved on the same day as a finished workout; a lifter whose only sessions sit in no routine. Is there a state with no obvious next action, or a wrong one?
   - The review notice: does the one-notice rule hold, and is the notice reachable wherever `pendingReviewBlocks` in `fitbod/Periodization/BlockReviewView.swift` returns a block? Is "the notice goes when START BLOCK ▸ starts the next block" (O-5) acceptable, or would you block on it?
   - The session sheet (O-2): trace the two-slot rule against `TodayResolver` in `fitbod/Periodization/` for a PPL ×2 routine with a session in two slots, for a swap, for a double, and for a start with no block. Does any ordinary action move the rotation somewhere the lifter would not expect? Does the "skips Pull A, Legs A" subline say the right thing?
   - Copy and fit: check every new label against the glossary in `CLAUDE.md`, the glyph table in `docs/design-system/iconography.md` and `docs/design-map/decisions.md`; check the 390pt fit of the two-line plan line with a long block name, the review notice row with a long block name, the this-week row, the deload hero's "~17 MIN", and a sheet row whose subline ends with "skips Pull A, Legs A".
   - "Saved Oct 3" on Planned cards and "oldest saved" as the ready-block order (O-6, O-14): does the lifter understand what the date means, and is there a case where two ready blocks make Today lead with the wrong one?
   - Do the accepted-with-reason items in `review-log.md` (rounds 1 and 2) hold up, or would you still block on one?
3. Rank by blast radius and split blockers from fix-soon.
   Each finding states Trigger, Mechanism, Blast radius and the Smallest fix.

Write the report to `<bundle>/reviews/round3-codex-experience.md`.
Do not edit any other file.
Then report `worker_done` through the Orca orchestration CLI as your original task instructions said, with one verdict line (final as written, or not final) and the number of blockers.
