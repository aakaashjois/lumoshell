class Lumoshell < Formula
  desc "Auto-sync Apple Terminal profiles with macOS appearance"
  homepage "https://github.com/aakaashjois/lumoshell"
  url "https://github.com/aakaashjois/lumoshell/releases/download/v0.2.4/lumoshell-darwin-universal.tar.gz"
  sha256 "90b62f883373e0f53f2cca9d2aa58806375a6f5a9fba11e17cea5d42024c5f11"
  license "MIT"

  head "https://github.com/aakaashjois/lumoshell.git", branch: "main"
  def install
    %w[
      lumoshell
      lumoshell-install
      lumoshell-uninstall
      lumoshell-appearance-sync-agent
    ].each do |binary|
      bin.install binary
    end
  end

  service do
    run [opt_bin/"lumoshell-appearance-sync-agent", "--quiet"]
    keep_alive true
    run_type :immediate
  end

  def caveats
    <<~EOS
      Run `lumoshell setup` after Homebrew installation to enroll startup setup.

      Quick verify (recommended):
        lumoshell doctor

      Enroll/start the appearance sync agent:
        lumoshell setup

      Test a one-time apply immediately:
        lumoshell apply --dry-run

      Then change macOS appearance (Light/Dark) to confirm automatic sync.
      If prompted, allow Terminal Automation permissions.

      Set profiles interactively from the CLI:
        lumoshell setup
    EOS
  end

  test do
    assert_match "Usage", shell_output("#{bin}/lumoshell 2>&1", 1)
    assert_match "mode=", shell_output("#{bin}/lumoshell apply --dry-run")
  end
end
