class Lumoshell < Formula
  desc "Auto-sync Apple Terminal profiles with macOS appearance"
  homepage "https://github.com/aakaashjois/lumoshell"
  url "https://github.com/aakaashjois/lumoshell/releases/download/v0.2.7/lumoshell-darwin-universal.tar.gz"
  sha256 "5815b6f48c45421cdc4f86ae6a936f3cb03efce5aea469a757e0fbcfaa052e2c"
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
