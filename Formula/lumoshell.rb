class Lumoshell < Formula
  desc "Auto-sync Apple Terminal profiles with macOS appearance"
  homepage "https://github.com/aakaashjois/lumoshell"
  url "https://github.com/aakaashjois/lumoshell/releases/download/v0.2.0/lumoshell-darwin-universal.tar.gz"
  sha256 "235096c9b5e59d7348f1ff71589608913f33c7298e64b6809202b559fb9e7038"
  license "MIT"

  head "https://github.com/aakaashjois/lumoshell.git", branch: "main"

  def install
    %w[
      lumoshell
      lumoshell-apply
      lumoshell-install
      lumoshell-uninstall
      lumoshell-appearance-sync-agent
    ].each do |binary|
      bin.install binary
    end
  end

  def post_install
    ohai "Run `lumoshell install` manually to enroll startup and grant permissions."
  end

  service do
    run [opt_bin/"lumoshell-appearance-sync-agent", "--apply-cmd", opt_bin/"lumoshell-apply", "--quiet"]
    keep_alive true
    run_type :immediate
  end

  def caveats
    <<~EOS
      Run `lumoshell install` after Homebrew installation to enroll startup setup.

      Quick verify (recommended):
        lumoshell doctor

      Enroll/start the appearance sync agent:
        lumoshell install

      Test a one-time apply immediately:
        lumoshell apply --dry-run

      Then change macOS appearance (Light/Dark) to confirm automatic sync.
      If prompted, allow Terminal Automation permissions.

      Set profiles from the CLI:
        lumoshell profile set light "Basic"
        lumoshell profile set dark "Pro"

      Optional env overrides:
        export LUMOSHELL_PROFILE_LIGHT="Basic"
        export LUMOSHELL_PROFILE_DARK="Pro"

      Env overrides take precedence over saved `lumoshell profile set` values.
    EOS
  end

  test do
    assert_match "Usage", shell_output("#{bin}/lumoshell 2>&1", 1)
    assert_match "mode=", shell_output("#{bin}/lumoshell-apply --dry-run")
  end
end
