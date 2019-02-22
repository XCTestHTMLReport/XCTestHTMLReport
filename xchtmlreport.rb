class Xchtmlreport < Formula
  desc "XCTestHTMLReport: Xcode-like HTML report for Unit and UI Tests"
  homepage "https://github.com/applidium/XCTestHTMLReport"
  url "https://github.com/applidium/XCTestHTMLReport/archive/1.7.2.tar.gz"
  sha256 "8a879ce4d05df964b311c0a63f639726e20778ad13b82ce4171026bce52da985"
  head "https://github.com/applidium/XCTestHTMLReport.git", :branch => "develop_ad"

  def install
    system "xcodebuild" " clean" " build" " CODE_SIGNING_REQUIRED=NO" " -workspace" " XCTestHTMLReport.xcworkspace" " -scheme XCTestHTMLReport" " -configuration Release"
    bin.install "xchtmlreport"
  end
end
