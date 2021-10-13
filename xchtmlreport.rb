class Xchtmlreport < Formula
  desc "XCTestHTMLReport: Xcode-like HTML report for Unit and UI Tests"
  homepage "https://github.com/XCTestHTMLReport/XCTestHTMLReport"
  url "https://github.com/XCTestHTMLReport/XCTestHTMLReport/releases/download/2.2.0/xchtmlreport-2.2.0.zip"
  sha256 "eb9dc25cd49ff0f44bc28799cd567151df473d3d074bfb7b141111a451f08e36"
  license "MIT"
  head "https://github.com/XCTestHTMLReport/XCTestHTMLReport.git", :branch => "main"

  def install
    system "swift build --disable-sandbox -c release"
    bin.install ".build/release/xchtmlreport"
  end

  test do
    system "./prepareTestResults.sh"
    system "swift test -v"
  end
end
