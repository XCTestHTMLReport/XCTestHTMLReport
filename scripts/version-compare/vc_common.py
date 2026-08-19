#!/usr/bin/env python3
"""Shared vocabulary for the version-compare stages.

The join id and the status fold live here because every stage must agree on
them exactly: extract writes them, diff joins on them, the site renders them.
See docs/superpowers/specs/2026-08-18-version-compare-harness-design.md.
"""

import re

# Seconds. Every version reads the same recorded bundle, so a sub-tolerance
# difference is formatting; larger means the versions disagree about WHICH
# duration a test has (e.g. first-run vs last-run on a retry) — worth flagging.
DURATION_TOLERANCE_SECONDS = 0.1

STATUSES = frozenset(
    {"passed", "failed", "skipped", "expectedFailure", "unknown", "mixed"}
)

# "name() (Iteration 1)" — the legacy format's label for a lone repetition.
_LONE_ITERATION = re.compile(r" \(Iteration \d+\)$")


def normalize_join_id(raw):
    """The cross-version identity of a test row."""
    return _LONE_ITERATION.sub("", raw)


def fold_statuses(statuses):
    """One status for a test from its per-iteration statuses."""
    unique = set(statuses)
    if not unique:
        return "unknown"
    if len(unique) == 1:
        return unique.pop()
    return "mixed"


def totals_from_tests(tests):
    totals = {status: 0 for status in sorted(STATUSES)}
    for test in tests:
        totals[test["status"]] = totals.get(test["status"], 0) + 1
    return totals
