require 'thor'

require_relative './lib/cmd'
require_relative './lib/print'

class Test < Thor
  PACKAGE_BUILD = "swift build -c release"
  PACKAGE_PATH = ".build/release/xchtmlreport"
  XCODEBUILD_CMD_BASE = 'xcodebuild test -project XCTestHTMLReportSampleApp/XCTestHTMLReportSampleApp.xcodeproj -scheme XCTestHTMLReportSampleApp -verbose'

  desc 'once', 'Runs tests and creates an HTML Report'
  def once
    Print.info 'Running tests once with one HTML Report'

    Print.step "Deleting previous test results"
    Cmd.new('rm -rf TestResultsA').run

    Print.step "Running tests"
    Cmd.new("#{XCODEBUILD_CMD_BASE} -destination 'platform=iOS Simulator,name=iPhone Xs,OS=12.4' -resultBundlePath TestResultsA | xcpretty").run

    Print.step "Generating report"
    Cmd.new("#{PACKAGE_BUILD}").run
    Cmd.new("#{PACKAGE_PATH} -r TestResultsA -v").run
  end

  desc 'twice', 'Runs tests twice and creates an HTML Report'
  def twice
    Print.info 'Running tests twice with one HTML Report'

    Print.step "Deleting previous test results"
    Cmd.new('rm -rf TestResultsA').run
    Cmd.new('rm -rf TestResultsB').run

    Print.step "Running tests"
    Cmd.new("#{XCODEBUILD_CMD_BASE} -destination 'platform=iOS Simulator,name=iPhone Xs,OS=12.4' -resultBundlePath TestResultsA | xcpretty").run
    Cmd.new("#{XCODEBUILD_CMD_BASE} -destination 'platform=iOS Simulator,name=iPhone Xs Max,OS=12.4' -resultBundlePath TestResultsB | xcpretty").run

    Print.step "Generating report"
    Cmd.new("#{PACKAGE_BUILD}").run
    Cmd.new("#{PACKAGE_PATH} -r TestResultsA -r TestResultsB -v").run
  end

  desc 'parallel', 'Runs tests in parallel in multiple devices and creates an HTML Report'
  def parallel
    Print.info 'Running tests in parallel with one HTML Report'

    Print.step "Deleting previous test results"
    Cmd.new('rm -rf TestResultsA').run

    Print.step "Running tests"
    Cmd.new("#{XCODEBUILD_CMD_BASE} -destination 'platform=iOS Simulator,name=iPhone Xs,OS=12.4' -destination 'platform=iOS Simulator,name=iPhone Xs Max,OS=12.4' -destination 'platform=iOS Simulator,name=iPhone Xr,OS=12.4' -resultBundlePath TestResultsA | xcpretty").run

    Print.step "Generating report"
    Cmd.new("#{PACKAGE_BUILD}").run
    Cmd.new("#{PACKAGE_PATH} -r TestResultsA -v").run
  end

  desc 'split', 'Runs tests split in multiple devices and creates an HTML Report'
  def split
    Print.info 'Running tests split with one HTML Report'

    Print.step "Deleting previous test results"
    Cmd.new('rm -rf TestResultsA').run
    Cmd.new('rm -rf TestResultsB').run

    Print.step "Running tests"
    Cmd.new("#{XCODEBUILD_CMD_BASE} -destination 'platform=iOS Simulator,name=iPhone Xs Max,OS=12.4' -only-testing:XCTestHTMLReportSampleAppUITests/FirstSuite -resultBundlePath TestResultsA | xcpretty").run
    Cmd.new("#{XCODEBUILD_CMD_BASE} -destination 'platform=iOS Simulator,name=iPhone Xs,OS=12.4' -only-testing:XCTestHTMLReportSampleAppUITests/SecondSuite -resultBundlePath TestResultsB | xcpretty").run

    Print.step "Generating report"
    Cmd.new("#{PACKAGE_BUILD}").run
    Cmd.new("#{PACKAGE_PATH} -r TestResultsA -r TestResultsB -v").run
  end

  desc 'same_device', 'Runs UI and Unit tests in the same device'
  def same_device
    Print.info 'Running UI in the same device'

    Print.step "Deleting previous test results"
    Cmd.new('rm -rf TestResultsA').run
    Cmd.new('rm -rf TestResultsB').run

    Print.step "Running tests"
    Cmd.new("#{XCODEBUILD_CMD_BASE} -destination 'platform=iOS Simulator,name=iPhone Xs,OS=12.4' -only-testing:XCTestHTMLReportSampleAppUITests/FirstSuite -resultBundlePath TestResultsA | xcpretty").run
    Cmd.new("#{XCODEBUILD_CMD_BASE} -destination 'platform=iOS Simulator,name=iPhone Xs,OS=12.4' -only-testing:XCTestHTMLReportSampleAppUITests/SecondSuite -resultBundlePath TestResultsB | xcpretty").run

    Print.step "Generating report"
    Cmd.new("#{PACKAGE_BUILD}").run
    Cmd.new("#{PACKAGE_PATH} -r TestResultsA -r TestResultsB -v").run
  end
end
