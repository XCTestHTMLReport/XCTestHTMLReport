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
    -resultBundlePath "$FILENAME" \
    -only-testing:SampleAppUITests/FirstSuite \
    -only-testing:SampleAppUITests/SecondSuite \
    -only-testing:SampleAppUITests/ThirdSuite || true
    
RETRY_FILENAME='RetryResults.xcresult'
rm -rf "$RETRY_FILENAME"
xcodebuild test \
    -project SampleApp.xcodeproj \
    -scheme MainScheme \
    -destination 'platform=iOS Simulator,name=iPhone 8,OS=latest' \
    -resultBundlePath "$RETRY_FILENAME" \
    -test-iterations 2 \
    -retry-tests-on-failure \
    -only-testing:SampleAppUITests/RetryTests || true

echo "Even if some test failed this is OK."

echo "${FILENAME} should contain succeed, failed and skipped tests for xchtmlreport functional testing"
rm -rf "../Tests/XCTestHTMLReportTests/${FILENAME}"
mv "$FILENAME" "../Tests/XCTestHTMLReportTests/"

echo "${RETRY_FILENAME} will contain mixed test results"
rm -rf "../Tests/XCTestHTMLReportTests/${RETRY_FILENAME}"
mv "$RETRY_FILENAME" "../Tests/XCTestHTMLReportTests/"

echo "$(tput setaf 2)$(basename "$0") successfully finished$(tput sgr 0)"
