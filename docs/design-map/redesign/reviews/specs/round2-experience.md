# Round 2 verification: experience lens

You reviewed draft v1 of the Today/Program redesign bundle and wrote `reviews/round1-claude-experience.md`.
The bundle is now draft v2.
Bundle: `/Users/chrissaechao/Desktop/fitbod/docs/design-map/redesign/`.
Repository: `/Users/chrissaechao/Desktop/fitbod` at commit 0ef702ea (unchanged since round 1).
Read `changelog.md` and `review-log.md` first; the log maps every round-1 finding to a resolution or an accepted-with-reason entry.

Your job is to break draft v2, not to re-review v1.

1. For each finding in your round-1 report, say closed, partly closed or not closed, naming the v2 leaf and the line that closes it.
   Where `review-log.md` claims a closure you cannot find in the leaves, say so.
2. Attack v2 fresh with your lens:
   - Do `hierarchy.md`, `today-layouts.md`, `program-layouts.md` and `evaluation.md` agree with each other on every state, label, precedence rule and example week? Name every contradiction.
   - Does every state still pass the brief's five-second test, and is there any state where the lifter has no obvious next action or a wrong one? Walk the new precedence (T-RESUME > T-READY > T-DONE > T-FIX > T-ATTACH > T-REST > T-TODAY > T-PICK > T-FIRST) for the day after a block ends, a rest day with a ready block waiting, and a finished workout followed by a second session.
   - Does the one-notice rule hold, and is the review notice reachable in every situation where `pendingReviewBlocks` in `fitbod/Periodization/BlockReviewView.swift` returns a block?
   - Does the session sheet's slot rule (O-2) produce a surprising rotation jump for any ordinary double or swap? Trace it against `TodayResolver` in `fitbod/Periodization/`.
   - Copy: check every new label against the glossary in `CLAUDE.md`, the glyph table in `docs/design-system/iconography.md` and `docs/design-map/decisions.md`; check the 390pt fit of the plan line and the this-week row.
   - Do the accepted-with-reason items in `review-log.md` hold up, or would you still block on one?
3. Rank by blast radius and split blockers from fix-soon.
   Each finding states Trigger, Mechanism, Blast radius and the Smallest fix.

Write the report to `<bundle>/reviews/round2-claude-experience.md`.
Do not edit any other file.
Then report `worker_done` with one verdict line (final as written, or not final) and the number of blockers.
