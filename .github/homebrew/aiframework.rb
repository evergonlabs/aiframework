# Homebrew formula for aiframework
# To use: brew tap evergonlabs/tap && brew install aiframework
#
# This formula is auto-updated by the release workflow.
# Manual updates: change url + sha256, then `brew audit --new aiframework`

class Aiframework < Formula
  desc "Universal automation bootstrap CLI for Claude Code"
  homepage "https://github.com/evergonlabs/aiframework"
  url "https://github.com/evergonlabs/aiframework/archive/refs/tags/v__VERSION__.tar.gz"
  sha256 "__SHA256__"
  license "MIT"

  depends_on "jq"
  depends_on "python@3.12"

  def install
    prefix.install Dir["*"]
    bin.install_symlink prefix/"bin/aiframework"
    bin.install_symlink prefix/"bin/aiframework-mcp"
    bin.install_symlink prefix/"bin/aiframework-telemetry"
  end

  def caveats
    <<~EOS
      To bootstrap a project:
        aiframework run --target ~/your-project

      Then open Claude Code and run:
        /aif-ready

      Optional: Install sheal for runtime session intelligence:
        npm install -g @liwala/sheal@latest
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/aiframework --version")
  end
end
