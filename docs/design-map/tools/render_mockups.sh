#!/bin/bash
# Renders four PNGs beside each mock-up with Chrome headless, at 2x like the
# screenshots: <id>-390-light.png, <id>-390-dark.png, <id>-440-light.png and
# <id>-440-dark.png. The page reads `theme` and `w` from its query string.
# New headless Chrome lays every page out at least 500 px wide, but the
# screenshot is the window size. So each page draws a fixed phone frame
# (390x844 or 440x956) at the top left and never sizes it with vw, vh or
# media queries.
#
#   docs/design-map/tools/render_mockups.sh                  # every mockups/*.html
#   docs/design-map/tools/render_mockups.sh mockups/a.html   # only these pages
set -euo pipefail

chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mockups="$(cd "$(dirname "$0")/../mockups" && pwd)"
[ -x "$chrome" ] || { echo "Google Chrome is not installed at $chrome" >&2; exit 1; }

pages=("$@")
[ ${#pages[@]} -gt 0 ] || pages=("$mockups"/*.html)
for page in "${pages[@]}"; do
  [ -f "$page" ] || { echo "no such page: $page" >&2; exit 1; }
  folder="$(cd "$(dirname "$page")" && pwd)"
  id="$(basename "$page" .html)"
  for size in 390x844 440x956; do
    width="${size%x*}"
    for theme in light dark; do
      out="$folder/$id-$width-$theme.png"
      profile="$(mktemp -d)"
      rm -f "$out"
      # The page's fonts are file:// URLs outside its folder, so Chrome must allow file access.
      "$chrome" --headless --disable-gpu --hide-scrollbars --allow-file-access-from-files \
        --user-data-dir="$profile" --force-device-scale-factor=2 --window-size="${size/x/,}" \
        --virtual-time-budget=2000 --screenshot="$out" \
        "file://$folder/$id.html?theme=$theme&w=$width" >/dev/null 2>&1 || true
      rm -rf "$profile"
      [ -s "$out" ] || { echo "Chrome wrote no screenshot for $id at $width $theme" >&2; exit 1; }
      echo "rendered ${out#"$mockups"/}"
    done
  done
done
