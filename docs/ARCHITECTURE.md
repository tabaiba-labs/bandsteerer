# Architecture

BandSteerer is a single-process SwiftUI menu-bar app built as a native Xcode macOS application. It deliberately has no application dependency layer, database, or remote service. Sparkle's bundled sandbox installer service performs user-approved app replacement.

## Components

- `BandSteererApp` declares the native `MenuBarExtra` and single-instance About window scenes.
- `AboutView` explains the utility and reads its displayed version and build from the app bundle.
- `MenuBarView` renders current connection state and user actions.
- `UpdateController` starts Sparkle with the app, makes the requested launch check without overriding a user's saved automatic-check preference, and exposes the manual check action.
- `AppModel` owns the main-actor session state, lifecycle notifications, bounded monitoring tasks, retry backoff, and login-item registration.
- `BandPreferenceStore` persists the explicit band choice for each hashed SSID identifier in `UserDefaults`.
- `WiFiService` serializes blocking CoreWLAN reads, scans, Keychain lookup, and association work on one dispatch queue.
- `CredentialStore` contains the app-specific generic-password Keychain operations.
- `LocationPermission` observes the authorization needed for CoreWLAN to reveal network information. It never requests coordinates.
- `WiFiTypes` contains the deterministic access-point selector and the pure session, correction, and wake policies exercised by the `BandSteererTests` Swift Testing target.

## Project structure

- `BandSteerer.xcodeproj` and its shared scheme are the only build definition.
- Sparkle 2 is the sole Swift Package Manager dependency. The project has no parallel build system.
- `Assets.xcassets` contains the compiled macOS app icon. The menu-bar label uses an SF Symbol and is independent of the application icon.
- `appcast.xml` is the static update feed. It contains only release metadata and EdDSA signatures; release archives live in GitHub Releases.
- Continuous integration tests, analyzes, and builds the shared scheme.

## State flow

An explicit preference belongs to the observed SSID and is restored when that SSID reconnects, including after an app launch or Mac reboot. Disconnect resets only the in-memory session to Automatic; choosing Automatic while connected deletes that network's saved preference. While a preference is active, a ten-second read checks the channel. A mismatch schedules a two-second delayed correction, and CoreWLAN scanning begins only if the mismatch remains.

Association requests carry a monotonically increasing generation. Cancelling an older task invalidates its generation, preventing a blocking CoreWLAN operation that returns late from overwriting newer UI or session state. Sleep also invalidates the current association before wake recovery begins.

## Security and privacy invariants

- Never log or persist a plaintext SSID, BSSID, scan result, or geographic coordinate. Persist only the SHA-256 SSID identifier needed to key a band preference.
- Never put a Wi-Fi password anywhere except process memory and an app-specific Keychain item.
- Keep Keychain items device-local.
- Keep CoreWLAN work off the main actor and serialized.
- Use only public Apple APIs and declared sandbox entitlements.
- Keep Automatic mode free of recurring monitoring.
- Never publish an update archive without a Sparkle EdDSA signature, and never put the private signing key in the repository.

Changes that cross one of these boundaries require corresponding tests, `PRIVACY.md` and `SECURITY.md` updates, and hardware validation.
