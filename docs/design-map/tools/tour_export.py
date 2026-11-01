#!/usr/bin/env python3
"""Export the design tour's screenshots and trees from one .xcresult bundle.

Run:
  python3 -I tools/tour_export.py --result X.xcresult --img screens/img \
      --tree screens/tree --full $DESIGN_WORK/full

Modelled on scripts/ci/collect_evidence.py:
  * `xcrun xcresulttool export attachments` writes every attachment and a
    manifest.json that maps each file to its suggestedHumanReadableName;
  * the name loses the `_<n>_<UUID>` suffix XCTest adds;
  * screenshots keep a full-size copy in --full and go into --img through
    `sips -s format png -Z 1700` (2x on both phones);
  * `<name>.tree` text attachments are trimmed to the element subtree, with
    memory addresses removed, and written to --full; main-state trees (no
    `--` in the screen part) also go to --tree as `<screen>.txt`.
Later exports overwrite earlier ones, so one test can be rerun alone.
Only macOS tooling and the standard library are used.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

SUFFIX = re.compile(r"_\d+_[0-9A-Fa-f-]{36}$")
# <phone>-<size>-<appearance>-<screen>, such as 17e-default-light-today--empty
NAME = re.compile(r"^(17e|17promax|\d+pt)-(default|ax3)-(light|dark)-(.+)$")
ADDRESS = re.compile(r", 0x[0-9a-f]+")
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".heic"}


def trim_tree(text: str) -> str:
    """Keeps the 'Element subtree' part of app.debugDescription."""
    start = text.find("Element subtree:")
    end = text.find("Path to element:")
    body = text[start:end] if start >= 0 else text
    return ADDRESS.sub("", body).rstrip() + "\n"


def export(result: pathlib.Path, img: pathlib.Path, tree: pathlib.Path, full: pathlib.Path) -> int:
    img.mkdir(parents=True, exist_ok=True)
    tree.mkdir(parents=True, exist_ok=True)
    full.mkdir(parents=True, exist_ok=True)
    raw = pathlib.Path(tempfile.mkdtemp(prefix="tour-export-"))
    try:
        subprocess.check_call(
            ["xcrun", "xcresulttool", "export", "attachments", "--path", str(result), "--output-path", str(raw)],
            stdout=subprocess.DEVNULL,
        )
        manifest = json.loads((raw / "manifest.json").read_text())
        shots = trees = 0
        for test in manifest:
            for att in test.get("attachments", []):
                src = raw / att.get("exportedFileName", "")
                suggested = pathlib.Path(att.get("suggestedHumanReadableName") or src.name)
                # XCTest keeps ".tree" as the suggested name's extension.
                human = SUFFIX.sub("", suggested.stem)
                if not src.exists():
                    continue
                if suggested.suffix == ".tree":
                    name = human
                    trimmed = trim_tree(src.read_text(errors="replace"))
                    (full / f"{name}.txt").write_text(trimmed)
                    match = NAME.match(name)
                    if match and match.group(1) == "17e" and match.group(2) == "default" \
                            and match.group(3) == "light" and "--" not in match.group(4):
                        (tree / f"{match.group(4)}.txt").write_text(trimmed)
                    trees += 1
                elif src.suffix.lower() in IMAGE_SUFFIXES and NAME.match(human):
                    original = full / f"{human}.png"
                    subprocess.check_call(["sips", "-s", "format", "png", str(src), "--out", str(original)],
                                          stdout=subprocess.DEVNULL)
                    subprocess.check_call(["sips", "-s", "format", "png", "-Z", "1700", str(original),
                                           "--out", str(img / f"{human}.png")], stdout=subprocess.DEVNULL)
                    shots += 1
        print(f"exported {shots} screenshots and {trees} trees from {result.name}")
        return 0
    finally:
        shutil.rmtree(raw, ignore_errors=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--result", required=True, type=pathlib.Path)
    parser.add_argument("--img", required=True, type=pathlib.Path)
    parser.add_argument("--tree", required=True, type=pathlib.Path)
    parser.add_argument("--full", required=True, type=pathlib.Path)
    args = parser.parse_args()
    if not args.result.exists():
        print(f"no result bundle at {args.result}", file=sys.stderr)
        return 1
    return export(args.result, args.img, args.tree, args.full)


if __name__ == "__main__":
    raise SystemExit(main())
