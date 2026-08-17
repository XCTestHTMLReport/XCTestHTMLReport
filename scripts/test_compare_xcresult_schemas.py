#!/usr/bin/env python3
"""Tests for scripts/compare_xcresult_schemas.py.

The probe's whole question is comparative — "when the schema changes, does the
bundle say so?" — and it is answered by one of a small number of verdicts. Each
is asserted here, because the expensive half of the probe (two macOS runners
booting simulators) is not something to re-run to find out that the cheap half
misreported it.

Run: python3 -m unittest discover -s scripts -p 'test_*.py'
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "compare_xcresult_schemas.py")


def write_capture(directory, name, xcode, version, fingerprint, present=True):
    database = {"present": False}
    if present:
        database = {
            "present": True,
            "tableCount": 40,
            "schemaFingerprint": f"sha256:{fingerprint}",
            "readTablesFingerprint": f"sha256:{fingerprint}",
            "developerTools": [],
            "readTablesMissing": [],
        }
    payload = {
        "toolchain": {"xcode": xcode, "xcodeBuild": "b", "xcresulttool": "t"},
        "bundles": [
            {
                "name": "TestResults.xcresult",
                "infoPlist": {"present": True, "version": version, "storageBackend": "fileBacked2"},
                "database": database,
            }
        ],
    }
    with open(os.path.join(directory, name), "w", encoding="utf-8") as handle:
        json.dump(payload, handle)


def write_disagreeing_capture(directory, name, xcode, version, fingerprints):
    """One toolchain whose own bundles disagree about the schema.

    Distinct from two captures sharing a version: that is a real cross-toolchain
    result. This is a single capture that contradicts itself, which means the
    comparison cannot be trusted at all.
    """
    payload = {
        "toolchain": {"xcode": xcode, "xcodeBuild": "b", "xcresulttool": "t"},
        "bundles": [
            {
                "name": f"Bundle{index}.xcresult",
                "infoPlist": {"present": True, "version": version, "storageBackend": "fileBacked2"},
                "database": {
                    "present": True,
                    "tableCount": 40,
                    "schemaFingerprint": f"sha256:{fingerprint}",
                    "readTablesFingerprint": f"sha256:{fingerprint}",
                    "developerTools": [],
                    "readTablesMissing": [],
                },
            }
            for index, fingerprint in enumerate(fingerprints)
        ],
    }
    with open(os.path.join(directory, name), "w", encoding="utf-8") as handle:
        json.dump(payload, handle)


def compare(directory):
    result = subprocess.run(
        [sys.executable, SCRIPT, directory], capture_output=True, text=True, check=False
    )
    assert result.returncode == 0, f"exit {result.returncode}: {result.stderr}"
    return result.stdout


class CompareTests(unittest.TestCase):
    def test_same_fingerprint_is_inconclusive(self):
        """No schema change happened, so nothing was learned about whether one
        would be detectable. Saying "no drift" here would be read as "safe"."""
        with tempfile.TemporaryDirectory() as root:
            write_capture(root, "a.json", "Xcode 16", "3.50", "aaa")
            write_capture(root, "b.json", "Xcode 26.2", "3.56", "aaa")

            self.assertIn("INCONCLUSIVE", compare(root))

    def test_version_moving_with_the_schema_means_a_gate_is_buildable(self):
        with tempfile.TemporaryDirectory() as root:
            write_capture(root, "a.json", "Xcode 16", "3.50", "aaa")
            write_capture(root, "b.json", "Xcode 26.2", "3.56", "bbb")

            self.assertIn("GATE AVAILABLE", compare(root))

    def test_schema_changing_under_a_fixed_version_means_no_gate(self):
        """The finding the probe exists to catch: the schema moved and nothing
        in the bundle reports it."""
        with tempfile.TemporaryDirectory() as root:
            write_capture(root, "a.json", "Xcode 16", "3.56", "aaa")
            write_capture(root, "b.json", "Xcode 26.2", "3.56", "bbb")

            self.assertIn("NO GATE", compare(root))

    def test_one_version_mapping_to_two_schemas_defeats_the_gate(self):
        """Two toolchains share a version and disagree about the schema, while a
        third has its own version. Comparing only the global sets sees "more
        than one version" and calls the gate available — but the shared version
        has already been shown mapping to two schemas, which is precisely the
        thing that disqualifies it. The wrong answer here is the expensive one:
        it greenlights building a reader on a gate that is known not to hold.
        """
        with tempfile.TemporaryDirectory() as root:
            write_capture(root, "a.json", "Xcode 16", "3.56", "aaa")
            write_capture(root, "b.json", "Xcode 17", "3.56", "bbb")
            write_capture(root, "c.json", "Xcode 26.2", "3.60", "ccc")

            self.assertIn("NO GATE", compare(root))

    def test_a_toolchain_disagreeing_with_itself_is_inconclusive(self):
        """All four fixtures on Xcode 26.2 produce an identical fingerprint, so
        a toolchain whose own bundles disagree means the capture is measuring
        something other than the schema — bundle-specific state, a partial
        generation — and no cross-toolchain conclusion drawn from it is sound.
        Reporting `NO GATE` off that would be a real finding invented from a
        broken measurement.
        """
        with tempfile.TemporaryDirectory() as root:
            write_disagreeing_capture(root, "a.json", "Xcode 26.2", "3.56", ["aaa", "zzz"])
            write_capture(root, "b.json", "Xcode 16", "3.50", "bbb")

            self.assertIn("INCONCLUSIVE", compare(root))

    def test_a_toolchain_without_a_database_is_called_out(self):
        with tempfile.TemporaryDirectory() as root:
            write_capture(root, "a.json", "Xcode 16", "3.50", "aaa", present=False)
            write_capture(root, "b.json", "Xcode 26.2", "3.56", "bbb")

            report = compare(root)

            self.assertIn("no database", report)
            self.assertIn("Xcode 16", report)

    def test_one_capture_cannot_answer_the_question(self):
        with tempfile.TemporaryDirectory() as root:
            write_capture(root, "a.json", "Xcode 26.2", "3.56", "aaa")

            self.assertIn("INCONCLUSIVE", compare(root))

    def test_every_toolchain_appears_in_the_table(self):
        with tempfile.TemporaryDirectory() as root:
            write_capture(root, "a.json", "Xcode 16", "3.50", "aaa")
            write_capture(root, "b.json", "Xcode 26.2", "3.56", "bbb")

            report = compare(root)

            self.assertIn("Xcode 16", report)
            self.assertIn("Xcode 26.2", report)
            self.assertIn("3.50", report)
            self.assertIn("3.56", report)


if __name__ == "__main__":
    unittest.main()
