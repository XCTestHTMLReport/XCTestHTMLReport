#!/usr/bin/env python3
"""Normalizes every rendered cell into one canonical per-test summary.

4.0/HEAD cells are read from their own --json (the documented wire contract,
recognized by its top-level schemaVersion key). Old-lineage cells are read
from the JUnit XML their -j flag wrote — deliberately NOT their report.json,
which is the raw legacy xcresulttool graph. A cell that offers neither
degrades to "no data"; extraction can never block the site.
"""

import argparse
import json
import os
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vc_common import fold_statuses, normalize_join_id, totals_from_tests


def read_junit(path):
    """Rows from a report.junit, one dict per <testcase>."""
    rows = []
    root = ET.parse(path).getroot()
    for suite in root.iter("testsuite"):
        for case in suite.iter("testcase"):
            raw = f"{case.get('classname')}/{case.get('name')}"
            failures = [f.get("message", "") for f in case.findall("failure")]
            if case.find("skipped") is not None:
                status = "skipped"
            elif failures:
                status = "failed"
            else:
                status = "passed"
            rows.append({
                "raw": raw,
                "statuses": [status],
                "duration": float(case.get("time", "0")),
                "attachmentCount": None,
                "failureMessages": failures,
            })
    return rows


def _walk_nodes(node):
    if node["kind"] == "testCase":
        yield node
    else:
        for child in node["children"]:
            yield from _walk_nodes(child)


def _count_attachments(activities):
    count = 0
    for activity in activities:
        count += len(activity["attachments"])
        count += _count_attachments(activity["subActivities"])
    return count


def _failure_titles(activities):
    titles = []
    for activity in activities:
        if activity["isFailure"]:
            titles.append(activity["title"])
        titles.extend(_failure_titles(activity["subActivities"]))
    return titles


def read_schema_json(path):
    """Rows from a 4.0-schema report.json; None if it is not that schema."""
    with open(path, encoding="utf-8") as handle:
        try:
            doc = json.load(handle)
        except ValueError:
            return None
    if not isinstance(doc, dict) or "schemaVersion" not in doc:
        return None  # the old lineage's raw legacy graph, or junk
    rows = []
    for run in doc["runs"]:
        for testable in run["testables"]:
            for group in testable["groups"]:
                for case in _walk_nodes(group):
                    statuses, duration, attachments, failures = [], 0.0, 0, []
                    for iteration in case["iterations"]:
                        statuses.append(iteration["status"])
                        duration += iteration["duration"]
                        attachments += _count_attachments(
                            iteration["activities"])
                        failures.extend(
                            _failure_titles(iteration["activities"]))
                    rows.append({
                        "raw": case["identifier"],
                        "statuses": statuses,
                        "duration": duration,
                        "attachmentCount": attachments,
                        "failureMessages": failures,
                    })
    return rows


def aggregate(rows):
    """Rows sharing a normalized id merge into one canonical test."""
    merged = {}
    for row in rows:
        key = normalize_join_id(row["raw"])
        slot = merged.setdefault(key, {
            "id": key, "rawNames": set(), "statuses": [],
            "duration": 0.0, "attachmentCount": None, "failureMessages": [],
        })
        slot["rawNames"].add(row["raw"])
        slot["statuses"].extend(row["statuses"])
        slot["duration"] += row["duration"]
        if row["attachmentCount"] is not None:
            slot["attachmentCount"] = \
                (slot["attachmentCount"] or 0) + row["attachmentCount"]
        slot["failureMessages"].extend(row["failureMessages"])
    tests = []
    for slot in merged.values():
        tests.append({
            "id": slot["id"],
            "rawNames": sorted(slot["rawNames"]),
            "status": fold_statuses(slot["statuses"]),
            "duration": round(slot["duration"], 3),
            "attachmentCount": slot["attachmentCount"],
            "failureMessages": slot["failureMessages"],
        })
    return sorted(tests, key=lambda t: t["id"])


def extract_cell(cell, render_root):
    """Returns (index_entry, canonical_doc_or_None)."""
    entry = {"tool": cell["tool"], "fixture": cell["fixture"],
             "extracted": False, "source": None, "file": None, "reason": None}
    if cell["status"] != "ok":
        entry["reason"] = "render failed"
        return entry, None

    cell_dir = os.path.join(render_root, cell["dir"])
    rows, source = None, None
    json_path = os.path.join(cell_dir, "report.json")
    if os.path.isfile(json_path):
        try:
            rows = read_schema_json(json_path)
            source = "json" if rows is not None else None
        except Exception as error:
            entry["reason"] = f"json unparseable: {error.__class__.__name__}: {error}"
            return entry, None
    if rows is None:
        junit_path = os.path.join(cell_dir, "report.junit")
        if os.path.isfile(junit_path):
            try:
                rows, source = read_junit(junit_path), "junit"
            except Exception as error:
                entry["reason"] = f"junit unparseable: {error}"
                return entry, None
    if rows is None:
        entry["reason"] = "no machine-readable artifact"
        return entry, None

    tests = aggregate(rows)
    doc = {"tool": cell["tool"], "fixture": cell["fixture"],
           "totals": totals_from_tests(tests), "tests": tests}
    entry.update(extracted=True, source=source,
                 file=os.path.join(cell["tool"], f"{cell['fixture']}.json"))
    return entry, doc


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--render", required=True, help="render directory")
    parser.add_argument("--out", required=True, help="extract directory")
    args = parser.parse_args(argv)

    with open(os.path.join(args.render, "cells.json"),
              encoding="utf-8") as handle:
        cells = json.load(handle)["cells"]

    index = []
    for cell in cells:
        entry, doc = extract_cell(cell, args.render)
        index.append(entry)
        if doc is not None:
            dest = os.path.join(args.out, entry["file"])
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            with open(dest, "w", encoding="utf-8") as handle:
                json.dump(doc, handle, indent=2, sort_keys=True)
                handle.write("\n")

    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, "index.json"), "w",
              encoding="utf-8") as handle:
        json.dump({"cells": index}, handle, indent=2, sort_keys=True)
        handle.write("\n")
    extracted = sum(1 for e in index if e["extracted"])
    print(f"extracted {extracted}/{len(index)} cell(s) -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
