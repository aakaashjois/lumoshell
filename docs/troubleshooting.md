# Troubleshooting

- Check status and paths:
  - `lumoshell doctor`
- View recent sync-agent logs (last 1 hour):
  - `lumoshell logs`
- Full log file path (24-hour rolling retention):
  - `~/Library/Logs/lumoshell/appearance-sync-agent.log`
- Validate LaunchAgent plist:
  - `plutil -lint launchd/com.user.lumoshell-appearance-sync-agent.plist`
- After Homebrew install, enroll startup behavior:
  - run `lumoshell install`
