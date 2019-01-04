class Xchtmlreport < Formula
  desc "XCTestHTMLReport: Xcode-like HTML report for Unit and UI Tests"
  homepage "https://github.com/applidium/XCTestHTMLReport"
  url "https://github.com/applidium/XCTestHTMLReport/archive/1.7.0.tar.gz"
  sha256 "004678a99d081b343326c4b2ceef7e23eb0670c262413c849bbe7508f87b28c8"
  head "https://github.com/applidium/XCTestHTMLReport.git", :branch => "develop_ad"

  def install
    system "xcodebuild" " clean" " build" " CODE_SIGNING_REQUIRED=NO" " -workspace" " XCTestHTMLReport.xcworkspace" " -scheme XCTestHTMLReport" " -configuration Release"
    bin.install "xchtmlreport"
  end
end
