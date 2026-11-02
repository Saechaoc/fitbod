# Round 3 (Codex): coverage lens on draft v3

You were dispatched to review draft v1 of the Today/Program redesign bundle and hit the ChatGPT usage limit before writing a report.
This round you take the coverage lens: does the proposal account for everything the app does today, and is every claim it makes about main true?
Discard any notes you kept on v1; the bundle has changed twice since.
Bundle: `/Users/chrissaechao/Desktop/fitbod/docs/design-map/redesign/` (draft v3).
Repository: `/Users/chrissaechao/Desktop/fitbod` at commit 0ef702ea (unchanged since your first dispatch).
Read `index.md`, `changelog.md` and `review-log.md` first.
The log maps every round-1 and round-2 finding of the interim Claude reviewers to a resolution or an accepted-with-reason entry; nobody has reviewed v3 itself.

Your job is to break draft v3.

1. Pick the ten claims in `review-log.md` with the widest blast radius (the seven blockers B-1 to B-5, B2-1, B2-2 and three fix-soon items of your choice) and say for each whether the leaves really close it, naming the leaf and the line.
2. Attack v3 fresh with the coverage lens:
   - Does `functionality-map.md` account for every capability in `fitbod/Views/TodayView.swift`, `fitbod/Periodization/ProgramView.swift`, their child views (`fitbod/Views/`, `fitbod/Periodization/`, `fitbod/Fatigue/`) and `docs/design-map/workflows/*.md`? Name every capability with no row, and every row whose "current" column misdescribes main.
   - Are the audit rows true against main and the screenshots in `docs/design-map/screens/img/`? Check A-01, A-02, A-04, A-06, A-14 and A-26 at least.
   - Does every `plan.md` step name every test suite that references a symbol, identifier or string the step removes or relabels? Spot-check with `rg` over `fitbodTests/` and `fitbodUITests/`; pay attention to the suites that read Swift files by path, to the five suites that match Program's block-card accessibility labels, and to the two suites that match the block band's uppercased block name "LIVE BLOCK".
   - Is every entry in the two "re-checked against the source" lists in `review-log.md` true? Name the file and line when you disprove one.
   - Do the three seeds step 1.3 adds describe states no seed in `fitbod/App/` already produces, and do the three existing seeds the plan reuses produce what it says?
   - Does `open-decisions.md` list every product call the layouts assume, or does a leaf assume a default no O-row records?
3. Rank by blast radius and split blockers from fix-soon.
   Each finding states Trigger, Mechanism, Blast radius and the Smallest fix.

Write the report to `<bundle>/reviews/round3-codex-coverage.md`.
Do not edit any other file.
Then report `worker_done` through the Orca orchestration CLI as your original task instructions said, with one verdict line (final as written, or not final) and the number of blockers.
