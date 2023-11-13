#!/bin/bash
set -ex

cd XCTestHTMLReportSampleApp

SIM_DESTINATION="platform=iOS Simulator,name=iPhone 12,OS=latest"

set +e
xcrun simctl list devices --json | grep '"name" : "iPhone 12"' 2> /dev/null
if [[ $? -ne 0 ]]; then
    xcrun simctl create "iPhone 12" "iPhone 12"
fi
set -e

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
