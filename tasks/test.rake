namespace :test do

desc "Run the UI Tests"

  desc 'Run the UI Tests and create an HTML Report'
  task :ui  do
    system "rm -rf 'TestResults'"
    system "xcodebuild test -workspace XCUITestHTMLReport.xcworkspace -scheme XCUITestHTMLReportSampleApp -destination 'platform=iOS Simulator,name=iPhone 7,OS=11.0' -verbose -resultBundlePath TestResults | xcpretty"
    system "xchtmlreport -r TestResults -v"
  end

end
