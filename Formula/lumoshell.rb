class Lumoshell < Formula
  desc "Auto-sync Apple Terminal profiles with macOS appearance"
  homepage "https://github.com/aakaashjois/lumoshell"
  license "MIT"

  head "https://github.com/aakaashjois/lumoshell.git", branch: "main"

  def install
    require "digest"

    asset_name = "lumoshell-darwin-universal.tar.gz"
    checksums_name = "SHA256SUMS.txt"
    release_base_url = ENV["LUMOSHELL_RELEASE_BASE_URL"] || "https://github.com/aakaashjois/lumoshell/releases/latest/download"
    release_base_url = release_base_url.chomp("/")

    system "curl", "-fsSL", "#{release_base_url}/#{asset_name}", "-o", asset_name
    system "curl", "-fsSL", "#{release_base_url}/#{checksums_name}", "-o", checksums_name

    checksum_line = (buildpath/checksums_name).read.lines.find do |line|
      line.split.last == asset_name
    end
    odie "Could not find checksum for #{asset_name} in #{checksums_name}" if checksum_line.nil?

    expected_sha = checksum_line.split.first
    actual_sha = Digest::SHA256.file(buildpath/asset_name).hexdigest
    odie "Checksum mismatch for #{asset_name}" if actual_sha != expected_sha

    system "tar", "-xzf", asset_name

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
    if install_script.exist? && !quiet_system(install_script.to_s)
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
