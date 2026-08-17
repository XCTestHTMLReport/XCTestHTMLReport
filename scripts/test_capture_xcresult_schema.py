#!/usr/bin/env python3
"""Tests for scripts/capture_xcresult_schema.py.

The capture exists to answer one question across toolchains: when Apple changes
the private `database.sqlite3` schema inside an .xcresult, does anything in the
bundle say so? Reading that database directly is the only lead that removes the
per-test subprocess cost (docs/reader-performance.md), and it is only safe if a
schema change is detectable before it silently produces a wrong report.

So the capture has to be trustworthy in two directions: it must not report a
difference that is only formatting, and it must not miss a difference that is
real. Both are asserted here on synthetic bundles, because the real ones can
only be produced by an Xcode we do not have on this machine.

Driven as a subprocess, like test_assemble_site.py, so the assertions are about
what an operator actually gets: exit status and the JSON on stdout.

Run: python3 -m unittest discover -s scripts -p 'test_*.py'
"""

import json
import os
import plistlib
import sqlite3
import subprocess
import sys
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "capture_xcresult_schema.py")


def make_bundle(root, name, ddl=None, version=(3, 56)):
    """Build a minimal .xcresult-shaped directory. ddl=None omits the database."""
    bundle = os.path.join(root, name)
    os.makedirs(bundle, exist_ok=True)
    with open(os.path.join(bundle, "Info.plist"), "wb") as handle:
        plistlib.dump(
            {
                "version": {"major": version[0], "minor": version[1]},
                "storage": {"backend": "fileBacked2", "compression": "standard"},
            },
            handle,
        )
    if ddl is not None:
        connection = sqlite3.connect(os.path.join(bundle, "database.sqlite3"))
        for statement in ddl:
            connection.execute(statement)
        connection.commit()
        connection.close()
    return bundle


def capture(*bundles):
    result = subprocess.run(
        [sys.executable, SCRIPT, *bundles],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, f"exit {result.returncode}: {result.stderr}"
    return json.loads(result.stdout)


class CaptureTests(unittest.TestCase):
    def test_reports_tables_and_columns(self):
        with tempfile.TemporaryDirectory() as root:
            bundle = make_bundle(
                root,
                "A.xcresult",
                ddl=["CREATE TABLE Activities (title TEXT, startTime REAL)"],
            )
            report = capture(bundle)["bundles"][0]

            self.assertTrue(report["database"]["present"])
            # Sorted, not in DDL order — see the next test for why.
            self.assertEqual(
                report["database"]["tables"]["Activities"], ["startTime", "title"]
            )

    def test_column_order_does_not_change_the_fingerprint(self):
        """Apple emits column order nondeterministically.

        Every bundle produced by Xcode 26.2 — including two from the same run —
        declares the same columns for a table in a different order, which is
        what a Swift dictionary's per-process iteration order does. Fingerprint
        the DDL order and every capture disagrees with every other capture,
        including two from the same toolchain, making the whole probe useless.

        This also constrains any future reader: columns must be addressed by
        name, never by position.
        """
        with tempfile.TemporaryDirectory() as root:
            one = make_bundle(
                root,
                "A.xcresult",
                ddl=["CREATE TABLE Activities (title TEXT, startTime REAL)"],
            )
            other = make_bundle(
                root,
                "B.xcresult",
                ddl=["CREATE TABLE Activities (startTime REAL, title TEXT)"],
            )
            report = capture(one, other)

            self.assertEqual(
                report["bundles"][0]["database"]["schemaFingerprint"],
                report["bundles"][1]["database"]["schemaFingerprint"],
            )

    def test_records_the_bundle_format_version(self):
        with tempfile.TemporaryDirectory() as root:
            bundle = make_bundle(root, "A.xcresult", ddl=[], version=(3, 57))
            report = capture(bundle)["bundles"][0]

            self.assertEqual(report["infoPlist"]["version"], "3.57")
            self.assertEqual(report["infoPlist"]["storageBackend"], "fileBacked2")

    def test_formatting_only_differences_do_not_change_the_fingerprint(self):
        """Whitespace and case in the DDL are noise. A capture that flagged them
        would cry wolf on every Xcode release and train us to ignore it."""
        with tempfile.TemporaryDirectory() as root:
            tidy = make_bundle(
                root, "A.xcresult", ddl=["CREATE TABLE Activities (title TEXT, x REAL)"]
            )
            messy = make_bundle(
                root,
                "B.xcresult",
                ddl=["create   table  Activities\n(title    TEXT,\n  x REAL)"],
            )
            report = capture(tidy, messy)

            self.assertEqual(
                report["bundles"][0]["database"]["schemaFingerprint"],
                report["bundles"][1]["database"]["schemaFingerprint"],
            )

    def test_an_added_column_changes_the_fingerprint(self):
        """The failure this whole capture exists to catch."""
        with tempfile.TemporaryDirectory() as root:
            before = make_bundle(
                root, "A.xcresult", ddl=["CREATE TABLE Activities (title TEXT)"]
            )
            after = make_bundle(
                root,
                "B.xcresult",
                ddl=["CREATE TABLE Activities (title TEXT, newColumn INTEGER)"],
            )
            report = capture(before, after)

            self.assertNotEqual(
                report["bundles"][0]["database"]["schemaFingerprint"],
                report["bundles"][1]["database"]["schemaFingerprint"],
            )

    def test_a_bundle_without_a_database_is_reported_not_fatal(self):
        """Older bundles may predate the sqlite backend entirely. That is a
        finding to record, not a crash — it is one of the answers the probe is
        looking for."""
        with tempfile.TemporaryDirectory() as root:
            bundle = make_bundle(root, "Old.xcresult", ddl=None)
            report = capture(bundle)["bundles"][0]

            self.assertFalse(report["database"]["present"])

    def test_records_whether_the_producing_xcode_is_identified(self):
        """`DeveloperTools` models the producing Xcode but is empty on 26.2. If
        a future Xcode populates it, that is a supported version gate and the
        whole risk calculus changes — so the probe must notice."""
        with tempfile.TemporaryDirectory() as root:
            bundle = make_bundle(
                root,
                "A.xcresult",
                ddl=[
                    "CREATE TABLE DeveloperTools (xcodeBuildVersion TEXT, xcodeVersion TEXT)",
                    "INSERT INTO DeveloperTools VALUES ('17C52', '26.2')",
                ],
            )
            report = capture(bundle)["bundles"][0]

            self.assertEqual(report["database"]["developerTools"], [
                {"xcodeBuildVersion": "17C52", "xcodeVersion": "26.2"}
            ])

    def test_developer_tools_values_survive_a_reversed_column_order(self):
        """Declared order and sorted order disagree here, which is the whole
        point: columns are reported sorted, but `SELECT *` yields values in
        physical order. Zip the two together and the Xcode version is filed
        under the build-version key — a wrong answer to the one question this
        probe exists to ask, and one that column-order nondeterminism
        guarantees will eventually happen on a real bundle."""
        with tempfile.TemporaryDirectory() as root:
            bundle = make_bundle(
                root,
                "A.xcresult",
                ddl=[
                    "CREATE TABLE DeveloperTools (xcodeVersion TEXT, xcodeBuildVersion TEXT)",
                    "INSERT INTO DeveloperTools VALUES ('26.2', '17C52')",
                ],
            )
            report = capture(bundle)["bundles"][0]

            self.assertEqual(report["database"]["developerTools"], [
                {"xcodeBuildVersion": "17C52", "xcodeVersion": "26.2"}
            ])

    def test_records_whether_the_database_was_shipped_with_the_bundle(self):
        """`xcodebuild test` writes only Info.plist and the content-addressed
        `Data/` store; `xcresulttool` builds the database on first read. The two
        facts are different — "Apple ships a database" versus "a read produced
        one" — and conflating them is what made the probe's first run report
        `no database` on both legs and learn nothing."""
        with tempfile.TemporaryDirectory() as root:
            with_db = make_bundle(root, "A.xcresult", ddl=["CREATE TABLE T (x TEXT)"])
            without = make_bundle(root, "B.xcresult", ddl=None)
            report = capture(with_db, without)["bundles"]

            self.assertTrue(report[0]["database"]["shippedWithBundle"])
            self.assertFalse(report[1]["database"]["shippedWithBundle"])

    def test_materialising_an_unreadable_bundle_is_not_fatal(self):
        """`--materialise` shells out to xcresulttool, which cannot read these
        synthetic bundles. That must degrade to "no database" rather than take
        the whole capture down — the same tolerance the toolchain probes have."""
        with tempfile.TemporaryDirectory() as root:
            bundle = make_bundle(root, "A.xcresult", ddl=None)

            result = subprocess.run(
                [sys.executable, SCRIPT, "--materialise", bundle],
                capture_output=True, text=True, check=False,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            database = json.loads(result.stdout)["bundles"][0]["database"]
            self.assertFalse(database["present"])
            self.assertFalse(database["shippedWithBundle"])

    def test_reports_the_toolchain_it_ran_against(self):
        """A fingerprint with no toolchain attached cannot be compared to
        anything."""
        with tempfile.TemporaryDirectory() as root:
            bundle = make_bundle(root, "A.xcresult", ddl=[])
            report = capture(bundle)

            self.assertIn("toolchain", report)
            self.assertIn("xcresulttool", report["toolchain"])


if __name__ == "__main__":
    unittest.main()
