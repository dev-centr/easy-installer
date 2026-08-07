# frozen_string_literal: true

class Ibex < Formula
  desc "Install Builder Extension — author packages and put tools on PATH"
  homepage "https://github.com/dev-centr/easy-installer"
  version "0.2.0"
  license "MIT"

  on_macos do
    url "https://github.com/dev-centr/easy-installer/releases/download/v#{version}/ibex-macos-amd64"
    sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  end

  on_linux do
    url "https://github.com/dev-centr/easy-installer/releases/download/v#{version}/ibex-linux-amd64"
    sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  end

  def install
    binary = Dir["ibex-*"].first || "ibex-macos-amd64"
    chmod 0755, binary if File.exist?(binary)
    bin.install binary => "ibex"
  end

  test do
    assert_match "ibex", shell_output("#{bin}/ibex --version")
  end
end
