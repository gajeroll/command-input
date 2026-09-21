# Contributing to Command Input

Thank you for improving Command Input.

## Architecture

Command Input is a Swift 6 app with no third-party dependencies:

- `Sources/CommandInputApp.swift`: app entry point, `AppDelegate`, and the
  SwiftUI `MenuBarExtra` menu.
- `Sources/AppModel.swift`: app state, Accessibility permission polling, and
  `SMAppService` launch-at-login synchronization.
- `Sources/KeyRemapper.swift`: session `CGEventTap` that watches Left and Right
  Command and posts synthetic Eisu and Kana events.

## Development setup

### Prerequisites

- macOS 14.0 Sonoma or later
- Xcode 16 or later, or Xcode Command Line Tools with Swift 6

### Building and running

```sh
make            # Build build/Command Input.app
make run        # Run the local build
make clean      # Remove build artifacts
```

## Code signing

macOS TCC (Accessibility) and `SMAppService` (Login Items) enforce signing
requirements during development.

### 1. Apple Development (preferred)

`make` uses the first **Apple Development** identity it finds. That identity
keeps a stable Team ID across rebuilds, so Accessibility permission survives
and Launch at Login can be registered.

If more than one identity is installed, pass one explicitly:

```sh
make SIGN_IDENTITY="Apple Development: Your Name (TEAMID1234)"
```

### 2. Self-signed certificate

A trusted self-signed certificate keeps the identity stable so Accessibility
permission persists. `SMAppService` still needs a real Team ID.

```sh
make SIGN_IDENTITY="Command Input Dev"
```

### 3. Ad-hoc signing

If no identity is found, `make` falls back to ad-hoc signing (`-`). The
signature changes on every rebuild, so Accessibility permission must be granted
again after each compile, and Launch at Login cannot be registered.

Changing the signing identity changes how macOS identifies the app. Grant
Accessibility permission again after the first build that uses a different
identity. An Apple Development identity and a Developer ID identity usually
belong to different teams, so permissions and login items are not shared
between local and release builds. Verify Launch at Login with the build you
ship.

## Release and notarization

Public distribution outside the Mac App Store requires Developer ID signing,
Hardened Runtime, and Apple notarization.

1. Store notarytool credentials:

   ```sh
   xcrun notarytool store-credentials "CommandInputNotary" \
     --apple-id "you@example.com" \
     --team-id "TEAMID1234" \
     --password "app-specific-password"
   ```

2. Build, sign, notarize, and staple:

   ```sh
   make notarize
   ```

3. Override the identity or profile if needed:

   ```sh
   make notarize \
     DEVID_IDENTITY="Developer ID Application: Your Name (TEAMID1234)" \
     NOTARY_PROFILE="CommandInputNotary"
   ```

The archive is written to `dist/CommandInput-<version>.zip`. The version comes
from `CFBundleShortVersionString` in `Info.plist`. Bump that value, commit, and
tag `vX.Y.Z` before cutting a release.

## Pull requests

- Keep changes focused.
- The project must build under Swift 6 (`-swift-version 6`).
- Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
  for new types and methods.
