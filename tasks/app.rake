namespace :app do

  desc 'Runs the Tests and create an HTML Report'
  task :test  do
    puts "Deleting previous test results"
    system "rm -rf 'TestResults'"

    puts "Running tests"
    system "xcodebuild test -workspace XCTestHTMLReport.xcworkspace -scheme XCTestHTMLReportSampleApp -destination 'platform=iOS Simulator,name=iPhone 8,OS=11.2' -verbose -resultBundlePath TestResults | xcpretty"

    puts "Generating report"
    system "./xchtmlreport -r TestResults -v"
  end

  desc 'Runs the Tests in // in multiple devices and create an HTML Report'
  task :test_parallel  do
    puts "Deleting previous test results"
    system "rm -rf 'TestResults'"

    puts "Running tests"
    system "xcodebuild test -workspace XCTestHTMLReport.xcworkspace -scheme XCTestHTMLReportSampleApp -destination 'platform=iOS Simulator,name=iPhone X,OS=11.2' -destination 'platform=iOS Simulator,name=iPhone 7,OS=11.2' -destination 'platform=iOS Simulator,name=iPhone 8,OS=11.2' -verbose -resultBundlePath TestResults | xcpretty"

    puts "Generating report"
    system "./xchtmlreport -r TestResults -v"
  end

end
