#!/bin/bash
# Tests for Scripts/check-substrate.sh.
#
# Fully hermetic: builds a fake repo in a temp dir and runs the guard there.
# Nothing here touches the real CLAUDE.md or docs/learnings/.
#
# Every check in the guard has a case here that makes it fail. A check no test
# can trip is not protection — it is a check that might already be broken.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cases=0
fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { cases=$((cases + 1)); echo "ok - $1"; }

# n lines of filler, each long enough that a handful clear the guard's byte
# floor. Used wherever a case is about line count and must not also trip a
# byte bound.
lines() { # count
    awk -v n="$1" 'BEGIN {
        for (i = 1; i <= n; i++) print "a rule line padded out past the byte floor"
    }'
}

# Fake repo mirroring the layout the guard walks.
make_fixture() { # dest
    mkdir -p "$1/Scripts" "$1/docs/learnings" "$1/.github/workflows"
    cp "$ROOT/Scripts/check-substrate.sh" "$1/Scripts/"
    lines 12 > "$1/CLAUDE.md"
    printf '# A learning\n' > "$1/docs/learnings/alpha.md"
    printf '# Learnings Index\n\n- [A learning](alpha.md) — hook\n' \
        > "$1/docs/learnings/INDEX.md"
    printf 'jobs:\n  substrate:\n    steps:\n    - run: ./Scripts/check-substrate.sh\n' \
        > "$1/.github/workflows/lint.yml"
}
check() { "$1/Scripts/check-substrate.sh"; }

# 1. Well-formed substrate -> pass, silently.
make_fixture "$TMP/a"
check "$TMP/a" >"$TMP/out" 2>&1 || fail "refused a well-formed substrate: $(cat "$TMP/out")"
[ ! -s "$TMP/out" ] || fail "should be silent on success, printed: $(cat "$TMP/out")"
pass "passes a well-formed substrate silently"

# 2. Missing CLAUDE.md -> refuse.
make_fixture "$TMP/b"; rm "$TMP/b/CLAUDE.md"
if check "$TMP/b" >"$TMP/out" 2>&1; then fail "passed with no CLAUDE.md"; fi
grep -q "CLAUDE.md is missing" "$TMP/out" || fail "missing-CLAUDE.md error unclear"
pass "fails when CLAUDE.md is missing"

# 3. CLAUDE.md over the cap -> refuse, and name the cap.
make_fixture "$TMP/c"; lines 51 > "$TMP/c/CLAUDE.md"
if check "$TMP/c" >"$TMP/out" 2>&1; then fail "passed a 51-line CLAUDE.md"; fi
grep -q "50-line cap" "$TMP/out" || fail "over-cap error does not name the cap"
pass "fails when CLAUDE.md exceeds the 50-line cap"

# 3b. 51 lines with no trailing newline -> refuse. `wc -l` counts newlines and
#     reports 50 for this file, so a cap built on it is bypassed by deleting one
#     byte. The guard counts records instead.
make_fixture "$TMP/c2"
lines 51 | awk '{ printf "%s%s", (NR > 1 ? "\n" : ""), $0 }' > "$TMP/c2/CLAUDE.md"
[ "$(wc -l < "$TMP/c2/CLAUDE.md" | tr -d '[:space:]')" -eq 50 ] \
    || fail "fixture is not the no-trailing-newline case wc -l undercounts"
if check "$TMP/c2" >"$TMP/out" 2>&1; then fail "passed 51 lines with no trailing newline"; fi
grep -q "is 51 lines" "$TMP/out" || fail "did not count the trailing partial line"
pass "fails at 51 lines even with no trailing newline"

# 3c. Emptied CLAUDE.md -> refuse. Truncating the rules to nothing satisfies
#     every upper bound; only a floor catches it.
make_fixture "$TMP/c3"; : > "$TMP/c3/CLAUDE.md"
if check "$TMP/c3" >"$TMP/out" 2>&1; then fail "passed a 0-byte CLAUDE.md"; fi
grep -q "byte floor" "$TMP/out" || fail "under-floor error does not name the floor"
pass "fails when CLAUDE.md is emptied"

# 3d. 100 KB on one line -> refuse. Under the line cap and unreadable, which is
#     the failure the line cap exists to prevent.
make_fixture "$TMP/c4"
awk 'BEGIN { s = "x"; while (length(s) < 100000) s = s s; print substr(s, 1, 100000) }' \
    > "$TMP/c4/CLAUDE.md"
[ "$(awk 'END { print NR }' "$TMP/c4/CLAUDE.md")" -le 50 ] \
    || fail "fixture is not the under-the-line-cap case"
if check "$TMP/c4" >"$TMP/out" 2>&1; then fail "passed a 100 KB CLAUDE.md"; fi
grep -q "byte ceiling" "$TMP/out" || fail "over-ceiling error does not name the ceiling"
pass "fails when CLAUDE.md is huge but within the line cap"

# 4. Learning file with no index entry -> refuse.
make_fixture "$TMP/d"; printf '# Orphan\n' > "$TMP/d/docs/learnings/orphan.md"
if check "$TMP/d" >"$TMP/out" 2>&1; then fail "passed an unindexed learning"; fi
grep -q "orphan.md has 0 index entries" "$TMP/out" || fail "orphan error unclear"
pass "fails when a learning file is missing from the index"

# 4b. Learning hidden in a subdirectory -> refuse. A walk bounded to one level
#     never sees this file, so it never requires it to be indexed.
make_fixture "$TMP/d2"
mkdir -p "$TMP/d2/docs/learnings/ci"
printf '# Hidden\n' > "$TMP/d2/docs/learnings/ci/hidden.md"
if check "$TMP/d2" >"$TMP/out" 2>&1; then fail "passed a learning hidden in a subdirectory"; fi
grep -q "ci/hidden.md has 0 index entries" "$TMP/out" || fail "nested-orphan error unclear"
pass "fails when a learning hides in a subdirectory"

# 4c. Nested learning indexed by the path INDEX.md can actually resolve -> pass.
#     The counterpart to 4b: the key is the path relative to docs/learnings/,
#     so `](ci/nested.md)` is what satisfies the bijection, not the basename.
make_fixture "$TMP/d3"
mkdir -p "$TMP/d3/docs/learnings/ci"
printf '# Nested\n' > "$TMP/d3/docs/learnings/ci/nested.md"
printf -- '- [Nested](ci/nested.md) — hook\n' >> "$TMP/d3/docs/learnings/INDEX.md"
check "$TMP/d3" >"$TMP/out" 2>&1 \
    || fail "refused a nested learning indexed by its relative path: $(cat "$TMP/out")"
pass "accepts a nested learning indexed by its relative path"

# 5. Learning file indexed twice -> refuse. A duplicate entry means one of them
#    is stale, and a reader following the wrong one gets the wrong hook.
make_fixture "$TMP/e"
printf -- '- [Again](alpha.md) — dupe\n' >> "$TMP/e/docs/learnings/INDEX.md"
if check "$TMP/e" >"$TMP/out" 2>&1; then fail "passed a doubly-indexed learning"; fi
grep -q "alpha.md has 2 index entries" "$TMP/out" || fail "duplicate error unclear"
pass "fails when a learning file is indexed more than once"

# 5b. Two links to the same file on ONE line -> refuse. This is the case the
#     implementation's `grep -oF | wc -l` exists for: `grep -c` counts matching
#     lines, so it would see one entry here and wrongly pass.
make_fixture "$TMP/e2"
printf -- '- [One](alpha.md) and [Two](alpha.md) on one line\n' \
    >> "$TMP/e2/docs/learnings/INDEX.md"
if check "$TMP/e2" >"$TMP/out" 2>&1; then fail "passed two same-line links to one file"; fi
grep -q "alpha.md has 3 index entries" "$TMP/out" || fail "same-line duplicate error unclear"
pass "fails when one INDEX.md line links the same learning twice"

# 6. Index pointing at a file that does not exist -> refuse.
make_fixture "$TMP/f"
printf -- '- [Ghost](ghost.md) — nothing here\n' >> "$TMP/f/docs/learnings/INDEX.md"
if check "$TMP/f" >"$TMP/out" 2>&1; then fail "passed an index entry with no file"; fi
grep -q "points at missing file: ghost.md" "$TMP/out" || fail "dangling-entry error unclear"
pass "fails when the index points at a missing file"

# 7. Missing INDEX.md -> refuse.
make_fixture "$TMP/g"; rm "$TMP/g/docs/learnings/INDEX.md"
if check "$TMP/g" >"$TMP/out" 2>&1; then fail "passed with no INDEX.md"; fi
grep -q "INDEX.md is missing" "$TMP/out" || fail "missing-index error unclear"
pass "fails when INDEX.md is missing"

# 7b. Every learning deleted, index emptied to match -> refuse. The bijection
#     holds over the empty set, so only a floor on the count catches this.
make_fixture "$TMP/g2"; rm "$TMP/g2/docs/learnings/alpha.md"
printf '# Learnings Index\n' > "$TMP/g2/docs/learnings/INDEX.md"
if check "$TMP/g2" >"$TMP/out" 2>&1; then fail "passed an emptied docs/learnings/"; fi
grep -q "no learning files" "$TMP/out" || fail "empty-learnings error unclear"
pass "fails when every learning has been deleted"

# 8. All problems are reported in one run, not just the first. A guard that
#    stops at the first error turns one fix-up into several round trips.
make_fixture "$TMP/h"; rm "$TMP/h/CLAUDE.md"
printf '# Orphan\n' > "$TMP/h/docs/learnings/orphan.md"
if check "$TMP/h" >"$TMP/out" 2>&1; then fail "passed a doubly-broken substrate"; fi
grep -q "CLAUDE.md is missing" "$TMP/out" || fail "did not report the CLAUDE.md problem"
grep -q "orphan.md has 0 index entries" "$TMP/out" || fail "did not report the index problem"
pass "reports every problem in a single run"

# 9. No workflow invokes the guard -> refuse. Deleting the CI job is a quieter
#    way to disable this script than editing it.
make_fixture "$TMP/i"; rm "$TMP/i/.github/workflows/lint.yml"
if check "$TMP/i" >"$TMP/out" 2>&1; then fail "passed with no workflow invoking the guard"; fi
grep -q "not wired into CI" "$TMP/out" || fail "unwired error unclear"
pass "fails when no workflow invokes the guard"

# 9b. A workflow that runs only the guard's TEST -> refuse. `check-substrate.sh`
#     is a substring of `test-check-substrate.sh`, so a wiring check that
#     matched the bare filename would call this wired.
make_fixture "$TMP/i2"
printf 'jobs:\n  substrate:\n    steps:\n    - run: ./Scripts/test-check-substrate.sh\n' \
    > "$TMP/i2/.github/workflows/lint.yml"
if check "$TMP/i2" >"$TMP/out" 2>&1; then fail "passed a workflow that runs only the guard's test"; fi
grep -q "not wired into CI" "$TMP/out" || fail "test-only wiring error unclear"
pass "fails when a workflow runs only the guard's test"

# 9c. The job moved to a different workflow file -> pass. The check asserts that
#     the guard runs somewhere, not that it runs in a particular file.
make_fixture "$TMP/i3"
rm "$TMP/i3/.github/workflows/lint.yml"
printf 'jobs:\n  substrate:\n    steps:\n    - run: ./Scripts/check-substrate.sh\n' \
    > "$TMP/i3/.github/workflows/substrate.yml"
check "$TMP/i3" >"$TMP/out" 2>&1 \
    || fail "refused a guard wired from another workflow file: $(cat "$TMP/out")"
pass "accepts the guard wired from any workflow file"

echo "All $cases check-substrate tests passed."
