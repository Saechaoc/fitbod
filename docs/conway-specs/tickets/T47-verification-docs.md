---
id: T47
title: Verification docs
phase: 7
items: []
depends_on: [T46]
size: M
sim: none
owns: [docs/VERIFICATION.md, docs/MILESTONE-1-CLOSEOUT.md, docs/MILESTONE-1-AUDIT.md, docs/verification/BASELINE-20261003.md]
---

# T47: Verification docs

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

The verification docs describe runs from before this closeout, and some of their claims are wrong:

- `docs/VERIFICATION.md` says the AX3 journey has not been rerun, and lists AX3 failures that later tickets fixed.
- `docs/verification/BASELINE-20261003.md` lists `iphone-pro-max-ax3-dark-workout.png` as accessibility evidence, but that capture shows the item 10 defect, the warm-up ramp at AX3.
- No dark-mode Program screenshot exists.
- The deny-rule flag says only that the runtime check is a known issue.

## Target

- `docs/VERIFICATION.md`, `docs/MILESTONE-1-CLOSEOUT.md`, `docs/MILESTONE-1-AUDIT.md` and `docs/verification/BASELINE-20261003.md`.
- New screenshot files in `docs/verification/`.

## Change

1. Rewrite the run tables in `VERIFICATION.md` from the latest T44, T45 and T46 evidence: for each run, the phone name and id, text size, appearance, counts, duration and result bundle name.
   The run log copy in your evidence folder names the latest evidence folders, including any reruns, and its ledger gives each ticket's commit and outcome.
2. Replace the large-text limitation with what T45 proved.
   Find it by its text ("at large text"), not by a line number.
3. In `BASELINE-20261003.md`, add a note next to the `iphone-pro-max-ax3-dark-workout.png` link: the capture shows the item 10 defect and is replaced by a newer capture, which you link.
   Keep the old image file.
4. Copy into `docs/verification/` only the screenshots the docs cite, including dark-mode Program screenshots from T46 or its reruns, using the newest capture of each screen, under the names they were given.
5. In `MILESTONE-1-CLOSEOUT.md`, add a table of review items 1 to 47 and finding N1.
   Each row gives the ticket, the commit and the evidence (a test name or a screenshot), or the reason the item was removed or deferred.
6. Replace the deny-rule flag with the text of `evidence/T40/closeout-statement.md`, and add T41's backup result.
7. Keep these flags open, each with its next action: VoiceOver on a physical device, haptics, notification permission prompts, and a fully offline journey.
8. In `MILESTONE-1-AUDIT.md`, point each done criterion from [../requirements.md](../requirements.md) at its evidence.
   Mark a criterion met only where that evidence exists.

## Constraints

- Every claim needs evidence in the bundle or in `docs/verification/`.
  Where evidence is missing, write the claim as open.
- In the parts you edit, put one sentence on each line, and use "-" instead of em dashes, including in the title of `VERIFICATION.md`.
- Do not edit any changelog file.
- Copy only cited screenshots into the repo, never whole evidence folders.

## Ownership

You may edit the four docs in `owns` and add screenshot files to `docs/verification/`.
Ask before you edit anything else.

## Repro first

This ticket changes no code.
Before you edit, list in `notes.md` each claim in the four docs that the new evidence contradicts, with the evidence file that contradicts it.

## Observable acceptance

- Every run the docs cite matches a result in the T44, T45 or T46 evidence, with the same counts.
- The closeout table has 48 rows, and each row has evidence or a stated reason.
- No doc presents a screenshot that shows a defect as passing evidence.
- Every image the four docs link exists.
- Each open flag has a next action.
- `git diff --check` is clean for the four docs, and no line you wrote has an em dash.

## Hints

- The run log's ticket ledger gives each ticket's commit and outcome.
- `rg -n "png" docs/VERIFICATION.md docs/MILESTONE-1-CLOSEOUT.md` finds every image link.
- Review items and their severities are in Appendix A of the plan, `.planning/noble-wishing-conway.md`.
