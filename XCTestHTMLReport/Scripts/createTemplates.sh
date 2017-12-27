#!/bin/bash
echo `pwd`
index=`cat XCTestHTMLReport/HTML/index.html | sed 's,",\\\\",g'`
testSummary=`cat XCTestHTMLReport/HTML/test_summary.html | sed 's,",\\\\",g'`
run=`cat XCTestHTMLReport/HTML/run.html | sed 's,",\\\\",g'`
device=`cat XCTestHTMLReport/HTML/device.html | sed 's,",\\\\",g'`
test=`cat XCTestHTMLReport/HTML/test.html | sed 's,",\\\\",g'`
activity=`cat XCTestHTMLReport/HTML/activity.html | sed 's,",\\\\",g'`
screenshot=`cat XCTestHTMLReport/HTML/screenshot.html | sed 's,",\\\\",g'`
text=`cat XCTestHTMLReport/HTML/text.html | sed 's,",\\\\",g'`

content="
struct HTMLTemplates
{
  static let index = \"\"\"
$index
  \"\"\"

  static let device = \"\"\"
  $device
  \"\"\"

  static let run = \"\"\"
$run
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
echo "$content" > 'XCTestHTMLReport/HTMLTemplates.swift'
