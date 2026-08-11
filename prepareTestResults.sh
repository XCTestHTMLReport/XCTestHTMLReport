#!/bin/bash
set -ex

cd XCTestHTMLReportSampleApp

# Pick the newest available iOS runtime, then the newest iPhone model within it.
# Device names cannot be compared as strings: "iPhone 8" sorts above
# "iPhone 17 Pro Max" because '8' > '1', and "iPhone SE" outranks both. Compare
# the numeric model instead, and pin the destination to the resolved runtime so
# the name and OS always agree. Exits 1 when no iPhone simulator is available.
IFS=$'\t' read -r DEVICE_NAME OS_VERSION UDID < <(
    xcrun simctl list devices available --json | python3 -c '
import json, re, sys

devices = json.load(sys.stdin)["devices"]

def runtime_version(identifier):
    match = re.search(r"iOS-([0-9-]+)$", identifier)
    if not match:
        return None
    return tuple(int(part) for part in match.group(1).split("-"))

def model_rank(entry):
    match = re.search(r"iPhone (\d+)", entry["name"])
    # Unnumbered models (iPhone SE, iPhone X) rank below numbered ones.
    return (1, int(match.group(1)), entry["name"]) if match else (0, 0, entry["name"])

best = None
for identifier, entries in devices.items():
    version = runtime_version(identifier)
    if version is None:
        continue
    iphones = [e for e in entries if e["name"].startswith("iPhone")]
    if not iphones:
        continue
    candidate = (version, max(iphones, key=model_rank))
    if best is None or candidate[0] > best[0]:
        best = candidate

if best is not None:
    # Tab-separated: device names contain spaces.
    version, entry = best
    print("\t".join([entry["name"], ".".join(str(part) for part in version), entry["udid"]]))
'
) || true
# `|| true` because `read` returns non-zero on empty input, which under
# `set -e` would kill the script here and leave the guard below unreachable.

if [[ -z "$DEVICE_NAME" ]]; then
    echo "No iPhone simulator available" >&2
    exit 1
fi

echo "Using simulator: $DEVICE_NAME (iOS $OS_VERSION) $UDID"
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

# Create a real macOS run destination fixture. The report used to hardcode
# every destination as iOS, which an iPhone-only fixture suite could not catch.
MACOS_FILENAME='MacOSResults.xcresult'
rm -rf "$MACOS_FILENAME"
SAMPLE_APP_DIR="$PWD"
(
    cd MacOSResultFixture
    xcodebuild test \
        -scheme Fixture \
        -destination 'platform=macOS' \
        -resultBundlePath "$SAMPLE_APP_DIR/$MACOS_FILENAME"
)

echo "${MACOS_FILENAME} should identify the run destination as macOS"
rm -rf "../Tests/XCTestHTMLReportTests/Resources/${MACOS_FILENAME}"
mv "$MACOS_FILENAME" "../Tests/XCTestHTMLReportTests/Resources/"

echo "$(tput setaf 2)$(basename "$0") successfully finished$(tput sgr 0)"
