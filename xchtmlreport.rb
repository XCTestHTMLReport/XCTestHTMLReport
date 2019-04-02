class Xchtmlreport < Formula
  desc "XCTestHTMLReport: Xcode-like HTML report for Unit and UI Tests"
  homepage "https://github.com/TitouanVanBelle/XCTestHTMLReport"
  url "https://github.com/TitouanVanBelle/XCTestHTMLReport/archive/1.6.1.tar.gz"
  sha256 "6e0e3c30331bb32bbf38ebd438c1ee3a168432c10ece0f0292c7fdbb72483e0c"
  head "https://github.com/TitouanVanBelle/XCTestHTMLReport.git", :branch => "develop"

  def install
    system "xcodebuild clean build CODE_SIGN_IDENTITY=\"\" CODE_SIGNING_REQUIRED=NO -workspace XCTestHTMLReport.xcworkspace -scheme XCTestHTMLReport -configuration Release"
    bin.install "xchtmlreport"
  end
end
