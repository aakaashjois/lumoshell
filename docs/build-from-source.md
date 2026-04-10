# Build From Source

Use this path if you do not want to install via Homebrew.

## Requirements

- macOS
- `bash`
- Swift toolchain

## Build

Build the appearance sync agent:

```sh
cd src/appearance-sync-agent
swift build -c release
```

## Install Binaries

Copy binaries to a directory on your `PATH` (example uses `/usr/local/bin`):

```sh
cp src/appearance-sync-agent/.build/release/lumoshell-appearance-sync-agent /usr/local/bin/
cp bin/lumoshell /usr/local/bin/
cp bin/lumoshell-apply /usr/local/bin/
cp bin/lumoshell-install /usr/local/bin/
cp bin/lumoshell-uninstall /usr/local/bin/
```

Enroll startup behavior:

```sh
lumoshell install
```

## Uninstall Manual Install

```sh
lumoshell uninstall
rm -f /usr/local/bin/lumoshell
rm -f /usr/local/bin/lumoshell-apply
rm -f /usr/local/bin/lumoshell-install
rm -f /usr/local/bin/lumoshell-uninstall
rm -f /usr/local/bin/lumoshell-appearance-sync-agent
```
