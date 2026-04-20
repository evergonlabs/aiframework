# Homebrew formula for aiframework
# To use: brew tap evergonlabs/tap && brew install aiframework
#
# This formula is auto-updated by the release workflow.
# Manual updates: change url + sha256, then `brew audit --new aiframework`

class Aiframework < Formula
  desc "Make Claude Code understand your project instantly"
  homepage "https://github.com/evergonlabs/aiframework"
  url "https://github.com/evergonlabs/aiframework/releases/download/v__VERSION__/aiframework-__VERSION__.tar.gz"
  sha256 "__SHA256__"
  license "MIT"

  head "https://github.com/evergonlabs/aiframework.git", branch: "main"

  depends_on "rust" => :build

  def install
    cd "rust" do
      system "cargo", "build", "--release"
      bin.install "target/release/aiframework"
    end
  end

  test do
    assert_match "aiframework", shell_output("#{bin}/aiframework --help")
  end
end
