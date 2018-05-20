class Xchtmlreport < Formula
  desc "XCTestHTMLReport: Xcode-like HTML report for Unit and UI Tests"
  homepage "https://github.com/TitouanVanBelle/XCTestHTMLReport"
  url "https://github.com/TitouanVanBelle/XCTestHTMLReport/archive/1.6.0.tar.gz"
  sha256 "2517d3a65407433f78b4a712eb6f0804475e0e9a3a0abc49a277ef6fa1442658"
  head "https://github.com/TitouanVanBelle/XCTestHTMLReport.git"

  def install
    system "xcodebuild clean build CODE_SIGN_IDENTITY=\"\" CODE_SIGNING_REQUIRED=NO -workspace XCTestHTMLReport.xcworkspace -scheme XCTestHTMLReport -configuration Release"
    bin.install "xchtmlreport"
  end
end
