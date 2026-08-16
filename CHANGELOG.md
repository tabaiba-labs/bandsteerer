# Changelog

## Unreleased

### Changed

- Made the native Xcode project and shared scheme the sole build, test, analysis, archive, and distribution definition.
- Kept developer-team, signing-certificate, provisioning, account, and per-user Xcode data outside the repository.
- Documented a local Xcode release process that signs, notarizes, staples, and verifies a universal drag-and-drop DMG without sharing Apple credentials with GitHub Actions.
- Replaced the oversized circled tray symbol with SwiftUI's natively sized Wi-Fi menu-bar label.
- Prevented cancelled association tasks from publishing stale state and cancelled active associations during sleep handling.
- Made the tested deterministic access-point selector the production selector.
- Stopped retaining the current BSSID in application state and marked copied Keychain credentials as device-local.
- Strengthened policy tests and full-target compilation in continuous integration.

### Added

- Per-network band preferences that survive disconnects, app launches, and Mac reboots without storing plaintext SSIDs.
- Privacy, security, contribution, architecture, and release documentation.
- Continuous integration for privacy checks, metadata validation, formatting, tests, static analysis, and universal Release builds.
- Contributor templates and conventional editor, formatting, line-ending, and dependency-update configuration.
- A complete macOS app-icon asset catalog generated from the supplied icon.

## 0.2.1

- Initial public-source baseline.
