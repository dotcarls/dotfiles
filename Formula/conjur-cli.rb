# typed: false
# frozen_string_literal: true

# Installs the checksummed CyberArk Secrets Manager CLI release.
class ConjurCli < Formula
  desc "CyberArk Secrets Manager command-line interface"
  homepage "https://github.com/cyberark/conjur-cli-go"
  version "9.2.4"
  license "Apache-2.0"

  on_macos do
    on_arm do
      url "https://github.com/cyberark/conjur-cli-go/releases/download/v9.2.4/conjur-cli_9.2.4_darwin_arm64.tar.gz"
      sha256 "22c75b38f95823a8901cdc46e3605873857642d475993a5fc1b0526850a6001f"
    end

    on_intel do
      url "https://github.com/cyberark/conjur-cli-go/releases/download/v9.2.4/conjur-cli_9.2.4_darwin_amd64.tar.gz"
      sha256 "25d24bcc46421f5929034843d97be19ea8c6f044ed739104538a34a5c72a2c01"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/cyberark/conjur-cli-go/releases/download/v9.2.4/conjur-cli_9.2.4_linux_arm64.tar.gz"
      sha256 "b3c45ae7349b196e2a821a2d46697c47d1494970f19ea479dcf422f2b42760c8"
    end

    on_intel do
      url "https://github.com/cyberark/conjur-cli-go/releases/download/v9.2.4/conjur-cli_9.2.4_linux_amd64.tar.gz"
      sha256 "0f21c2b95534be281e16c47b067e64739b098442d210b35fce657b97b46275ba"
    end
  end

  def install
    bin.install "conjur"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/conjur --version")
  end
end
