#!/usr/bin/env python3
"""BRU color tokens: table and contrast check.

Run from anywhere:  python3 docs/design-system/tokens_check.py

Reads the light and dark values straight from the asset catalog, so the
numbers can never drift from the app. Prints:
  1. the token table (Markdown, paste into color.md when tokens change),
  2. the WCAG 2.2 contrast ratio of the approved semantic foreground pairs,
     in light and dark mode,
  3. the hotspot: pairs below their required ratio.

Edit only PAIRS below. Each pair is (foreground, background, where it is
used, required ratio). 4.5 is WCAG AA for normal text. 3.0 is AA for large
text (at least 18pt regular or 14pt bold) and for control boundaries.
Exit code is 1 when any pair fails, so this can run in CI.
"""

import json
import sys
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[2] / "fitbod" / "Assets.xcassets"

PAIRS = [
    # Text on the main surfaces
    ("bruInk", "bruPaper", "body text on paper", 4.5),
    ("bruInk", "bruBg", "text on the screen-edge background", 4.5),
    ("bruInk", "bruBg2", "text in inset cards", 4.5),
    ("bruMuted", "bruPaper", "secondary text on paper", 4.5),
    ("bruMuted", "bruBg", "secondary text on the screen-edge background", 4.5),
    ("bruMuted", "bruBg2", "secondary text in inset cards", 4.5),
    ("bruMuted", "bruFaint", "disabled button label on its fill", 4.5),
    ("bruPaper", "bruInk", "text on ink slabs and the selected segment", 4.5),
    # The signal accent
    ("bruOnSignal", "bruSignal", "CTA label on signal fill", 4.5),
    ("bruSignalText", "bruPaper", "signal text on paper", 4.5),
    ("bruSignalText", "bruBg", "signal text on the screen-edge background", 4.5),
    ("bruSignalText", "bruBg2", "signal text in inset cards", 4.5),
    ("bruSignalOnInk", "bruInk", "signal text on ink slabs", 4.5),
    ("bruInk", "bruPaper", "signal control outer outline against the surrounding surface", 3.0),
    # Status colors
    ("bruOnSignal", "bruAmber", "label on the amber warning chip", 4.5),
    ("bruOnSignal", "bruGreen", "label on the green encouragement chip", 4.5),
    ("bruPaper", "bruBlue", "label on the blue phase badge", 4.5),
    # Tab bar
    ("bruInk", "bruTabSurface", "inactive tab label", 4.5),
    ("bruTabSurface", "bruInk", "active tab label on the ink cell", 4.5),
]


def parse_component(value) -> int:
    text = str(value)
    if text.startswith("0x"):
        return int(text, 16)
    number = float(text)
    return round(number * 255) if number <= 1.0 else int(number)


def load_tokens() -> dict:
    tokens = {}
    for contents in sorted(CATALOG.glob("*.colorset/Contents.json")):
        name = contents.parent.name.removesuffix(".colorset")
        data = json.loads(contents.read_text())
        for entry in data.get("colors", []):
            parts = entry["color"]["components"]
            rgb = tuple(parse_component(parts[k]) for k in ("red", "green", "blue"))
            appearances = entry.get("appearances") or []
            mode = "dark" if any(a.get("value") == "dark" for a in appearances) else "light"
            tokens.setdefault(name, {})[mode] = rgb
    return tokens


def luminance(rgb) -> float:
    def channel(c: int) -> float:
        s = c / 255
        return s / 12.92 if s <= 0.04045 else ((s + 0.055) / 1.055) ** 2.4

    r, g, b = (channel(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(fg, bg) -> float:
    lighter, darker = sorted((luminance(fg), luminance(bg)), reverse=True)
    return (lighter + 0.05) / (darker + 0.05)


def hex_of(rgb) -> str:
    return "#%02X%02X%02X" % rgb


def main() -> int:
    tokens = load_tokens()
    bru = {k: v for k, v in tokens.items() if k.startswith("bru")}

    print("| Token | Light | Dark |")
    print("| --- | --- | --- |")
    for name, modes in bru.items():
        light = hex_of(modes["light"]) if "light" in modes else "-"
        dark = hex_of(modes.get("dark", modes.get("light")))
        print(f"| `Color.{name}` | `{light}` | `{dark}` |")

    others = sorted(set(tokens) - set(bru))
    if others:
        print(f"\nNon-BRU colorsets in the catalog: {', '.join(others)}")

    print("\n| Foreground on background | Use | Light | Dark | Needs |")
    print("| --- | --- | --- | --- | --- |")
    failures = []
    for fg, bg, use, needed in PAIRS:
        cells = []
        for mode in ("light", "dark"):
            f = bru[fg].get(mode, bru[fg]["light"])
            b = bru[bg].get(mode, bru[bg]["light"])
            ratio = contrast(f, b)
            ok = ratio >= needed
            cells.append(f"{ratio:.2f}" + ("" if ok else " FAIL"))
            if not ok:
                failures.append(f"{fg} on {bg} ({mode}): {ratio:.2f} < {needed} - {use}")
        print(f"| {fg} on {bg} | {use} | {cells[0]} | {cells[1]} | {needed} |")

    print("\nhotspot:", "none, every pair passes" if not failures else "")
    for failure in failures:
        print("  -", failure)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
