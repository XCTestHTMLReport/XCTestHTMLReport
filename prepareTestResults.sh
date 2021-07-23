#! /bin/bash
set -e
# Create TestResults.xcresult for functional tests
FILENAME='TestResults.xcresult'
cd SampleApp
rm -rf "$FILENAME"
xcodebuild test \
    -project SampleApp.xcodeproj \
    -scheme SampleApp \
    -destination 'platform=iOS Simulator,name=iPhone 8,OS=latest' \
    -resultBundlePath "$FILENAME" || true
echo "Even if some test failed this is OK."
echo "${FILENAME} should contain succeed, failed and skipped tests for xchtmlreport functional testing"
rm -rf "../Tests/XCTestHTMLReportTests/${FILENAME}"
mv "$FILENAME" "../Tests/XCTestHTMLReportTests/"
echo "$(tput setaf 2)$(basename "$0") successfully finished$(tput sgr 0)"