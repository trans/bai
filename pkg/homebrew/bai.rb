class Bai < Formula
  desc "AI shell-command helper"
  homepage "https://github.com/trans/bai"
  url "https://github.com/trans/bai/archive/refs/tags/v0.4.3.tar.gz"
  sha256 "f05d82f1bdbf8de3e084a43835cffc3808d2998c1c479ae40c5243e26e18fea1"
  license "MIT"

  depends_on "crystal" => :build
  depends_on "bdw-gc"
  depends_on "libevent"
  depends_on "openssl@3"
  depends_on "pcre2"

  def install
    system "crystal", "build", "--release", "--no-debug", "src/main.cr", "-o", "bai"
    bin.install "bai"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/bai --version")
    assert_match "provider:", shell_output("#{bin}/bai --show-config --no-copy")
  end
end
