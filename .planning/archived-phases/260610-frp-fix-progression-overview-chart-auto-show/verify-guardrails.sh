#!/usr/bin/env bash
# Task 2 verify: build + run all four New Block guardrail suites on the iOS
# simulator, filtering xcodebuild output to keep context small.
# Override the destination by passing a name, e.g.:
#   ./verify-guardrails.sh "iPhone 16 Pro"
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

DEST_NAME="${1:-iPhone 16 Pro}"

xcodebuild test \
  -scheme fitbod \
  -destination "platform=iOS Simulator,name=${DEST_NAME}" \
  -only-testing:fitbodTests/NewBlockBuilderFidelityTests \
  -only-testing:fitbodTests/BlockBuilderViewCopyTests \
  -only-testing:fitbodTests/BlockBuilderViewActivationTests \
  -only-testing:fitbodTests/NewBlockProgressionChartTests \
  2>&1 | rg -i "Test Suite.*(passed|failed)|error:|\*\* TEST (SUCCEEDED|FAILED)" | tail -40

# Exit status reflects xcodebuild, not rg (rg drops non-matching lines).
exit "${PIPESTATUS[0]}"
