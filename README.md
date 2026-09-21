# Command Input

[日本語](README.ja.md)

Command Input is a lightweight macOS menu bar app that switches Japanese input
modes with single taps of the Command keys:

- **Left Command** (tap alone) → Eisu (英数 / Alphanumeric)
- **Right Command** (tap alone) → Kana (かな / Japanese)

Standard keyboard shortcuts such as `Command-C` or `Command-Space` pass through
unchanged.

## Requirements

- **Platform:** macOS 14.0 Sonoma or later
- **Architecture:** Apple silicon and Intel (Universal release builds)
- **Build (source only):** Swift 6 and Xcode Command Line Tools

## Installation

### Prebuilt binary

Download the latest `CommandInput-<version>.zip` from
[Releases](https://github.com/gajeroll/command-input/releases), unzip it, and
drag `Command Input.app` to `/Applications`.

### Build from source

```sh
git clone https://github.com/gajeroll/command-input.git
cd command-input
make            # Build build/Command Input.app (host architecture)
make run        # Run from the build directory
make install    # Copy to /Applications
```

Command Input runs as a menu bar accessory and does not appear in the Dock.

### Uninstallation

```sh
make uninstall  # Remove /Applications/Command Input.app
```

You can also quit the app and move it to the Trash.

## Permissions and Privacy

Command Input requires **Accessibility** permission to observe modifier keys
and post input-switching events.

- **Granting permission:** Enable the app under **System Settings > Privacy &
  Security > Accessibility** when prompted.
- **Input Monitoring is not required.** The app uses a session-level
  `CGEventTap` and does not need the broader Input Monitoring permission.
- **What the tap does:** The tap is created with `listenOnly`, so it cannot
  modify or suppress events. It observes `keyDown`, `keyUp`, and `flagsChanged`
  events so shortcuts such as Command-A or held keys cancel a pending switch.
  Keystrokes are never stored or sent anywhere.
- **Privacy manifest:** `PrivacyInfo.xcprivacy` is bundled into the app
  (no tracking, no collected data, and UserDefaults reason CA92.1).

See [SECURITY.md](SECURITY.md) for the full policy and a verification command.

## Launch at Login

Command Input manages startup through macOS `SMAppService` and an internal
preference. The stored preference is the source of truth, so a registration
that macOS silently drops is restored instead of being treated as an opt-out.

### Default behavior

- **Installed app** (`/Applications` or `~/Applications`): enabled automatically
  on first launch.
- **Development builds** (`build/`): automatic registration is off so a
  temporary path is not recorded. The menu toggle still works.

### Approval, repair, and opt-out

- **Approval required:** If macOS asks for approval, choose **Open Login Items
  Settings** in the app menu and enable Command Input once.
- **Repair:** If macOS loses the registration, the app retries a few times and
  then shows **Repair Launch at Login** in the menu.
- **Disabling:** Use the in-app toggle. Removing the item in System Settings
  only clears the system record, so the app restores it from the stored
  preference.

## Troubleshooting

- **Keys are not switching:** Open **System Settings > Privacy & Security >
  Accessibility** and confirm Command Input is enabled. After an update or
  identity change, turn the checkbox off and on again.
- **Menu shows "Repair Launch at Login":** Click the item to re-register with
  macOS.
- **Menu shows "Approve Command Input in Login Items":** Open Login Items in
  System Settings and enable the app.

## Development

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for local
setup, code signing, architecture notes, and the release workflow.

```sh
make            # Build local host binary
make test       # Run test suite via Swift Testing
make run        # Build and run locally
make clean      # Remove build artifacts
```

## Security

For event-tap guarantees and vulnerability reporting, see
[SECURITY.md](SECURITY.md).

## Roadmap

- Homebrew Cask distribution
- DMG packaging
- Automatic updates

## Credits

Inspired by [iMasanari/cmd-eikana](https://github.com/iMasanari/cmd-eikana) and
[dominion525/cmd-eikana](https://github.com/dominion525/cmd-eikana).

## License

Distributed under the [MIT License](LICENSE).
