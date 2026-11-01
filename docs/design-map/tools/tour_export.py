#!/usr/bin/env python3
"""Export the design tour's screenshots and trees from one .xcresult bundle.

Run:
  python3 -I tools/tour_export.py --result X.xcresult --img screens/img \
      --tree screens/tree --full $DESIGN_WORK/full
  python3 -I tools/tour_export.py --self-test

Modelled on scripts/ci/collect_evidence.py:
  * `xcrun xcresulttool export attachments` writes every attachment and a
    manifest.json that maps each file to its suggestedHumanReadableName;
  * the name loses the `_<n>_<UUID>` suffix XCTest adds;
  * screenshots keep a full-size copy in --full and go into --img at 2x
    scale (twice the phone's width in points), so 2 pixels are 1 point on
    both phones;
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
POINTS = {"17e": 390, "17promax": 440}  # screen widths in points


def width_2x(name: str) -> int:
    """The 2x pixel width of a tour screenshot, from the phone in its name."""
    phone = NAME.match(name).group(1)
    return 2 * (POINTS.get(phone) or int(phone.removesuffix("pt")))


def tour_name(suggested: str) -> str:
    """The tour's name for an attachment: its suggested name without the
    extension and the `_<n>_<UUID>` suffix XCTest adds."""
    return SUFFIX.sub("", pathlib.Path(suggested).stem)


def main_tree_screen(name: str) -> str | None:
    """The screen stem when `name` is a main-state tree for screens/tree/
    (17e, default text, light, no `--<state>`), else None."""
    match = NAME.match(name)
    if match and match.group(1, 2, 3) == ("17e", "default", "light") and "--" not in match.group(4):
        return match.group(4)
    return None


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
        # xcresulttool writes no manifest when the run attached nothing.
        manifest_path = raw / "manifest.json"
        manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else []
        shots = trees = 0
        for test in manifest:
            for att in test.get("attachments", []):
                src = raw / att.get("exportedFileName", "")
                suggested = att.get("suggestedHumanReadableName") or src.name
                name = tour_name(suggested)
                if not src.exists():
                    continue
                # XCTest keeps ".tree" as the suggested name's extension.
                if pathlib.Path(suggested).suffix == ".tree":
                    trimmed = trim_tree(src.read_text(errors="replace"))
                    (full / f"{name}.txt").write_text(trimmed)
                    if screen := main_tree_screen(name):
                        (tree / f"{screen}.txt").write_text(trimmed)
                    trees += 1
                elif src.suffix.lower() in IMAGE_SUFFIXES and NAME.match(name):
                    original = full / f"{name}.png"
                    subprocess.check_call(["sips", "-s", "format", "png", str(src), "--out", str(original)],
                                          stdout=subprocess.DEVNULL)
                    subprocess.check_call(["sips", "-s", "format", "png", "--resampleWidth", str(width_2x(name)),
                                           str(original), "--out", str(img / f"{name}.png")],
                                          stdout=subprocess.DEVNULL)
                    shots += 1
        print(f"exported {shots} screenshots and {trees} trees from {result.name}")
        return 0
    finally:
        shutil.rmtree(raw, ignore_errors=True)


def self_test() -> int:
    """Checks the name parsing against names copied from a real export."""
    uuid = "D1CE9B13-8E4D-4951-8830-53A8E9417ADA"
    assert tour_name(f"17e-default-light-today--smoke_0_{uuid}.png") == "17e-default-light-today--smoke"
    assert tour_name(f"17e-default-light-today_1_{uuid}.tree") == "17e-default-light-today"
    assert tour_name("Launch Screen") == "Launch Screen"
    assert NAME.match("Launch Screen") is None
    assert main_tree_screen("17e-default-light-dialog-end-block") == "dialog-end-block"
    assert main_tree_screen("17e-default-light-today--empty") is None
    assert main_tree_screen("17promax-default-light-today") is None
    assert main_tree_screen("17e-ax3-light-today") is None
    assert main_tree_screen("17e-default-dark-today") is None
    assert width_2x("17e-default-light-today") == 780
    assert width_2x("17promax-ax3-dark-today--empty") == 880
    assert width_2x("390pt-default-light-today") == 780
    tree = "Attributes\nElement subtree:\n →Application, 0x10a2b3c4d, pid: 7\nPath to element:\n →x\n"
    assert trim_tree(tree) == "Element subtree:\n →Application, pid: 7\n"
    print("self-test passed")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--self-test", action="store_true", help="check the name parsing and exit")
    parser.add_argument("--result", type=pathlib.Path)
    parser.add_argument("--img", type=pathlib.Path)
    parser.add_argument("--tree", type=pathlib.Path)
    parser.add_argument("--full", type=pathlib.Path)
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    if not (args.result and args.img and args.tree and args.full):
        parser.error("--result, --img, --tree and --full are required")
    if not args.result.exists():
        print(f"no result bundle at {args.result}", file=sys.stderr)
        return 1
    return export(args.result, args.img, args.tree, args.full)


if __name__ == "__main__":
    raise SystemExit(main())
