# Changelog

## 0.5.0 - 2026-08-23

### Added

- Added automated Swift package update checks and made Sparkle's third-party notices part of both app and disk-image packaging.

### Changed

- Replaced the Automatic, 2.4 GHz, and 5 GHz picker with one native per-network **Prefer 5 GHz** switch, migrating saved 2.4 GHz choices to off and removing the generic target-band steering path.
- Replaced the text menu-bar status with native template-rendered on and off icons that follow the active macOS appearance.
- Moved **Check for Updates…** into the More menu instead of showing it as an unlabeled footer icon.
- Limited duplicate CI runs to pull requests and pushes to `main`, clarified private vulnerability reporting, and made the bug-report version prompt release-independent.

### Fixed

- Kept custom menu-bar SVGs at an 18-point intrinsic size so macOS does not allocate an oversized, off-screen status item.
- Upgraded Sparkle to 2.9.6 for its latest installer and archive-handling security hardening.

## 0.4.0 - 2026-08-17

### Changed

- Restored saved band preferences only when they can be enforced without an authorization prompt; otherwise launch now falls back to Automatic until the user chooses a band.
- Made the menu-bar label show active bands with explicit GHz units, while keeping Automatic visually quiet during wake recovery and avoiding Automatic-mode polling.
- Kept band choices cancellable during an in-progress switch and clarified localizable Location permission and connection status copy without widening the native menu.
- Reordered menu actions, added the standard Command-Q shortcut, and replaced the deprecated application activation call.
- Tightened connection details to channel and signal strength and made errors visually distinct, clearing stale errors when the menu reopens.

### Added

- Added an About-window action to reset every saved band preference with confirmation.

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
