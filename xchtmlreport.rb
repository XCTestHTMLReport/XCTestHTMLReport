class Xchtmlreport < Formula
  desc "XCTestHTMLReport: Xcode-like HTML report for Unit and UI Tests"
  homepage "https://github.com/TitouanVanBelle/XCTestHTMLReport"
  url "https://github.com/TitouanVanBelle/XCTestHTMLReport/archive/2.0.0.tar.gz"
  sha256 "4424d673d578e84e67fd96afa53a5bd3e80ec7acade65365a123af358c77b47e"
  head "https://github.com/TitouanVanBelle/XCTestHTMLReport.git", :branch => "develop"

  def install
    system "swift build --disable-sandbox -c release"
    bin.install ".build/release/xchtmlreport"
  end
end
