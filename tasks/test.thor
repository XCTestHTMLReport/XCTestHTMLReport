require 'thor'

require_relative './lib/cmd'
require_relative './lib/print'

class Test < Thor
  XCODEBUILD_CMD_BASE = 'xcodebuild test -workspace XCTestHTMLReport.xcworkspace -scheme XCTestHTMLReportSampleApp -verbose'

  desc 'once', 'Runs tests and creates an HTML Report'
  def once
    Print.info 'Running tests once with one HTML Report'

    Print.step "Deleting previous test results"
    Cmd.new('rm -rf TestResultsA').run

    Print.step "Running tests"
    Cmd.new("#{XCODEBUILD_CMD_BASE} -destination 'platform=iOS Simulator,name=iPhone 8,OS=11.4' -resultBundlePath TestResultsA | xcpretty").run

    Print.step "Generating report"
    Cmd.new("xchtmlreport -r TestResultsA -v").run
  end

  desc 'twice', 'Runs tests twice and creates an HTML Report'
  def twice
    Print.info 'Running tests twice with one HTML Report'

    Print.step "Deleting previous test results"
    Cmd.new('rm -rf TestResultsA').run
    Cmd.new('rm -rf TestResultsB').run

    Print.step "Running tests"
    Cmd.new("#{XCODEBUILD_CMD_BASE} -destination 'platform=iOS Simulator,name=iPhone 8,OS=11.4' -resultBundlePath TestResultsA | xcpretty").run
    Cmd.new("#{XCODEBUILD_CMD_BASE} -destination 'platform=iOS Simulator,name=iPhone 8 Plus,OS=11.4' -resultBundlePath TestResultsB | xcpretty").run

    Print.step "Generating report"
    Cmd.new("xchtmlreport -r TestResultsA -r TestResultsB -v").run
  end

  desc 'parallel', 'Runs tests in parallel in multiple devices and creates an HTML Report'
  def parallel
    Print.info 'Running tests in parallel with one HTML Report'

    Print.step "Deleting previous test results"
    Cmd.new('rm -rf TestResultsA').run

    Print.step "Running tests"
    Cmd.new("#{XCODEBUILD_CMD_BASE} -destination 'platform=iOS Simulator,name=iPhone X,OS=11.4' -destination 'platform=iOS Simulator,name=iPhone 7,OS=11.4' -destination 'platform=iOS Simulator,name=iPhone 8,OS=11.4' -resultBundlePath TestResultsA | xcpretty").run

    Print.step "Generating report"
    Cmd.new("xchtmlreport -r TestResultsA -v").run
  end

  desc 'split', 'Runs tests split in multiple devices and creates an HTML Report'
  def split
    Print.info 'Running tests split with one HTML Report'

    Print.step "Deleting previous test results"
    Cmd.new('rm -rf TestResultsA').run
    Cmd.new('rm -rf TestResultsB').run

    Print.step "Running tests"
    Cmd.new("#{XCODEBUILD_CMD_BASE} -destination 'platform=iOS Simulator,name=iPhone 8,OS=11.4' -only-testing:XCTestHTMLReportSampleAppUITests/FirstSuite -resultBundlePath TestResultsA | xcpretty").run
    Cmd.new("#{XCODEBUILD_CMD_BASE} -destination 'platform=iOS Simulator,name=iPhone X,OS=11.4' -only-testing:XCTestHTMLReportSampleAppUITests/SecondSuite -resultBundlePath TestResultsB | xcpretty").run

    Print.step "Generating report"
    Cmd.new("xchtmlreport -r TestResultsA -r TestResultsB -v").run
  end
end
