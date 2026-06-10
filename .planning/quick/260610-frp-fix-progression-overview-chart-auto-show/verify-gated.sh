#!/usr/bin/env bash
# Task 1 verify: prove no week-1 force remains in NewBlockProgressionChart.
# Passes (exit 0, prints GATED-OK) only when BOTH the `selectedWeek ?? 1`
# fallback and the `selectedWeek = 1` assignment are gone from the file.
set -euo pipefail
FILE="fitbod/Periodization/BlockBuilderView.swift"
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

fail=0
if rg -q 'selectedWeek \?\? 1' "$FILE"; then
  echo "FAIL: 'selectedWeek ?? 1' fallback still present"
  fail=1
fi
if rg -q 'selectedWeek = 1' "$FILE"; then
  echo "FAIL: 'selectedWeek = 1' force-assignment still present"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "STILL-FORCES-W1"
  exit 1
fi

echo "GATED-OK"
