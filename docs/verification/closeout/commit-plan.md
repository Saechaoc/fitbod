# Prepared commit groups

**Not staged, committed or pushed.** The user already authorized grouped commits
and a push to main. Final verification is open, and this session makes `.git`
read-only. The first exact-path staging attempt failed creating `.git/index.lock`
with Operation not permitted; the index remains empty. Complete the checks in [VERIFICATION.md](../../VERIFICATION.md) first.

Each manifest lists exact repository-relative paths, one per line. The list is
a snapshot for review, not permission to include future unrelated edits to the
same files. Recheck every diff immediately before staging. Do not use `git add .`
or `git add -A`. Review the groups in order; shared source dependencies mean the
final combined tree, not every intermediate commit, has the recorded test run.

| Group | Paths | Proposed commit | Exact manifest |
| --- | --- | --- | --- |
| 01-design | 27 | feat(design): add accessible BRU primitives and native icon | [Paths](commit-groups/01-design.paths) |
| 02-logger | 46 | fix(logger): preserve workout data and consistent weight labels | [Paths](commit-groups/02-logger.paths) |
| 03-authoring | 19 | feat(authoring): complete native exercise and session workflows | [Paths](commit-groups/03-authoring.paths) |
| 04-navigation | 20 | feat(navigation): connect history and refine weekly volume | [Paths](commit-groups/04-navigation.paths) |
| 05-deload | 2 | fix(deload): assess missed targets from finished sessions | [Paths](commit-groups/05-deload.paths) |
| 06-ui-tests | 24 | test(ui): cover current navigation and workout journeys | [Paths](commit-groups/06-ui-tests.paths) |
| 07-docs-reference | 165 | docs: record milestone evidence and open release flags | [Paths](commit-groups/07-docs-reference.paths) |

Before each commit, verify the staged path list matches its manifest, review
`git diff --cached`, and run GitNexus `detect_changes(scope: staged)`. Report any
HIGH/CRITICAL impact. Do not commit until unexpected scope is resolved. No
Co-Authored-By trailer. Push main normally after all required results are recorded;
no force push is needed or authorized here.

Example for the first group, after environment access and verification recover:

```sh
git add --pathspec-from-file=docs/verification/closeout/commit-groups/01-design.paths
git diff --cached --name-only
git diff --cached --check
git diff --cached
# GitNexus detect_changes({repo: "fitbod", scope: "staged"})
# Review its result before committing; repeat for every group.
```

[Machine-readable ownership manifest](commit-manifest.json) includes the entire
excluded-path list. Preserved exclusions include `.planning/config.json`,
`.planning/research/STACK.md`, `docs/STACK-RESEARCH.md`, existing top-level design
exports outside `bru-screens/Fitbod-Session/`, GitNexus/tooling files and unrelated
quick tasks. The supplied Fitbod-Session reference snapshot is included in the
documentation group, as requested in the milestone work.

New report files must be added explicitly to the documentation manifest if a
later verification run creates them. Recheck that no unrelated path has entered
any group before staging.
