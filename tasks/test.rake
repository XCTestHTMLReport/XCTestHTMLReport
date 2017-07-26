namespace :test do

desc "Run the UI Tests"
task :ui  do
  `rm -rf 'TestResults'`
  `xcodebuild test -workspace XCUITestHTMLReport.xcworkspace -scheme XCUITestHTMLReportSampleApp -destination 'platform=iOS Simulator,name=iPhone 7,OS=11.0' -resultBundlePath TestResults`
  `./xchtmlreport -r TestResults`
end

end
