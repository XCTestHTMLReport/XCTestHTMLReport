#!/usr/bin/env python3
"""Renders every (tool, fixture) cell of the comparison matrix.

Each cell runs one acquired binary over a TEMP COPY of one fixture bundle —
never the fixture itself, because at least one shipped version mutates its
input. A tool that fails produces a failed cell with its stderr on disk; the
matrix always completes. DEVELOPER_DIR passes through untouched.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
CAPTURE_SCHEMA = os.path.join(HERE, "..", "capture_xcresult_schema.py")

# One shape serves 2.5.1 through HEAD (verified per tag); a future version
# that diverges gets its own entry keyed by label.
def invocation(binary, out_dir, bundle):
    return [binary, "-i", "-j", "--exclude-run-destination-info",
            "--json", "-o", out_dir, bundle]


def render_cell(tool, fixture, out_root, timeout):
    stem = os.path.basename(fixture)
    stem = stem[: -len(".xcresult")] if stem.endswith(".xcresult") else stem
    rel_dir = os.path.join(tool["label"], stem)
    cell_dir = os.path.join(out_root, rel_dir)
    os.makedirs(cell_dir, exist_ok=True)

    started = time.monotonic()
    with tempfile.TemporaryDirectory(prefix="vc-render-") as tmp:
        bundle_copy = os.path.join(tmp, os.path.basename(fixture))
        shutil.copytree(fixture, bundle_copy)
        try:
            proc = subprocess.run(
                invocation(tool["binary"], cell_dir, bundle_copy),
                capture_output=True, text=True, timeout=timeout, check=False,
            )
            exit_code, stdout, stderr = proc.returncode, proc.stdout, proc.stderr
        except subprocess.TimeoutExpired as expired:
            exit_code = -1
            stdout = (expired.stdout or b"").decode("utf-8", "replace") \
                if isinstance(expired.stdout, bytes) else (expired.stdout or "")
            stderr = f"timed out after {timeout}s"
    wall = time.monotonic() - started

    with open(os.path.join(cell_dir, "stdout.txt"), "w", encoding="utf-8") as h:
        h.write(stdout)
    with open(os.path.join(cell_dir, "stderr.txt"), "w", encoding="utf-8") as h:
        h.write(stderr)

    artifacts = {
        "html": os.path.isfile(os.path.join(cell_dir, "index.html")),
        "junit": os.path.isfile(os.path.join(cell_dir, "report.junit")),
        "json": os.path.isfile(os.path.join(cell_dir, "report.json")),
    }
    status = "ok" if exit_code == 0 and artifacts["html"] else "failed"
    return {
        "tool": tool["label"],
        "fixture": stem,
        "status": status,
        "exitCode": exit_code,
        "wallSeconds": round(wall, 2),
        "dir": rel_dir,
        "artifacts": artifacts,
    }


def capture_provenance(fixture, out_root):
    stem = os.path.basename(fixture)
    stem = stem[: -len(".xcresult")] if stem.endswith(".xcresult") else stem
    rel = os.path.join("provenance", f"{stem}.json")
    dest = os.path.join(out_root, rel)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    proc = subprocess.run(
        [sys.executable, CAPTURE_SCHEMA, fixture, "-o", dest],
        capture_output=True, text=True, check=False,
    )
    if proc.returncode != 0:
        print(f"warning: provenance capture failed for {stem}: "
              f"{proc.stderr.strip()}", file=sys.stderr)
        return None
    return rel


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tools", required=True, help="acquire.json")
    parser.add_argument("--fixtures", required=True,
                        help="comma-separated .xcresult paths")
    parser.add_argument("--out", required=True, help="render directory")
    parser.add_argument("--provenance", choices=("auto", "skip"),
                        default="auto")
    parser.add_argument("--timeout", type=int, default=600,
                        help="per-cell seconds")
    args = parser.parse_args(argv)

    with open(args.tools, encoding="utf-8") as handle:
        tools = json.load(handle)["tools"]
    fixtures = [f for f in args.fixtures.split(",") if f]
    for fixture in fixtures:
        if not os.path.isdir(fixture):
            raise SystemExit(f"error: fixture not found: {fixture}")

    os.makedirs(args.out, exist_ok=True)
    cells = []
    for fixture in fixtures:
        for tool in tools:
            cell = render_cell(tool, fixture, args.out, args.timeout)
            marker = "ok" if cell["status"] == "ok" else "FAILED"
            print(f"  [{marker}] {cell['tool']} x {cell['fixture']} "
                  f"({cell['wallSeconds']}s)")
            cells.append(cell)

    provenance = {}
    if args.provenance == "auto":
        for fixture in fixtures:
            rel = capture_provenance(fixture, args.out)
            if rel:
                stem = os.path.basename(fixture)
                stem = stem[: -len(".xcresult")] \
                    if stem.endswith(".xcresult") else stem
                provenance[stem] = rel

    with open(os.path.join(args.out, "cells.json"), "w",
              encoding="utf-8") as handle:
        json.dump({"cells": cells, "provenance": provenance}, handle,
                  indent=2, sort_keys=True)
        handle.write("\n")
    failed = sum(1 for c in cells if c["status"] != "ok")
    print(f"rendered {len(cells)} cell(s), {failed} failed -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
