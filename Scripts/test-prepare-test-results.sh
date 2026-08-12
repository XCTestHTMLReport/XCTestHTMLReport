#!/bin/bash
# Tests prepareTestResults.sh's simulator-resolution guard.
#
# docs/learnings/read-under-set-e-skips-its-guard.md records that `read` under
# `set -e` returns non-zero on empty input, which used to kill the script at
# the read before its own `[[ -z "$DEVICE_NAME" ]]` guard could print a useful
# error. prepareTestResults.sh now ends that read with `|| true` so the guard
# is reachable. This test pins that: it stubs `xcrun` so the device search
# finds no iPhones, then asserts the script fails with the guard's own
# message, not a bare `read`-failure trace. Remove the `|| true` and this
# assertion fails.
#
# Fully hermetic: stubs `xcrun` on PATH and runs in a temp dir, so it never
# touches the host's real simulators or invokes xcodebuild.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/prepareTestResults.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cases=0
fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { cases=$((cases + 1)); echo "ok - $1"; }

# prepareTestResults.sh does a bare `cd XCTestHTMLReportSampleApp` relative to
# its caller's working directory. The script exits at the simulator-resolution
# guard, long before it needs anything else in that directory, so an empty
# directory is enough.
mkdir -p "$TMP/XCTestHTMLReportSampleApp"

# Stub xcrun: `simctl list devices available --json` with a device list that
# has runtimes but no iPhones, so the script's Python selection finds nothing
# and the `read` gets empty input.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/xcrun" <<'STUB'
#!/bin/bash
cat <<'JSON'
{
  "devices": {
    "com.apple.CoreSimulator.SimRuntime.iOS-17-0": [
      { "name": "iPad Pro (12.9-inch) (6th generation)", "isAvailable": true }
    ]
  }
}
JSON
STUB
chmod +x "$TMP/bin/xcrun"

run_prepare() { (cd "$TMP" && PATH="$TMP/bin:$PATH" "$SCRIPT"); }

# 1. No iPhone simulator available -> exit non-zero with the guard's own
#    message, not a bare `read`-failure trace.
if run_prepare >"$TMP/out" 2>&1; then
    fail "prepareTestResults.sh exited 0 with no iPhone simulator available"
fi
grep -qF "No iPhone simulator available" "$TMP/out" \
    || fail "expected the guard's message, got: $(cat "$TMP/out")"
pass "fails with 'No iPhone simulator available' when no iPhone simulator exists"

echo "All $cases prepare-test-results tests passed."
