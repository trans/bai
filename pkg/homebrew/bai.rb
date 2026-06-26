class Bai < Formula
  desc "AI shell-command helper"
  homepage "https://github.com/trans/bai"
  url "https://github.com/trans/bai.git",
      tag: "v0.4.4"
  version "0.4.4"
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
