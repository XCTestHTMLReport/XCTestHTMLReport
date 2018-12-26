xchtmlreport:
	xcodebuild clean build CODE_SIGNING_REQUIRED=NO -workspace XCTestHTMLReport.xcworkspace -scheme XCTestHTMLReport -configuration Release
	mv xchtmlreport /usr/local/bin/