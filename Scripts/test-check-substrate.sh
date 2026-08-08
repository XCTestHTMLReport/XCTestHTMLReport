#!/bin/bash
# Tests for Scripts/check-substrate.sh.
#
# Fully hermetic: builds a fake repo in a temp dir and runs the guard there.
# Nothing here touches the real CLAUDE.md or docs/learnings/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "ok - $1"; }

# Fake repo mirroring the layout the guard walks.
make_fixture() { # dest
    mkdir -p "$1/Scripts" "$1/docs/learnings"
    cp "$ROOT/Scripts/check-substrate.sh" "$1/Scripts/"
    printf '# rules\n' > "$1/CLAUDE.md"
    printf '# A learning\n' > "$1/docs/learnings/alpha.md"
    printf '# Learnings Index\n\n- [A learning](alpha.md) — hook\n' \
        > "$1/docs/learnings/INDEX.md"
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
make_fixture "$TMP/c"; seq 1 51 > "$TMP/c/CLAUDE.md"
if check "$TMP/c" >"$TMP/out" 2>&1; then fail "passed a 51-line CLAUDE.md"; fi
grep -q "50-line cap" "$TMP/out" || fail "over-cap error does not name the cap"
pass "fails when CLAUDE.md exceeds the 50-line cap"

# 4. Learning file with no index entry -> refuse.
make_fixture "$TMP/d"; printf '# Orphan\n' > "$TMP/d/docs/learnings/orphan.md"
if check "$TMP/d" >"$TMP/out" 2>&1; then fail "passed an unindexed learning"; fi
grep -q "orphan.md has 0 index entries" "$TMP/out" || fail "orphan error unclear"
pass "fails when a learning file is missing from the index"

# 5. Learning file indexed twice -> refuse. A duplicate entry means one of them
#    is stale, and a reader following the wrong one gets the wrong hook.
make_fixture "$TMP/e"
printf -- '- [Again](alpha.md) — dupe\n' >> "$TMP/e/docs/learnings/INDEX.md"
if check "$TMP/e" >"$TMP/out" 2>&1; then fail "passed a doubly-indexed learning"; fi
grep -q "alpha.md has 2 index entries" "$TMP/out" || fail "duplicate error unclear"
pass "fails when a learning file is indexed more than once"

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

# 8. All problems are reported in one run, not just the first. A guard that
#    stops at the first error turns one fix-up into several round trips.
make_fixture "$TMP/h"; rm "$TMP/h/CLAUDE.md"
printf '# Orphan\n' > "$TMP/h/docs/learnings/orphan.md"
if check "$TMP/h" >"$TMP/out" 2>&1; then fail "passed a doubly-broken substrate"; fi
grep -q "CLAUDE.md is missing" "$TMP/out" || fail "did not report the CLAUDE.md problem"
grep -q "orphan.md has 0 index entries" "$TMP/out" || fail "did not report the index problem"
pass "reports every problem in a single run"

echo "All check-substrate tests passed."
