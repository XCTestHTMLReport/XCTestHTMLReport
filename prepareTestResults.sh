#!/bin/bash
set -ex

# Simulator selection lives in scripts/select_simulator.py so the CI fixture
# cache key can derive the runtime the exact same way this script does (#436).
# It picks the newest available iOS runtime with an iPhone, then the newest
# iPhone model within it, pinning the destination to the resolved runtime so
# the name and OS always agree. Exits 1 when no iPhone simulator is available.
IFS=$'\t' read -r DEVICE_NAME OS_VERSION UDID RUNTIME_BUILD < <(
    python3 scripts/select_simulator.py
) || true
# `|| true` because `read` returns non-zero on empty input, which under
# `set -e` would kill the script here and leave the guard below unreachable.

if [[ -z "$DEVICE_NAME" ]]; then
    echo "No iPhone simulator available" >&2
    exit 1
fi

echo "Using simulator: $DEVICE_NAME (iOS $OS_VERSION, runtime build $RUNTIME_BUILD) $UDID"

cd XCTestHTMLReportSampleApp
# Pin by UDID rather than name+OS: it is unambiguous when several runtimes
# offer the same device name, and it lets the boot below and the xcodebuild
# invocations target provably the same simulator.
SIM_DESTINATION="id=${UDID}"

# The three fixtures below used to be three `xcodebuild test` invocations, each
# paying a full build and its own simulator boot. On CI that overhead dominated:
# the two single-purpose bundles cost 43-45% of fixture generation while
# producing one test and one retry suite between them (#412). Boot once and
# build once here, then run each fixture with `test-without-building`.
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b

# A stable path rather than a temp dir, so local runs stay incremental.
DERIVED_DATA="${PWD}/.derivedData"

# No `|| true`: the tests below are allowed to fail, but a build failure is a
# real failure and must stop the script. Under the old `xcodebuild test || true`
# a broken sample app surfaced only later, as a confusing `mv` error.
xcodebuild build-for-testing \
    -project SampleApp.xcodeproj \
    -scheme MainScheme \
    -destination "$SIM_DESTINATION" \
    -derivedDataPath "$DERIVED_DATA"

# Create TestResults.xcresult for functional tests
FILENAME='TestResults.xcresult'
rm -rf "$FILENAME"
xcodebuild test-without-building \
    -project SampleApp.xcodeproj \
    -scheme MainScheme \
    -destination "$SIM_DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    -skip-testing:SampleAppUITests/RetryTests \
    -resultBundlePath "$FILENAME" || true

echo "Even if some test failed this is OK."

echo "${FILENAME} should contain succeed, failed and skipped tests for xchtmlreport functional testing"
mkdir -p "../Tests/XCTestHTMLReportTests/Resources/"
rm -rf "../Tests/XCTestHTMLReportTests/Resources/${FILENAME}"
mv "$FILENAME" "../Tests/XCTestHTMLReportTests/Resources/"

SANITY_FILENAME='SanityResults.xcresult'
rm -rf "$SANITY_FILENAME"
xcodebuild test-without-building \
    -project SampleApp.xcodeproj \
    -scheme MainScheme \
    -destination "$SIM_DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    -only-testing:SampleAppUITests/FirstSuite/testOne \
    -resultBundlePath "$SANITY_FILENAME" || true

echo "${SANITY_FILENAME} should contain sample data for sanity tests"
rm -rf "../Tests/XCTestHTMLReportTests/Resources/${SANITY_FILENAME}"
mv "$SANITY_FILENAME" "../Tests/XCTestHTMLReportTests/Resources/"

if [[ $XCODE_VERSION != 12.* && $XCODE_VERSION != 11.* ]]; then
    # "Mixed" test results must be run separately to use -retry-tests-on-failure
    RETRY_FILENAME='RetryResults.xcresult'
    rm -rf "$RETRY_FILENAME"
    xcodebuild test-without-building \
        -project SampleApp.xcodeproj \
        -scheme MainScheme \
        -destination "$SIM_DESTINATION" \
        -derivedDataPath "$DERIVED_DATA" \
        -test-iterations 2 \
        -retry-tests-on-failure \
        -only-testing:SampleAppUITests/RetryTests \
        -resultBundlePath "$RETRY_FILENAME" || true

    echo "${RETRY_FILENAME} will contain mixed test results"
    rm -rf "../Tests/XCTestHTMLReportTests/Resources/${RETRY_FILENAME}"
    mv "$RETRY_FILENAME" "../Tests/XCTestHTMLReportTests/Resources/"
fi

# The one fixture that is deliberately a broken run.
#
# `systemFailure` (#478) keys on a group Apple names `System Failures`, and a
# display name is a handle that can be renamed out from under us — nothing
# structural tells that bucket apart from a user's own suite on either reader.
# So the name is re-measured instead of assumed: SystemFailureCanaryTests reads
# this bundle and asserts both readers still find the bucket in it, which turns
# a rename in some future Xcode into a red suite on the toolchain that
# introduces it rather than a fault that quietly stops firing.
#
# XCHR_TRAP_AT_LAUNCH makes the sample app's AppDelegate trap in
# didFinishLaunchingWithOptions. SampleAppUnitTests is hosted in that app, so
# the whole target dies with it — which is exactly what happened on the Xcode 27
# beta, reproduced rather than simulated. `TEST_RUNNER_` is xcodebuild's own
# channel for reaching the launched process: it strips the prefix and passes the
# rest through, and for a hosted unit test that process is the host app. No
# scheme edit and no second copy of the project to keep in step.
#
# Unit tests only. The UI tests launch the app themselves through
# XCUIApplication, which does not inherit this environment, so including them
# would add a minute of healthy rows the canary does not read.
CRASH_FILENAME='CrashResults.xcresult'
rm -rf "$CRASH_FILENAME"
TEST_RUNNER_XCHR_TRAP_AT_LAUNCH=1 xcodebuild test-without-building \
    -project SampleApp.xcodeproj \
    -scheme MainScheme \
    -destination "$SIM_DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    -only-testing:SampleAppUnitTests \
    -resultBundlePath "$CRASH_FILENAME" || true

# `|| true` above because this invocation is *meant* to fail — but the move is
# not guarded, so a run that wrote no bundle at all still stops the script here
# rather than leaving the canary to fail later with a missing resource.
echo "${CRASH_FILENAME} should contain a host-app launch failure for the System Failures canary"
rm -rf "../Tests/XCTestHTMLReportTests/Resources/${CRASH_FILENAME}"
mv "$CRASH_FILENAME" "../Tests/XCTestHTMLReportTests/Resources/"

echo "$(tput setaf 2)$(basename "$0") successfully finished$(tput sgr 0)"
