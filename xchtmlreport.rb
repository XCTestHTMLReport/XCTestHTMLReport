class Xchtmlreport < Formula
  desc "XCTestHTMLReport: Xcode-like HTML report for Unit and UI Tests"
  homepage "https://github.com/XCTestHTMLReport/XCTestHTMLReport"
  url "https://github.com/XCTestHTMLReport/XCTestHTMLReport/archive/refs/tags/2.2.0.tar.gz"
  sha256 "bdab5934a92df2dfbeea40c3f0fefba816b48cb1c125785e87514ec0a534fada"
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
