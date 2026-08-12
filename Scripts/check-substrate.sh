#!/bin/bash
# Structural checks for the agent substrate's tracked files: CLAUDE.md and
# docs/learnings/.
#
# These two artifacts are conventions, and conventions decay silently. An
# unindexed learning is invisible to anyone who reads only the index; a
# CLAUDE.md that grows without bound stops being read at all. Each failure is
# quiet and each is cheap to catch mechanically, so it is caught mechanically.
#
# Every check has both an upper and a lower bound where one is meaningful. A
# guard that only refuses too much lets the substrate be emptied instead, which
# is the same loss arrived at from the other direction.
#
# Reports EVERY problem in one run rather than stopping at the first, so a
# fix-up is one round trip.
#
# Deliberately offline: checks only what is in the diff under review, and needs
# no network, no token, and no `gh`. A guard that depends on repo-wide mutable
# state can turn unrelated pull requests red for something their author cannot
# fix.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_MD="$ROOT/CLAUDE.md"
LEARNINGS="$ROOT/docs/learnings"
INDEX="$LEARNINGS/INDEX.md"
WORKFLOWS="$ROOT/.github/workflows"
LINE_CAP=50
MIN_BYTES=500
MAX_BYTES=20000

status=0
err() { echo "error: $*" >&2; status=1; }

# 1. CLAUDE.md exists and stays inside all three bounds.
#
# The line cap alone does not bound the file. A 100 KB file on 50 very long
# lines is under the cap and unreadable; a 0-byte file is under the cap and
# says nothing. Bytes bound both ends, lines keep the shape scannable.
#
# Lines are counted with awk, not `wc -l`: `wc -l` counts newline characters,
# so a 51-line file whose last line has no trailing newline reports 50 and
# slips under the cap. awk's NR counts that trailing partial line.
if [ ! -f "$CLAUDE_MD" ]; then
    err "CLAUDE.md is missing — the always-on rules file is required substrate."
else
    lines="$(awk 'END { print NR }' "$CLAUDE_MD")"
    bytes="$(wc -c < "$CLAUDE_MD" | tr -d '[:space:]')"
    if [ "$lines" -gt "$LINE_CAP" ]; then
        err "CLAUDE.md is $lines lines, over the ${LINE_CAP}-line cap — move detail into docs/learnings/."
    fi
    if [ "$bytes" -lt "$MIN_BYTES" ]; then
        err "CLAUDE.md is $bytes bytes, under the ${MIN_BYTES}-byte floor — an emptied rules file must not pass as a small one."
    fi
    if [ "$bytes" -gt "$MAX_BYTES" ]; then
        err "CLAUDE.md is $bytes bytes, over the ${MAX_BYTES}-byte ceiling — the line cap does not bound line length; move detail into docs/learnings/."
    fi
fi

# 2. INDEX.md and the learning files are in exact bijection.
if [ ! -f "$INDEX" ]; then
    err "$INDEX is missing."
else
    learnings=0
    while IFS= read -r f; do
        if [ "$f" = "$INDEX" ]; then continue; fi
        learnings=$((learnings + 1))
        # The key is the path relative to docs/learnings/, not the basename.
        # INDEX.md links resolve relative to INDEX.md's own directory, so a
        # learning at ci/hidden.md is only reachable as `](ci/hidden.md)`;
        # matching on the basename would accept `](hidden.md)`, a link that
        # renders as a dead end, and would be ambiguous the moment two
        # subdirectories hold the same filename.
        rel="${f#"$LEARNINGS/"}"
        # -c counts matching *lines*, so two links to the same file on one
        # INDEX.md line would count as one entry and pass; -o plus a line
        # count counts each match, however many share a line.
        n="$(grep -oF "]($rel)" "$INDEX" | wc -l | tr -d '[:space:]' || true)"
        if [ "$n" -ne 1 ]; then
            err "docs/learnings/$rel has $n index entries in INDEX.md, expected exactly 1."
        fi
        # The walk recurses on purpose. Bounded to one level, a learning filed
        # in a subdirectory is never seen, so it is never required to be
        # indexed — the quietest way to add an invisible file. INDEX.md itself
        # is skipped by exact path, not by name, so that a nested INDEX.md does
        # not become the same hiding place.
    done < <(find "$LEARNINGS" -type f -name '*.md' | sort)

    # A bijection over the empty set holds, so the pair of loops above passes a
    # docs/learnings/ with every learning deleted. Require at least one.
    if [ "$learnings" -eq 0 ]; then
        err "docs/learnings/ contains no learning files — the directory is required substrate, not an empty convention."
    fi

    while IFS= read -r target; do
        [ -f "$LEARNINGS/$target" ] \
            || err "INDEX.md points at missing file: $target"
    done < <(grep -oE '\]\([^)]+\.md\)' "$INDEX" | sed -E 's/^\]\(//; s/\)$//' | sort -u)
fi

# 3. The guard is still wired into CI.
#
# A check nobody invokes is indistinguishable from a check that always passes,
# and deleting the job that runs it is a quieter way to disable this script
# than editing it. So the script asserts its own wiring.
#
# Offline, like the rest: it greps the workflow files, which are in the diff
# under review, rather than asking GitHub what ran. It does not care which
# workflow invokes the guard, so moving the job between files is fine.
#
# The pattern is the path and not the bare filename because a bare
# `check-substrate.sh` also matches `test-check-substrate.sh` — a workflow that
# ran only the guard's test, and never the guard, would otherwise look wired.
if [ ! -d "$WORKFLOWS" ]; then
    err ".github/workflows/ is missing — nothing can be invoking Scripts/check-substrate.sh."
elif ! grep -rqF 'Scripts/check-substrate.sh' "$WORKFLOWS"; then
    err "no file under .github/workflows/ invokes Scripts/check-substrate.sh — the guard is not wired into CI."
fi

exit "$status"
