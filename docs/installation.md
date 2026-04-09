# Installation

## Requirements

- macOS (Apple Terminal)
- `bash`
- Homebrew (for formula/service install path)

## Homebrew (recommended)

Install from the official tap:

```sh
brew tap aakaashjois/lumoshell
brew install lumoshell
```

If Homebrew does not resolve the short formula name in your environment, use:

```sh
brew install aakaashjois/lumoshell/lumoshell
```

After Homebrew install, enroll startup behavior:

```sh
lumoshell install
```

Service lifecycle commands:

```sh
brew services start lumoshell
brew services stop lumoshell
brew services restart lumoshell
brew services list
```

Uninstall:

```sh
lumoshell uninstall
brew uninstall --formula lumoshell
```

## Build From Source

See `build-from-source.md` for manual build and install steps.
