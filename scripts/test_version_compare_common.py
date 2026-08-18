#!/usr/bin/env python3
"""Tests for scripts/version-compare/vc_common.py.

The join id and the status fold are the two rules every other stage leans on:
a wrong join makes the diff table report phantom added/removed tests, and a
wrong fold mislabels retries. They are pure functions, so unlike the stage
scripts (subprocess-tested), they are imported directly.

Run: python3 -m unittest discover -s scripts -p 'test_*.py'
"""

import importlib.util
import os
import unittest

_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "version-compare", "vc_common.py"
)
_spec = importlib.util.spec_from_file_location("vc_common", _PATH)
vc_common = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(vc_common)


class NormalizeJoinIdTests(unittest.TestCase):
    def test_plain_identifier_passes_through(self):
        self.assertEqual(
            vc_common.normalize_join_id("FirstSuite/testTwo()"),
            "FirstSuite/testTwo()",
        )

    def test_lone_iteration_suffix_is_stripped(self):
        # The legacy format labels a single-run repetition "name (Iteration 1)";
        # 4.0's LegacyResultReader.strippingLoneIterationNumber exists for the
        # same reason. Defensive here: harmless when the suffix never appears.
        self.assertEqual(
            vc_common.normalize_join_id("FirstSuite/testTwo() (Iteration 1)"),
            "FirstSuite/testTwo()",
        )

    def test_iteration_like_text_mid_name_is_kept(self):
        self.assertEqual(
            vc_common.normalize_join_id("S/test (Iteration 1) extra()"),
            "S/test (Iteration 1) extra()",
        )


class FoldStatusesTests(unittest.TestCase):
    def test_empty_is_unknown(self):
        self.assertEqual(vc_common.fold_statuses([]), "unknown")

    def test_uniform_returns_the_value(self):
        self.assertEqual(vc_common.fold_statuses(["passed", "passed"]), "passed")

    def test_disagreement_is_mixed(self):
        self.assertEqual(vc_common.fold_statuses(["failed", "passed"]), "mixed")


class TotalsTests(unittest.TestCase):
    def test_counts_every_vocabulary_key(self):
        totals = vc_common.totals_from_tests(
            [{"status": "passed"}, {"status": "passed"}, {"status": "mixed"}]
        )
        self.assertEqual(totals["passed"], 2)
        self.assertEqual(totals["mixed"], 1)
        self.assertEqual(totals["failed"], 0)
        self.assertIn("expectedFailure", totals)
        self.assertIn("skipped", totals)
        self.assertIn("unknown", totals)


if __name__ == "__main__":
    unittest.main()
