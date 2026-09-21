# Contributing to Command Input

Thank you for improving Command Input.

## Architecture

Command Input is a Swift 6 app with no third-party dependencies:

- `Sources/App/CommandInputApp.swift`: app entry point, `AppDelegate`, and the
  SwiftUI `MenuBarExtra` menu.
- `Sources/App/AppModel.swift`: app state, Accessibility permission polling, and
  lifecycle supervision.
- `Sources/App/KeyRemapper.swift`: session `CGEventTap` lifecycle, tap recreation,
  and synthetic Eisu and Kana event posting.
- `Sources/Core/KeyRemapEngine.swift`: pure Command-tap state machine that
  evaluates modifier flags and key events (`keyDown`, `keyUp`, `flagsChanged`,
  pointer activity).
- `Sources/Core/DefaultsKey.swift`: UserDefaults key constants for on-disk
  preferences.
- `Sources/Core/LaunchAtLoginManager.swift`: launch-at-login state, preference
  persistence, `SMAppService` synchronization, and repair budget.
- `Sources/Core/LoginItemService.swift`: protocol abstraction over `SMAppService`
  for unit testing.

## Development setup

### Prerequisites

- macOS 14.0 Sonoma or later
- Xcode 16 or later, or Xcode Command Line Tools with Swift 6

### Building and testing

```sh
make            # Build build/Command Input.app for host architecture
make test       # Run unit tests via Swift Testing (swift test)
make run        # Run the local build
make clean      # Remove build artifacts
```

## Event tap and debugging

The event tap is created with `CGEventTapOptions.listenOnly` and observes
`keyDown`, `keyUp`, and `flagsChanged` events. `KeyRemapEngine` serves as the
pure state machine.

- **Tap recreation:** If macOS disables the tap and re-enabling fails,
  `KeyRemapper` automatically invalidates and recreates the tap.
- **Resetting permissions:** To reset Accessibility permissions for testing:
  ```sh
  tccutil reset Accessibility com.gajeroll.commandinput
  ```
- **Log streaming:** To verify tap initialization in system logs:
  ```sh
  log stream --predicate 'process == "CommandInput"' --debug
  ```
  Look for `Command Input: event tap started.`

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

Development `make` builds for the host architecture. Release builds produce a
Universal Binary (`arm64` and `x86_64`) via `make compile-universal` or
`make release`. `PrivacyInfo.xcprivacy` is bundled automatically into
`Contents/Resources/` (declaring no tracking, no collected data, and
UserDefaults usage CA92.1).

Public distribution outside the Mac App Store requires Developer ID signing,
Hardened Runtime, and Apple notarization.

### Release verification

`make verify-release` validates that:

1. `CFBundleShortVersionString` is set in `Info.plist`.
2. `CFBundleVersion` in `Info.plist` is an integer.
3. `CHANGELOG.md` contains a matching `## [VERSION]` heading.

To test verification failure handling, run:

```sh
make verify-release VERSION=9.9.9
```

### Release checklist

1. Bump `CFBundleShortVersionString` (e.g. `0.2.0`) and `CFBundleVersion`
   (integer, e.g. `2`) by hand in `Info.plist`.
2. Add a `## [VERSION] - YYYY-MM-DD` section in `CHANGELOG.md` and move items
   from `[Unreleased]`.
3. Run `make test` and `make verify-release`.
4. Store notarytool credentials (first time only):

   ```sh
   xcrun notarytool store-credentials "CommandInputNotary" \
     --apple-id "you@example.com" \
     --team-id "TEAMID1234" \
     --password "app-specific-password"
   ```

5. Commit and tag `vX.Y.Z`.
6. Build, sign, notarize, and staple:

   ```sh
   make notarize
   ```

   Override the identity or profile if needed:

   ```sh
   make notarize \
     DEVID_IDENTITY="Developer ID Application: Your Name (TEAMID1234)" \
     NOTARY_PROFILE="CommandInputNotary"
   ```

The archive is written to `dist/CommandInput-<version>.zip`.

## Documentation screenshots

When adding screenshots of the menu bar interface for documentation:

1. Capture the menu window using `screencapture`:

   ```sh
   screencapture -i -W docs/menu.png
   ```

2. Store images in the `docs/` directory.
3. Do not add markdown image references until the image file exists in the
   repository.

## Pull requests

- Keep changes focused.
- Ensure the project builds cleanly under Swift 6 (`-swift-version 6`).
- Ensure all tests pass (`make test`).
- Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
  for new types and methods.
