#!/bin/bash
echo `pwd`
index=`cat XCUITestHTMLReport/HTML/index.html | sed 's,",\\\\",g'`
testSummary=`cat XCUITestHTMLReport/HTML/test_summary.html | sed 's,",\\\\",g'`
test=`cat XCUITestHTMLReport/HTML/test.html | sed 's,",\\\\",g'`
activity=`cat XCUITestHTMLReport/HTML/activity.html | sed 's,",\\\\",g'`
screenshot=`cat XCUITestHTMLReport/HTML/screenshot.html | sed 's,",\\\\",g'`
text=`cat XCUITestHTMLReport/HTML/text.html | sed 's,",\\\\",g'`

content="
struct HTMLTemplates
{
  static let index = \"\"\"
$index
  \"\"\"

  static let testSummary = \"\"\"
$testSummary
  \"\"\"

  static let test = \"\"\"
$test
  \"\"\"

  static let activity = \"\"\"
$activity
  \"\"\"

  static let screenshot = \"\"\"
$screenshot
  \"\"\"

  static let text = \"\"\"
$text
  \"\"\"
}
"
echo "$content" > 'XCUITestHTMLReport/HTMLTemplates.swift'
