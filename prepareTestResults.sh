#!/bin/bash
set -ex

cd XCTestHTMLReportSampleApp

# Pick the newest available iOS runtime, then the newest iPhone model within it.
# Device names cannot be compared as strings: "iPhone 8" sorts above
# "iPhone 17 Pro Max" because '8' > '1', and "iPhone SE" outranks both. Compare
# the numeric model instead, and pin the destination to the resolved runtime so
# the name and OS always agree. Exits 1 when no iPhone simulator is available.
IFS=$'\t' read -r DEVICE_NAME OS_VERSION < <(
    xcrun simctl list devices available --json | python3 -c '
import json, re, sys

devices = json.load(sys.stdin)["devices"]

def runtime_version(identifier):
    match = re.search(r"iOS-([0-9-]+)$", identifier)
    if not match:
        return None
    return tuple(int(part) for part in match.group(1).split("-"))

def model_rank(name):
    match = re.search(r"iPhone (\d+)", name)
    # Unnumbered models (iPhone SE, iPhone X) rank below numbered ones.
    return (1, int(match.group(1)), name) if match else (0, 0, name)

best = None
for identifier, entries in devices.items():
    version = runtime_version(identifier)
    if version is None:
        continue
    iphones = [e["name"] for e in entries if e["name"].startswith("iPhone")]
    if not iphones:
        continue
    candidate = (version, max(iphones, key=model_rank))
    if best is None or candidate[0] > best[0]:
        best = candidate

if best is not None:
    # Tab-separated: device names contain spaces.
    print(best[1] + "\t" + ".".join(str(part) for part in best[0]))
'
) || true
# `|| true` because `read` returns non-zero on empty input, which under
# `set -e` would kill the script here and leave the guard below unreachable.

if [[ -z "$DEVICE_NAME" ]]; then
    echo "No iPhone simulator available" >&2
    exit 1
fi

echo "Using simulator: $DEVICE_NAME (iOS $OS_VERSION)"
SIM_DESTINATION="platform=iOS Simulator,name=${DEVICE_NAME},OS=${OS_VERSION}"

# Create TestResults.xcresult for functional tests
FILENAME='TestResults.xcresult'
rm -rf "$FILENAME"
xcodebuild test \
    -project SampleApp.xcodeproj \
    -scheme MainScheme \
    -destination "$SIM_DESTINATION" \
    -skip-testing:SampleAppUITests/RetryTests \
    -resultBundlePath "$FILENAME" || true

echo "Even if some test failed this is OK."

echo "${FILENAME} should contain succeed, failed and skipped tests for xchtmlreport functional testing"
mkdir -p "../Tests/XCTestHTMLReportTests/Resources/"
rm -rf "../Tests/XCTestHTMLReportTests/Resources/${FILENAME}"
mv "$FILENAME" "../Tests/XCTestHTMLReportTests/Resources/"

SANITY_FILENAME='SanityResults.xcresult'
rm -rf "$SANITY_FILENAME"
xcodebuild test \
    -project SampleApp.xcodeproj \
    -scheme MainScheme \
    -destination "$SIM_DESTINATION" \
    -only-testing:SampleAppUITests/FirstSuite/testOne \
    -resultBundlePath "$SANITY_FILENAME" || true

echo "${SANITY_FILENAME} should contain sample data for sanity tests"
rm -rf "../Tests/XCTestHTMLReportTests/Resources/${SANITY_FILENAME}"
mv "$SANITY_FILENAME" "../Tests/XCTestHTMLReportTests/Resources/"

if [[ $XCODE_VERSION != 12.* && $XCODE_VERSION != 11.* ]]; then
    # "Mixed" test results must be run separately to use -retry-tests-on-failure
    RETRY_FILENAME='RetryResults.xcresult'
    rm -rf "$RETRY_FILENAME"
    xcodebuild test \
        -project SampleApp.xcodeproj \
        -scheme MainScheme \
        -destination "$SIM_DESTINATION" \
        -test-iterations 2 \
        -retry-tests-on-failure \
        -only-testing:SampleAppUITests/RetryTests \
        -resultBundlePath "$RETRY_FILENAME" || true

    echo "${RETRY_FILENAME} will contain mixed test results"
    rm -rf "../Tests/XCTestHTMLReportTests/Resources/${RETRY_FILENAME}"
    mv "$RETRY_FILENAME" "../Tests/XCTestHTMLReportTests/Resources/"
fi

echo "$(tput setaf 2)$(basename "$0") successfully finished$(tput sgr 0)"
