#!/bin/bash
set -ex

cd XCTestHTMLReportSampleApp

# Pick the newest available iPhone simulator rather than hardcoding a model that
# Apple eventually removes. Falls back to the generic destination if none is found.
DEVICE_NAME=$(xcrun simctl list devices available --json \
    | python3 -c "
import json, sys
devices = json.load(sys.stdin)['devices']
names = [d['name'] for runtime in devices for d in devices[runtime] if d['name'].startswith('iPhone')]
print(sorted(names)[-1] if names else '')
")

if [[ -z "$DEVICE_NAME" ]]; then
    echo "No iPhone simulator available" >&2
    exit 1
fi

echo "Using simulator: $DEVICE_NAME"
SIM_DESTINATION="platform=iOS Simulator,name=${DEVICE_NAME},OS=latest"

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
