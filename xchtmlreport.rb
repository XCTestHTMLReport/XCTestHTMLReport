class Xchtmlreport < Formula
  desc "XCTestHTMLReport: Xcode-like HTML report for Unit and UI Tests"
  homepage "https://github.com/TitouanVanBelle/XCTestHTMLReport"
  url "https://github.com/TitouanVanBelle/XCTestHTMLReport/archive/2.1.0.tar.gz"
  sha256 "98bc4d97c18b7bfa46ca9fbe72df2351fa96acabe70f14ec5b4f9aeca7bc5b57"
  head "https://github.com/TitouanVanBelle/XCTestHTMLReport.git", :branch => "develop"

  def install
    system "swift build --disable-sandbox -c release"
    bin.install ".build/release/xchtmlreport"
  end
end
