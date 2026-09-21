# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-09-22

### Added

- `KeyRemapEngine` pure state machine extracted into `CommandInputCore`.
- Unit test suite using Swift Testing and `Package.swift`, runnable via `make test`.
- `LaunchAtLoginManager` and `LoginItemService` protocol abstractions extracted
  into `CommandInputCore`.
- Automatic recreation of dead event taps when re-enabling fails.
- Universal Binary compilation (`arm64` and `x86_64`) via
  `make compile-universal` and `make release`.
- `PrivacyInfo.xcprivacy` privacy manifest declaring UserDefaults usage (CA92.1)
  and zero data collection or tracking.
- `make verify-release` target to check version format in `Info.plist` and
  `CHANGELOG.md` headings.
- Japanese user documentation (`README.ja.md`).

### Fixed

- Handled `keyUp` events in `KeyRemapEngine` so releasing a held key after a
  shortcut or tapping Command while another key is held properly cancels
  pending switches.

## [0.1.0] - 2026-09-21

### Added

- Initial public release of Command Input.
- Left Command single-tap mapping to Eisu (英数).
- Right Command single-tap mapping to Kana (かな).
- Pass-through for standard keyboard shortcuts and modifier combinations.
- Menu bar status item with active and inactive indicators.
- Launch at Login via `SMAppService`, with a stored preference and self-healing
  registration.
- Makefile build, development signing, and notarization targets.
