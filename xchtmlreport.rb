class Xchtmlreport < Formula
  desc "XCTestHTMLReport: Xcode-like HTML report for Unit and UI Tests"
  homepage "https://github.com/applidium/XCTestHTMLReport"
  url "https://github.com/applidium/XCTestHTMLReport/archive/1.7.2.tar.gz"
  sha256 "3d0fc23087dcf958bb242b41a5054d12f12bed6eba56fdf1e0fddd4465b5cd78"
  head "https://github.com/applidium/XCTestHTMLReport.git", :branch => "develop_ad"

  def install
    system "xcodebuild" " clean" " build" " CODE_SIGNING_REQUIRED=NO" " -workspace" " XCTestHTMLReport.xcworkspace" " -scheme XCTestHTMLReport" " -configuration Release"
    bin.install "xchtmlreport"
  end
end
