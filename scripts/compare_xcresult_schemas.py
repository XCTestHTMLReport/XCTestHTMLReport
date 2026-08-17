#!/usr/bin/env python3
"""Compare xcresult schema captures from several toolchains and state the
verdict.

Each probe leg can only see its own bundle, but the question is comparative:

    When Apple changes the private `database.sqlite3` schema, does anything in
    the bundle report it?

The only producer-written stamp in a bundle is `Info.plist`'s `version` (3.56 on
Xcode 26.2), and its documented meaning is the *legacy commands* format version
— the surface Apple is removing. So the answer comes from watching the schema
fingerprint and that version across Xcode majors:

    fingerprint same                     -> INCONCLUSIVE (nothing changed, so
                                            nothing was learned)
    fingerprint differs, version differs -> GATE AVAILABLE
    fingerprint differs, version same    -> NO GATE — the schema moved silently

`INCONCLUSIVE` deserves its own word rather than being reported as "no drift":
a run where nothing changed proves nothing about detectability, and calling it
clean would be read as calling it safe.

Always exits 0. The bad answer is a finding to record, not a broken build.

Usage:
    compare_xcresult_schemas.py CAPTURE_DIR
"""

import argparse
import glob
import json
import os
import sys


def load(directory):
    captures = []
    for path in sorted(glob.glob(os.path.join(directory, "*.json"))):
        with open(path, encoding="utf-8") as handle:
            captures.append(json.load(handle))
    return captures


def summarise(capture):
    """Collapse one toolchain's bundles to the values being compared.

    Bundles from one toolchain are expected to agree — they did on Xcode 26.2,
    across all four fixtures — so disagreement is itself reportable rather than
    something to average away.
    """
    bundles = capture.get("bundles") or []
    versions = {b.get("infoPlist", {}).get("version") for b in bundles}
    databases = [b.get("database", {}) for b in bundles]
    present = {bool(d.get("present")) for d in databases}
    fingerprints = {d.get("schemaFingerprint") for d in databases if d.get("present")}
    read_fingerprints = {d.get("readTablesFingerprint") for d in databases if d.get("present")}
    return {
        "xcode": capture.get("toolchain", {}).get("xcode", "unknown"),
        "xcresulttool": capture.get("toolchain", {}).get("xcresulttool", "unknown"),
        "versions": sorted(v for v in versions if v),
        "anyDatabase": any(present),
        "allDatabases": all(present) and bool(present),
        "fingerprints": sorted(f for f in fingerprints if f),
        "readFingerprints": sorted(f for f in read_fingerprints if f),
        "bundleCount": len(bundles),
    }


def one(values):
    """The single shared value, or None when a toolchain disagrees with itself."""
    return values[0] if len(values) == 1 else None


def verdict(summaries):
    usable = [s for s in summaries if s["anyDatabase"]]
    if len(usable) < 2:
        return (
            "INCONCLUSIVE",
            "Fewer than two toolchains produced a database, so there is nothing "
            "to compare. Re-run once both legs succeed.",
        )

    fingerprints = {one(s["fingerprints"]) for s in usable}
    versions = {one(s["versions"]) for s in usable}

    if None in fingerprints or None in versions:
        return (
            "INCONCLUSIVE",
            "A toolchain disagreed with itself across bundles, so the "
            "comparison across toolchains is not meaningful. See the table.",
        )
    if len(fingerprints) == 1:
        return (
            "INCONCLUSIVE",
            "The schema is identical across these toolchains, so no schema "
            "change occurred and nothing was learned about whether one would be "
            "detectable. This is **not** evidence that a gate is safe — try a "
            "wider Xcode spread.",
        )
    if len(versions) > 1:
        return (
            "GATE AVAILABLE",
            "The schema changed and the `Info.plist` version changed with it, "
            "so that stamp is a candidate gate. Confirm it moves on *every* "
            "schema change, not just this one, before relying on it — and note "
            "its documented meaning is still the legacy-commands format "
            "version.",
        )
    return (
        "NO GATE",
        "The schema changed while the `Info.plist` version stayed the same. "
        "Nothing in the bundle reports the change, so a database-backed reader "
        "would have no way to know it is reading an unfamiliar schema. Lead 4 "
        "in docs/reader-performance.md needs a different safety story.",
    )


def render(summaries):
    lines = ["## xcresult schema comparison", ""]
    if not summaries:
        return "\n".join(lines + ["No captures found."])

    lines += [
        "| toolchain | bundles | Info.plist version | schema | read tables | database |",
        "| --- | ---: | --- | --- | --- | --- |",
    ]
    for summary in summaries:
        database = "yes" if summary["allDatabases"] else (
            "partial" if summary["anyDatabase"] else "**no database**"
        )
        lines.append(
            "| {xcode} | {count} | {versions} | {schema} | {read} | {database} |".format(
                xcode=summary["xcode"],
                count=summary["bundleCount"],
                versions=", ".join(summary["versions"]) or "—",
                schema=", ".join(f[7:19] for f in summary["fingerprints"]) or "—",
                read=", ".join(f[7:19] for f in summary["readFingerprints"]) or "—",
                database=database,
            )
        )

    headline, detail = verdict(summaries)
    lines += ["", f"### {headline}", "", detail]

    absent = [s["xcode"] for s in summaries if not s["anyDatabase"]]
    if absent:
        lines += [
            "",
            "Produced **no database** at all: " + ", ".join(absent) + ". A bundle "
            "predating the sqlite backend cannot be read by a database-backed "
            "reader, so that reader would need the `xcresulttool` path as a "
            "fallback rather than a reference.",
        ]
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", help="directory of capture JSON files")
    args = parser.parse_args(argv)

    summaries = [summarise(capture) for capture in load(args.directory)]
    print(render(summaries))
    return 0


if __name__ == "__main__":
    sys.exit(main())
