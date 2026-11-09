# Fitbod agent notes

Fitbod is a prototype: learn fast, scale effort to the change, never skip data integrity, correctness, privacy or security.
Read `docs/DEVELOPMENT.md` for what can wait and when it comes back, and `CLAUDE.md` for the stack and conventions.
Use `docs/SETUP.md` for build/test commands, `CONVENTIONS.md` for code patterns and `ARCHITECTURE.md` for technical contracts.

`docs/ROADMAP.md` is the sole source for priorities, unfinished work, product decisions and acceptance criteria.
Read the relevant RM entry before starting; update it when scope, status, dependencies or evidence changes.
Keep stable RM IDs and original finding IDs. Do not maintain a separate backlog, ticket ledger, handoff status or mandatory GSD workflow.
Technical contracts live in `ARCHITECTURE.md`; dated audits and design references supply evidence, not current status.
Record concise test results and limitations in the relevant RM entry. Keep run logs and screenshots in CI artifacts or ignored local output; do not create report archives or evidence dumps in the repository.
Routine verification belongs to the agent: Planned → Active → Done means agreed scope works, appropriate checks pass and docs are current; personal sign-off is not a routine gate.
Use Implemented; verification pending for finished implementation with required unavailable proof. Keep the exact check open in the roadmap and continue independent work; involve the user only for unavailable observations or product decisions.
Separate Requires (real prerequisites), Scheduled after (delivery order) and Verify when (stability/release triggers).
Archive finished substantial implementation plans in `docs/archive/features/` with historical scope, build/commit, results and RM backlink, even when a separately recorded device check remains open. Older unsupported completion claims stay historically shipped; acceptance unrecorded, without a whole-app retest.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **fitbod** (11905 symbols, 233617 relationships, 219 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/fitbod/context` | Codebase overview, check index freshness |
| `gitnexus://repo/fitbod/clusters` | All functional areas |
| `gitnexus://repo/fitbod/processes` | All execution flows |
| `gitnexus://repo/fitbod/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
