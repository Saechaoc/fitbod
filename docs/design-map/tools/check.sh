#!/usr/bin/env bash
#
# check.sh - the design map's full check: tools/check_map.py, then every
# Mermaid block rendered with mermaid-cli to prove that it parses.
#
#   tools/check.sh [--partial]
#
# Needs node (for npx) and Google Chrome, which tools/puppeteer.json names.
# The SVGs go to a temporary folder and are not kept.

set -euo pipefail

TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/design-map-check.XXXXXX")"
trap 'rm -rf "$OUT"' EXIT

status=0
python3 -I "$TOOLS/check_map.py" --mmd-out "$OUT" "$@" || status=1

shopt -s nullglob
blocks=("$OUT"/*.mmd)
failed=0
for block in "${blocks[@]}"; do
  if ! PUPPETEER_SKIP_DOWNLOAD=1 npx -y @mermaid-js/mermaid-cli@11.4.2 -q \
      -p "$TOOLS/puppeteer.json" -i "$block" -o "${block%.mmd}.svg" </dev/null > "${block%.mmd}.log" 2>&1; then
    echo "ERROR mermaid: $(basename "$block") does not render:"
    sed -n 1,15p "${block%.mmd}.log"
    failed=$((failed + 1))
  fi
done
echo "rendered    ${#blocks[@]} Mermaid blocks, $failed failed"
[[ $failed -eq 0 ]] || status=1
exit "$status"
