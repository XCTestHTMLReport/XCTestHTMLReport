class Xchtmlreport < Formula
  desc "XCTestHTMLReport: Xcode-like HTML report for Unit and UI Tests"
  homepage "https://github.com/TitouanVanBelle/XCTestHTMLReport"
  url "https://github.com/TitouanVanBelle/XCTestHTMLReport/archive/2.0.0.tar.gz"
  sha256 "6e0e3c30331bb32bbf38ebd438c1ee3a168432c10ece0f0292c7fdbb72483e0c"
  head "https://github.com/TitouanVanBelle/XCTestHTMLReport.git", :branch => "develop"

  def install
    system "swift build -c release"
    bin.install ".build/release/xchtmlreport"
  end
end
