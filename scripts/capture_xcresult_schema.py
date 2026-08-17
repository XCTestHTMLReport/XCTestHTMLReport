#!/usr/bin/env python3
"""Capture the private schema inside .xcresult bundles, for comparison across
Xcode versions.

Reading `database.sqlite3` directly is the only lead that removes the per-test
`xcresulttool` subprocess rather than merely overlapping it — roughly 115 ms per
test case, see docs/reader-performance.md. It is also the only lead that can
fail *silently*: the database is private and undocumented, so a schema change
produces a report that looks fine and is wrong.

Before anything is built on it, one question has to be answered with data rather
than assumption:

    When Apple changes the database schema, does anything in the bundle say so?

The candidates are thin. `PRAGMA user_version` and `application_id` are both 0
on every bundle inspected. The `DeveloperTools` table models the producing Xcode
and is empty. That leaves `Info.plist`'s `version` (3.56 on Xcode 26.2) — the
only producer-written stamp in the bundle — whose documented meaning is the
*legacy commands* format version, and the legacy commands are being removed.

So this captures, per bundle: that version, whether a database exists, and a
fingerprint of the schema. Run it under several Xcode versions and the answer
falls out of diffing the JSON: if the fingerprint moves and the version does
not, there is nothing to gate on and the lead needs a different safety story.

**The database is derived, not shipped.** `xcodebuild test` writes only
`Info.plist` and the content-addressed `Data/` store; `xcresulttool` builds
`database.sqlite3` on its first read of the bundle and leaves it behind. Delete
it and the next query recreates it with an identical schema fingerprint. A
freshly generated bundle therefore has none, which is what the first run of the
probe workflow found on both legs — so `--materialise` reads each bundle once
before inspecting it, and `shippedWithBundle` records whether one was there
beforehand.

The fingerprint is computed from each table's sorted (column, declared type)
pairs, not from the DDL text, so it is insensitive to formatting and to Apple's
nondeterministic column order, while remaining sensitive to anything a reader
could depend on.

Usage:
    capture_xcresult_schema.py BUNDLE [BUNDLE ...] [--materialise] [-o OUT.json]
"""

import argparse
import hashlib
import json
import os
import plistlib
import sqlite3
import subprocess
import sys

# Tables a database-backed reader would have to depend on. Recorded separately
# from the whole-schema fingerprint so a change inside our blast radius is
# distinguishable from a change somewhere we never look.
READ_TABLES = [
    "Activities",
    "Attachments",
    "Devices",
    "ExpectedFailures",
    "RepetitionPolicies",
    "RunDestinations",
    "TestCaseRuns",
    "TestCases",
    "TestIssues",
    "TestSuites",
]


def probe(command):
    """Every line a toolchain probe printed, or [] if it is not available here.

    Tolerant on purpose: this runs on CI images where a given Xcode may be
    absent, and a missing probe is a fact to record rather than a reason to
    lose the whole capture.
    """
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=False)
    except (OSError, ValueError):
        return []
    if result.returncode != 0:
        return []
    return [line.strip() for line in result.stdout.strip().splitlines() if line.strip()]


def first(lines, index=0):
    return lines[index] if len(lines) > index else "unavailable"


def toolchain():
    """`xcodebuild -version` prints the version then the build, on two lines."""
    xcodebuild = probe(["xcodebuild", "-version"])
    return {
        "xcode": first(xcodebuild, 0),
        "xcodeBuild": first(xcodebuild, 1),
        "xcresulttool": first(probe(["xcrun", "xcresulttool", "version"])),
    }


def read_info_plist(bundle):
    path = os.path.join(bundle, "Info.plist")
    if not os.path.exists(path):
        return {"present": False}
    with open(path, "rb") as handle:
        plist = plistlib.load(handle)
    version = plist.get("version") or {}
    storage = plist.get("storage") or {}
    return {
        "present": True,
        "version": f"{version.get('major')}.{version.get('minor')}",
        "storageBackend": storage.get("backend"),
        "compression": storage.get("compression"),
    }


def table_columns(connection, table):
    """(name, declared type) pairs, sorted by name.

    Sorted because Apple's column order is nondeterministic: two bundles from
    the same Xcode — the same test run, even — declare a table's columns in
    different orders, which is what a Swift dictionary's per-process iteration
    order produces. Fingerprinting that order would make every capture differ
    from every other capture and answer nothing.

    It is also a constraint on any reader built on this database: address
    columns by name, never by position.
    """
    rows = connection.execute(f'PRAGMA table_info("{table}")').fetchall()
    return sorted((row[1], row[2]) for row in rows)


def developer_tools(connection, tables):
    """The producing Xcode, if this bundle records it. None means the table is
    absent; [] means it exists and Apple left it empty, which is what every
    bundle inspected on 26.2 does."""
    if "DeveloperTools" not in tables:
        return None
    # Name the columns rather than `SELECT *`: `tables` is sorted by name while
    # `SELECT *` yields physical order, and those disagree — column order is
    # nondeterministic, see table_columns. Zipping the two together files each
    # value under whichever key happens to sort into its position.
    columns = [name for name, _ in tables["DeveloperTools"]]
    projection = ", ".join(f'"{column}"' for column in columns)
    rows = connection.execute(f"SELECT {projection} FROM DeveloperTools").fetchall()
    return [dict(zip(columns, row)) for row in rows]


def fingerprint(schema):
    payload = json.dumps(schema, sort_keys=True, separators=(",", ":"))
    return "sha256:" + hashlib.sha256(payload.encode("utf-8")).hexdigest()


def materialise(bundle):
    """Force the derived database into existence by reading the bundle once.

    `database.sqlite3` is **not** written by `xcodebuild test`. A bundle fresh
    off a test run contains only `Info.plist` and the content-addressed `Data/`
    store; `xcresulttool` builds the database on its first read and leaves it
    behind. Delete it and any query recreates it, with an identical schema.

    So a probe that inspects a freshly generated bundle finds no database and
    learns nothing — which is exactly what the first run of this workflow did
    on both legs. Read once, then inspect.
    """
    try:
        subprocess.run(
            ["xcrun", "xcresulttool", "get", "test-results", "tests",
             "--path", bundle, "--schema-version", "0.1.0"],
            capture_output=True,
            check=False,
        )
    except OSError:
        # No `xcrun` here at all, which is the case on the Linux runner that
        # runs these tests. A missing executable raises rather than returning
        # non-zero, so `check=False` does not cover it. Nothing to materialise
        # is a fact for the capture to record, not a reason to abort it — the
        # same tolerance `probe` has.
        pass


def read_database(bundle, force=False):
    path = os.path.join(bundle, "database.sqlite3")
    # Whether Apple ships it, recorded before anything can create it. Distinct
    # from `present`, which after `--materialise` says only that a read worked.
    shipped = os.path.exists(path)
    if force and not shipped:
        materialise(bundle)
    if not os.path.exists(path):
        return {"present": False, "shippedWithBundle": shipped}

    connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    try:
        names = [
            row[0]
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
            ).fetchall()
            if not row[0].startswith("sqlite_")
        ]
        schema = {name: table_columns(connection, name) for name in names}
        read_schema = {name: schema[name] for name in READ_TABLES if name in schema}
        report = {
            "present": True,
            "shippedWithBundle": shipped,
            "userVersion": connection.execute("PRAGMA user_version").fetchone()[0],
            "applicationId": connection.execute("PRAGMA application_id").fetchone()[0],
            "tableCount": len(names),
            "tables": {name: [column for column, _ in columns] for name, columns in schema.items()},
            "schemaFingerprint": fingerprint(schema),
            "readTablesFingerprint": fingerprint(read_schema),
            "readTablesMissing": [name for name in READ_TABLES if name not in schema],
            "developerTools": developer_tools(connection, schema),
        }
    finally:
        connection.close()
    return report


def capture_bundle(bundle, force=False):
    return {
        "name": os.path.basename(bundle),
        "infoPlist": read_info_plist(bundle),
        "database": read_database(bundle, force=force),
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundles", nargs="+", help=".xcresult bundles to inspect")
    parser.add_argument("-o", "--output", help="write JSON here instead of stdout")
    parser.add_argument(
        "--materialise",
        action="store_true",
        help="read each bundle once first, so the derived database exists "
             "(a freshly generated bundle does not carry one)",
    )
    args = parser.parse_args(argv)

    missing = [bundle for bundle in args.bundles if not os.path.isdir(bundle)]
    if missing:
        parser.error("no such bundle: " + ", ".join(missing))

    report = {
        "toolchain": toolchain(),
        "bundles": [
            capture_bundle(bundle, force=args.materialise) for bundle in args.bundles
        ],
    }
    text = json.dumps(report, indent=2, sort_keys=True)
    if args.output:
        with open(args.output, "w", encoding="utf-8") as handle:
            handle.write(text + "\n")
    else:
        print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
