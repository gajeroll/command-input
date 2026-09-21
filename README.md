# Command Input

Command Input is a lightweight macOS menu bar app for switching Japanese input modes with the Command keys:

- **Left Command** alone: Eisu
- **Right Command** alone: Kana

Normal shortcuts such as `Command-C` are passed through unchanged.

## Requirements

- macOS 14 Sonoma or later
- Swift 6 and Xcode Command Line Tools

## Install and Run

```sh
make            # Build build/Command Input.app
make run        # Run from the build directory
make install    # Copy to /Applications
```

The app runs in the menu bar and does not appear in the Dock.

## Permissions

Command Input requires **Accessibility** permission to observe and post keyboard events. Enable it in **System Settings > Privacy & Security > Accessibility** when prompted.

Input Monitoring is not required.

## Implementation

The codebase is intentionally small and uses Swift 6, SwiftUI `MenuBarExtra`, and the Observation framework.

- `Sources/CommandInputApp.swift`: app entry point and menu bar UI
- `Sources/AppModel.swift`: app state, permission polling, and user actions
- `Sources/KeyRemapper.swift`: `CGEventTap` handling and input switching

## Development Signing

`make` uses ad-hoc signing by default. For frequent local development, create a trusted self-signed code signing certificate named `Command Input Dev` so Accessibility permission can survive rebuilds.

The Makefile uses that certificate automatically when available, or you can pass it explicitly:

```sh
make SIGN_IDENTITY="Command Input Dev"
```

## Release Builds

Public distribution requires Developer ID signing and notarization.

Create a notarytool keychain profile:

```sh
xcrun notarytool store-credentials "CommandInputNotary" \
  --apple-id "you@example.com" \
  --team-id "TEAMID1234" \
  --password "app-specific-password"
```

Then build a notarized zip:

```sh
make notarize
```

Override the defaults if needed:

```sh
make notarize DEVID_IDENTITY="Developer ID Application: Your Name (TEAMID1234)" NOTARY_PROFILE="CommandInputNotary"
```

The output is written to `dist/CommandInput-<version>.zip`.

## Roadmap

- Homebrew Cask distribution
- DMG packaging
- Automatic updates

## Credits

Inspired by [iMasanari/cmd-eikana](https://github.com/iMasanari/cmd-eikana) and [dominion525/cmd-eikana](https://github.com/dominion525/cmd-eikana).

## License

MIT License
