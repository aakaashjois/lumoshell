class Lumoshell < Formula
  desc "Auto-sync Apple Terminal profiles with macOS appearance"
  homepage "https://github.com/aakaashjois/lumoshell"
  url "https://github.com/aakaashjois/lumoshell/releases/download/v0.1.0/lumoshell-darwin-universal.tar.gz"
  sha256 "3f35e8e915097baaef29722d8f01efb4960ce2b88f1f2cc590d079c194f918f6"
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
    install_script = opt_bin/"lumoshell-install"
    unless install_script.exist?
      opoo "Automatic startup setup skipped because `#{install_script}` was not found."
      return
    end

    if quiet_system(install_script.to_s)
      ohai "Automatic startup enrollment/start completed."
    else
      opoo "Automatic startup enrollment/start failed. Run `lumoshell install` manually."
    end
  end

  service do
    run [opt_bin/"lumoshell-appearance-sync-agent", "--apply-cmd", opt_bin/"lumoshell-apply", "--quiet"]
    keep_alive true
    run_type :immediate
  end

  def caveats
    <<~EOS
      lumoshell attempted automatic startup setup during install.

      Quick verify (recommended):
        lumoshell doctor

      If the appearance sync agent is not running, run:
        lumoshell install

      Test a one-time apply immediately:
        lumoshell apply --reason post-install

      Then change macOS appearance (Light/Dark) to confirm automatic sync.
      If prompted, allow Terminal Automation permissions.

      To override Terminal profile names, set these environment variables:
        export MAC_TERMINAL_LIGHT_PROFILE="Basic"
        export MAC_TERMINAL_DARK_PROFILE="Pro"

      Put them in your shell config (for example: ~/.zprofile), then restart Terminal.
      Overrides are applied automatically on the next appearance change or new shell session.
    EOS
  end

  test do
    assert_match "Usage", shell_output("#{bin}/lumoshell 2>&1", 1)
    assert_match "mode=", shell_output("#{bin}/lumoshell-apply --dry-run")
  end
end
