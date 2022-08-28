#!/bin/bash
set -ex

cd XCTestHTMLReportSampleApp

# Create TestResults.xcresult for functional tests
FILENAME='TestResults.xcresult'
rm -rf "$FILENAME"
xcodebuild test \
    -project SampleApp.xcodeproj \
    -scheme MainScheme \
    -destination 'platform=iOS Simulator,name=iPhone 8,OS=latest' \
    -skip-testing:SampleAppUITests/RetryTests \
    -resultBundlePath "$FILENAME" || true

echo "Even if some test failed this is OK."

echo "${FILENAME} should contain succeed, failed and skipped tests for xchtmlreport functional testing"
rm -rf "../Tests/XCTestHTMLReportTests/${FILENAME}"
mv "$FILENAME" "../Tests/XCTestHTMLReportTests/Resources"

FILENAME='SanityResults.xcresult'
rm -rf "$FILENAME"
xcodebuild test \
    -project SampleApp.xcodeproj \
    -scheme MainScheme \
    -destination 'platform=iOS Simulator,name=iPhone 8,OS=latest' \
    -only-testing:SampleAppUITests/FirstSuite/testOne \
    -resultBundlePath "$FILENAME" || true

echo "${FILENAME} shoudl contain sample data for sanity tests"
rm -rf "../Tests/XCTestHTMLReportTests/${FILENAME}"
mv "$FILENAME" "../Tests/XCTestHTMLReportTests/Resources"

if [[ $XCODE_VERSION != 12.* && $XCODE_VERSION != 11.* ]]; then
    # "Mixed" test results must be run separately to use -retry-tests-on-failure
    RETRY_FILENAME='RetryResults.xcresult'
    rm -rf "$RETRY_FILENAME"
    xcodebuild test \
        -project SampleApp.xcodeproj \
        -scheme MainScheme \
        -destination 'platform=iOS Simulator,name=iPhone 8,OS=latest' \
        -test-iterations 2 \
        -retry-tests-on-failure \
        -only-testing:SampleAppUITests/RetryTests \
        -resultBundlePath "$RETRY_FILENAME" || true

    echo "${RETRY_FILENAME} will contain mixed test results"
    rm -rf "../Tests/XCTestHTMLReportTests/${RETRY_FILENAME}"
    mv "$RETRY_FILENAME" "../Tests/XCTestHTMLReportTests/Resources"
fi

echo "$(tput setaf 2)$(basename "$0") successfully finished$(tput sgr 0)"
