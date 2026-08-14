#!/bin/bash
# Verifies that the .xcresult fixtures actually contain test data.
#
# Shared by every workflow that generates or restores fixtures — test.yml,
# toolchain-drift.yml, pages.yml and pages-release.yml — so the gates cannot
# drift apart, and runnable locally straight after ./prepareTestResults.sh.
#
# Presence is not evidence. When a CI runner's simulator vanished mid-generation
# ("Unable to find a device matching the provided destination specifier"), the
# `|| true` in prepareTestResults.sh swallowed the failure and xcodebuild still
# left a stub bundle behind: an Info.plist, a Data directory, and no tests. The
# presence-only check this replaces passed that stub, so the test job failed
# downstream with a confusing error instead of failing fast at generation — and
# the stub came one step from being SAVED to the fixture cache under a valid
# key, where it would have poisoned every restore until the key rotated (#454).
#
# `xcresulttool get test-results summary` exits 0 on such a stub and reports
# `"totalTestCount": 0`, so the count is the assertion here, not the exit
# status. That command is the modern surface the report itself already reads
# through (ModernResultReader), so this gate needs no toolchain the tool does
# not already need.
#
# A stub is not the only way generation lies. `totalTestCount > 0` also passed a
# bundle missing 57% of the suite: on the Xcode 27 beta the sample app trapped
# at launch, taking the whole `SampleAppUnitTests` target with it, and this gate
# reported `TestResults.xcresult: 10 tests` and waved 10-of-21 through to
# `swift test` (#478). A global floor cannot catch that — 10 is a perfectly
# healthy count for a bundle whose expected shape is 10. So the floor is
# per bundle, below.
#
# Takes bundle paths as arguments, defaulting to the three CI fixtures. Every
# bundle is checked before exiting, so one run names every offender rather than
# stopping at the first.
set -euo pipefail

# Minimum test rows each known fixture must contain, keyed by bundle file name.
#
# These are floors, not equalities. The counts are fixed by the sample sources
# and by the `-only-testing` / `-skip-testing` filters in prepareTestResults.sh,
# so they only move when someone edits those — at which point this table is
# meant to be edited too, deliberately, in the same commit. A floor rather than
# `-eq` because adding a test to the sample app must not fail the gate on every
# branch until the table catches up; losing one still must.
#
#   TestResults   21 = 9 SampleAppUITests (First/Second/Third, RetryTests
#                      skipped) + 7 SampleAppUnitTests XCTest methods
#                      + 5 SwiftTestingSuite `@Test` functions.
#                      CoreTests.testResultStatusCount asserts the same 21.
#   SanityResults  1 = -only-testing:SampleAppUITests/FirstSuite/testOne
#   RetryResults   4 = -only-testing:SampleAppUITests/RetryTests, whose four
#                      methods merge their repetitions into four rows
#
# A bundle not named here — anything passed as an argument by a human — keeps
# the original `> 0` assertion, since this script cannot know its shape.
expected_minimum() {
    case "$1" in
    TestResults.xcresult) echo 21 ;;
    SanityResults.xcresult) echo 1 ;;
    RetryResults.xcresult) echo 4 ;;
    *) echo 1 ;;
    esac
}

if [ "$#" -gt 0 ]; then
    bundles=("$@")
else
    resources='Tests/XCTestHTMLReportTests/Resources'
    bundles=(
        "${resources}/TestResults.xcresult"
        "${resources}/SanityResults.xcresult"
        "${resources}/RetryResults.xcresult"
    )
fi

# `::error::` so a rejection lands as an annotation on the CI run rather than as
# one line somewhere in a very long log.
fail() {
    echo "::error::$1"
}

status=0
for bundle in "${bundles[@]}"; do
    name="$(basename "$bundle")"

    if [ ! -f "${bundle}/Info.plist" ]; then
        fail "missing or incomplete fixture: ${name}"
        status=1
        continue
    fi

    if ! summary="$(xcrun xcresulttool get test-results summary --path "$bundle" 2>&1)"; then
        fail "unreadable fixture: ${name} — xcresulttool could not summarize it"
        printf '%s\n' "$summary" >&2
        status=1
        continue
    fi

    total="$(printf '%s' "$summary" | python3 -c \
        'import json, sys; print(json.load(sys.stdin).get("totalTestCount", ""))' \
        2>/dev/null || true)"

    case "$total" in
    '' | *[!0-9]*)
        fail "unreadable fixture: ${name} — no usable totalTestCount in the xcresulttool summary"
        printf '%s\n' "$summary" >&2
        status=1
        continue
        ;;
    esac

    minimum="$(expected_minimum "$name")"

    if [ "$total" -eq 0 ]; then
        fail "stub fixture: ${name} contains no tests (totalTestCount=0) — generation did not complete, so this bundle must not be trusted or cached"
        status=1
        continue
    fi

    # Distinct message from the stub case above on purpose: a partial bundle
    # looks healthy from the outside, so the rejection has to say what was
    # expected and what arrived, and name the bundle, or the next reader is left
    # guessing which of the three is short.
    if [ "$total" -lt "$minimum" ]; then
        fail "partial fixture: ${name} contains ${total} tests, expected at least ${minimum} — part of the suite never ran (a host-app launch failure takes its whole target with it), so this bundle must not be trusted or cached"
        status=1
        continue
    fi

    echo "${name}: ${total} tests (expected at least ${minimum})"
done

exit "$status"
