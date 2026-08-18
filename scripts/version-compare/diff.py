#!/usr/bin/env python3
"""Joins the canonical cell summaries into per-fixture diff rows.

Diffs are precomputed against EVERY tool as baseline so the site's baseline
switcher is a lookup, not a re-implementation of these rules in JS — the
rules exist exactly once, here. Rows matching expected-divergences.json are
marked expected: the muted rendering that keeps highlights meaningful.
"""

import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vc_common import DURATION_TOLERANCE_SECONDS

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_EXPECTED = os.path.join(HERE, "expected-divergences.json")


def compare(base, other):
    """How `other` disagrees with `base` on one row. Both may be None."""
    flags = []
    if base is not None and other is None:
        return ["missing"]
    if base is None and other is not None:
        return ["extra"]
    if base is None and other is None:
        return []
    if base["status"] != other["status"]:
        flags.append("status")
    if abs(base["duration"] - other["duration"]) > DURATION_TOLERANCE_SECONDS:
        flags.append("duration")
    if (base["attachmentCount"] is not None
            and other["attachmentCount"] is not None
            and base["attachmentCount"] != other["attachmentCount"]):
        flags.append("attachments")
    return flags


def diff_fixture(fixture, docs, no_data, expectations):
    tools = sorted(docs)
    ids = sorted({t["id"] for doc in docs.values() for t in doc["tests"]})
    by_tool = {tool: {t["id"]: t for t in doc["tests"]}
               for tool, doc in docs.items()}

    rows = []
    for id_ in ids:
        cells = {}
        for tool in tools:
            test = by_tool[tool].get(id_)
            cells[tool] = None if test is None else {
                "status": test["status"], "duration": test["duration"],
                "attachmentCount": test["attachmentCount"],
                "rawNames": test["rawNames"],
                "failureMessages": test["failureMessages"],
            }
        flags = {}
        for baseline in tools:
            per_tool = {}
            for tool in tools:
                if tool == baseline:
                    continue
                disagreement = compare(cells[baseline], cells[tool])
                if disagreement:
                    per_tool[tool] = disagreement
            if per_tool:
                flags[baseline] = per_tool
        expected_reason = None
        target = f"{fixture}/{id_}"
        for expectation in expectations:
            if re.search(expectation["pattern"], target):
                expected_reason = expectation["reason"]
                break
        rows.append({
            "id": id_, "cells": cells, "flags": flags,
            "expected": expected_reason is not None,
            "reason": expected_reason,
        })
    return {"fixture": fixture, "tools": tools,
            "noData": sorted(no_data), "rows": rows}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--extract", required=True, help="extract directory")
    parser.add_argument("--out", required=True, help="diff directory")
    parser.add_argument("--expected", default=DEFAULT_EXPECTED)
    parser.add_argument("--default-baseline", default="3.0.0")
    args = parser.parse_args(argv)

    with open(os.path.join(args.extract, "index.json"),
              encoding="utf-8") as handle:
        index = json.load(handle)["cells"]
    with open(args.expected, encoding="utf-8") as handle:
        expectations = json.load(handle)

    fixtures = sorted({entry["fixture"] for entry in index})
    all_tools = sorted({entry["tool"] for entry in index})
    extracted_tools = sorted(
        {entry["tool"] for entry in index if entry["extracted"]})
    default_baseline = (args.default_baseline
                        if args.default_baseline in extracted_tools
                        else (extracted_tools[0] if extracted_tools else None))

    os.makedirs(args.out, exist_ok=True)
    unexplained = expected_only = 0
    for fixture in fixtures:
        docs, no_data = {}, []
        for entry in index:
            if entry["fixture"] != fixture:
                continue
            if not entry["extracted"]:
                no_data.append(entry["tool"])
                continue
            # Graceful degradation: missing or unreadable files become no-data.
            try:
                with open(os.path.join(args.extract, entry["file"]),
                          encoding="utf-8") as handle:
                    docs[entry["tool"]] = json.load(handle)
            except (FileNotFoundError, IOError, json.JSONDecodeError) as e:
                print(f"Warning: {entry['tool']}/{fixture} unreadable: {e}",
                      file=sys.stderr)
                no_data.append(entry["tool"])
        doc = diff_fixture(fixture, docs, no_data, expectations)
        for row in doc["rows"]:
            has_flag = bool(row["flags"].get(default_baseline))
            if has_flag and row["expected"]:
                expected_only += 1
            elif has_flag:
                unexplained += 1
        with open(os.path.join(args.out, f"{fixture}.json"), "w",
                  encoding="utf-8") as handle:
            json.dump(doc, handle, indent=2, sort_keys=True)
            handle.write("\n")

    summary = {
        "defaultBaseline": default_baseline,
        "tools": all_tools,
        "fixtures": fixtures,
        "unexplained": unexplained,
        "expectedOnly": expected_only,
        "cellsFailed": sum(1 for e in index
                           if e["reason"] == "render failed"),
        "cellsNoData": sum(1 for e in index if not e["extracted"]),
    }
    with open(os.path.join(args.out, "summary.json"), "w",
              encoding="utf-8") as handle:
        json.dump(summary, handle, indent=2, sort_keys=True)
        handle.write("\n")
    print(f"diffed {len(fixtures)} fixture(s): {unexplained} unexplained, "
          f"{expected_only} expected -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
