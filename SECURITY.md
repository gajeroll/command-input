# Security Policy

## Security and Privacy Architecture

Command Input uses macOS Accessibility APIs and a CoreGraphics event tap
(`CGEventTap`) to detect standalone Left and Right Command key presses. This
document states what that tap does and does not do.

### Keystroke handling

- **All `keyDown` and `keyUp` events are observed.** The tap must see every
  key-down and key-up so that pressing a combination such as Command-A or
  releasing a non-modifier key while Command is held cancels a pending
  input-mode switch. Without that, releasing Command after a shortcut would be
  mistaken for a standalone tap and would emit Eisu or Kana. Neither mask can
  be removed without changing that behavior.
- **Keystrokes are not stored.** Modifier state lives in memory only for the
  duration of a press, then is discarded. Nothing is written to disk, logs, or
  temporary files.
- **Keystrokes are not transmitted.** The app contains no networking code,
  analytics, or telemetry. The only process it launches is `/usr/bin/open`,
  used to reopen the app after Restart and to open System Settings.

### What `.listenOnly` guarantees

The event tap is created with `CGEventTapOptions.listenOnly`. That option
prevents the tap from modifying or suppressing events. It does **not** prevent
observation. "Listen-only" is proof that Command Input does not rewrite or
drop your keystrokes; it is not proof that it cannot see them.

Accessibility permission is still required. A listen-only tap that watches
`keyDown` and `keyUp` is still a keystroke observer.

### Local-only processing

- Event handling is confined to [`Sources/App/KeyRemapper.swift`](Sources/App/KeyRemapper.swift)
  and [`Sources/Core/KeyRemapEngine.swift`](Sources/Core/KeyRemapEngine.swift).
- The app imports `Cocoa`, `SwiftUI`, `Observation`, and `ServiceManagement`.
  It does not import `Network`, use `URLSession`, or open sockets.

### How to verify

From a clone of this repository:

```sh
# Should print nothing.
rg 'URLSession|Network|NWConnection|socket|http://|https://' Sources/
```

Read `Sources/App/KeyRemapper.swift` and `Sources/Core/KeyRemapEngine.swift` end
to end. Together, the two files are roughly 250 lines and contain the entire
event-tap and remapping path.

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |
| < 0.1.0 | :x:                |

## Reporting a Vulnerability

Do not open a public issue for a security vulnerability.

1. Use [GitHub Private Vulnerability Reporting](https://github.com/gajeroll/command-input/security/advisories/new).
2. Include steps to reproduce and any relevant system logs.
3. We will acknowledge the report and give an estimated timeline for a fix.
