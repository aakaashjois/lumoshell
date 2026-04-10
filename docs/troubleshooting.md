# Troubleshooting

- Check status and paths:
  - `lumoshell doctor`
- Validate LaunchAgent plist:
  - `plutil -lint launchd/com.user.lumoshell-appearance-sync-agent.plist`
- After Homebrew install, enroll startup behavior:
  - run `lumoshell install`
