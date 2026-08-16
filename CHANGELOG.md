# Changelog

## Unreleased

## 0.3.0 - 2026-08-16

### Changed

- Migrated the app to a native Xcode project with a shared build and test scheme.
- Replaced the oversized circled tray symbol with SwiftUI's natively sized Wi-Fi menu-bar label.
- Prevented cancelled association tasks from publishing stale state and cancelled active associations during sleep handling.
- Made the tested deterministic access-point selector the production selector.
- Stopped retaining the current BSSID in application state and marked copied Keychain credentials as device-local.

### Added

- Per-network band preferences that survive disconnects, app launches, and Mac reboots without storing plaintext SSIDs.
- Privacy, security, contribution, and architecture documentation.
- A complete macOS app-icon asset catalog generated from the supplied icon.
- Signed Sparkle updates with a silent check at app launch, daily scheduled checks, and a manual **Check for Updates…** action.

## 0.2.1

- Initial public-source baseline.
