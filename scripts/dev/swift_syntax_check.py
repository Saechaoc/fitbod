#!/usr/bin/env python3
"""Fast, offline Swift *syntax* check (no type checking) using tree-sitter.

Used during development on machines without Xcode to catch unbalanced
braces, malformed closures and similar mistakes before a CI build.
Usage: python3 scripts/dev/swift_syntax_check.py [paths...]
Requires: pip install tree-sitter-language-pack
"""
import pathlib
import sys

from tree_sitter_language_pack import get_parser

parser = get_parser("swift")


def errors(node, out):
    if node.type == "ERROR" or node.is_missing:
        out.append(node)
    for child in node.children:
        if child.has_error or child.type == "ERROR" or child.is_missing:
            errors(child, out)
    return out


def main(argv):
    roots = [pathlib.Path(a) for a in argv] or [pathlib.Path("fitbod"), pathlib.Path("fitbodTests"), pathlib.Path("fitbodUITests"), pathlib.Path("FitbodWidgets")]
    files = []
    for r in roots:
        files += [r] if r.is_file() else sorted(r.rglob("*.swift"))
    bad = 0
    for f in files:
        src = f.read_bytes()
        tree = parser.parse(src)
        if tree.root_node.has_error:
            errs = errors(tree.root_node, [])
            bad += 1
            for e in errs[:5]:
                line = e.start_point[0] + 1
                text = src.splitlines()[e.start_point[0]].decode(errors="replace").strip() if e.start_point[0] < len(src.splitlines()) else ""
                kind = "missing " + e.type if e.is_missing else "error"
                print(f"{f}:{line}: {kind}: {text[:120]}")
    print(f"checked {len(files)} files, {bad} with syntax errors")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
