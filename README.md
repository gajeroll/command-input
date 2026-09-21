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

## Launch at Login

Launch at Login uses macOS `SMAppService` and stores your choice in app preferences. That stored
choice, not the current system state, decides what the app does on launch, so a registration macOS
silently drops is restored instead of being mistaken for an opt-out.

The first run from `/Applications` or `~/Applications` turns Launch at Login on. A copy running from
`build/` is never registered automatically, because that bundle is about to be replaced or moved.
The menu toggle works from any location.

If macOS drops the registration, the app re-registers it on the next few launches and then stops,
leaving **Repair Launch at Login** in the menu. If macOS asks for approval instead, the menu links
to Login Items in System Settings, where the item has to be turned on once.

Use the menu toggle to opt out. Deleting the item in System Settings only clears the system record,
so the app restores it from the stored preference.

## Permissions

Command Input requires **Accessibility** permission to observe and post keyboard events. Enable it in **System Settings > Privacy & Security > Accessibility** when prompted.

Input Monitoring is not required.

## Implementation

The codebase is intentionally small and uses Swift 6, SwiftUI `MenuBarExtra`, and the Observation framework.

- `Sources/CommandInputApp.swift`: app entry point and menu bar UI
- `Sources/AppModel.swift`: app state, permission polling, and user actions
- `Sources/KeyRemapper.swift`: `CGEventTap` handling and input switching

## Development Signing

`make` prefers an available **Apple Development** signing identity. Accessibility permission only
needs a signing identity that stays the same across rebuilds, but Login Items additionally needs a
real Team ID, which ad-hoc signing cannot provide. Override the identity explicitly when more than
one is installed:

```sh
make SIGN_IDENTITY="Apple Development: Your Name (TEAMID1234)"
```

Without an Apple Development identity, `make` falls back to ad-hoc signing. Ad-hoc signatures change
on every rebuild, so Accessibility permission has to be granted again each time and Launch at Login
cannot be registered at all. A trusted self-signed certificate is a better fallback because it at
least keeps the identity stable:

```sh
make SIGN_IDENTITY="Command Input Dev"
```

Switching signing identities changes how macOS identifies the app, so Accessibility permission has
to be granted again after the first build that changes it. An Apple Development identity and a
Developer ID identity usually belong to different teams, so permissions and login items are not
shared between local and release builds. Verify Launch at Login with the build you ship.

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
