# Round 2 verification: coverage lens

You reviewed draft v1 of the Today/Program redesign bundle and wrote `reviews/round1-claude-coverage.md`.
The bundle is now draft v2.
Bundle: `/Users/chrissaechao/Desktop/fitbod/docs/design-map/redesign/`.
Repository: `/Users/chrissaechao/Desktop/fitbod` at commit 0ef702ea (unchanged since round 1).
Read `changelog.md` and `review-log.md` first; the log maps every round-1 finding to a resolution or an accepted-with-reason entry.

Your job is to break draft v2, not to re-review v1.

1. For each finding in your round-1 report, say closed, partly closed or not closed, naming the v2 leaf and the line that closes it.
   Where `review-log.md` claims a closure you cannot find in the leaves, say so.
2. Attack v2 fresh with your lens:
   - Does `functionality-map.md` v2 still account for every capability in `fitbod/Views/TodayView.swift`, `fitbod/Periodization/ProgramView.swift`, their child views and `docs/design-map/workflows/*.md`, including the rows the revision added?
   - Are the six corrected audit rows (A-01, A-02, A-04, A-06, A-14, A-26) true against main and the screenshots in `docs/design-map/screens/img/`?
   - Does every `plan.md` step name every test suite that references a symbol or string the step removes? Spot-check with `rg` over `fitbodTests/` and `fitbodUITests/`.
   - Is every entry in the "Reviewer claims re-checked against the source" list at the end of `review-log.md` true? Name the file and line when you disprove one.
   - Do the five seeds step 1.3 adds describe states no existing seed in `fitbod/App/` already produces?
3. Rank by blast radius and split blockers from fix-soon.
   Each finding states Trigger, Mechanism, Blast radius and the Smallest fix.

Write the report to `<bundle>/reviews/round2-claude-coverage.md`.
Do not edit any other file.
Then report `worker_done` with one verdict line (final as written, or not final) and the number of blockers.
