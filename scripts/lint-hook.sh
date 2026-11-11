#!/usr/bin/env bash
#
# lint-hook.sh — Claude Code PostToolUse hook, wired in .claude/settings.json.
# Lints the app Swift file an agent just edited with .swiftlint.yml, run from
# that file's own git root so a worktree uses its own rules, and hands any
# violation back to the agent (exit 2 shows stderr to it). Silent when the
# file is clean, is not app Swift, or SwiftLint is missing.

file="$(jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[[ "$file" == *.swift && -f "$file" ]] && command -v swiftlint >/dev/null || exit 0
file="$(realpath "$file")"
root="$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null)" || exit 0
case "${file#"$root"/}" in fitbod/*|FitbodWidgets/*) ;; *) exit 0 ;; esac
out="$(cd "$root" && swiftlint lint --quiet "${file#"$root"/}" 2>&1)" && exit 0
echo "$out" >&2
exit 2
