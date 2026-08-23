# Architecture

BandSteerer is a single-process SwiftUI menu-bar app built as a native Xcode macOS application. It deliberately has no application dependency layer, database, or remote service. Sparkle's bundled sandbox installer service performs user-approved app replacement.

## Components

- `BandSteererApp` declares the native `MenuBarExtra`, its stateful accessible label, and the single-instance About window scene.
- `AboutView` explains the utility and reads its displayed version and build from the app bundle.
- `MenuBarView` renders current connection state and user actions.
- `UpdateController` starts Sparkle with the app, makes the requested launch check without overriding a user's saved automatic-check preference, and exposes the manual check action.
- `AppModel` owns the main-actor session state, lifecycle notifications, bounded monitoring tasks, retry backoff, and login-item registration.
- `FiveGHzPreferenceStore` persists the per-network 5 GHz switch for each hashed SSID identifier in `UserDefaults`.
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

The 5 GHz switch belongs to the observed SSID and is persisted as soon as it is enabled. When that SSID reconnects, including after an app launch or Mac reboot, the preference is restored only if CoreWLAN does not require administrator authorization and an open network or app-owned credential makes association possible without user interaction. Otherwise the switch remains off until the user enables it, so any authorization prompt follows an explicit action. Disconnect resets only the in-memory session; turning the switch off while connected deletes that network's saved preference. While the switch is on, a ten-second read checks the channel. A mismatch schedules a two-second delayed correction, and CoreWLAN scanning begins only if the mismatch remains.

The menu-bar label reflects only state the app already observes: switch-off mode stays a plain Wi-Fi symbol during normal use and wake recovery, an active preference adds `5 GHz` and exposes correction state, and unavailable Wi-Fi or permission states show a slash. It does not introduce polling while the switch is off. Resetting saved preferences clears the preference store, cancels active correction work, and turns the switch off without changing macOS network settings.

Association requests carry a monotonically increasing generation. Cancelling an older task invalidates its generation, preventing a blocking CoreWLAN operation that returns late from overwriting newer UI or session state. Sleep also invalidates the current association before wake recovery begins.

Only temporarily missing 5 GHz service or a post-association verification mismatch keeps the preference active after an association failure. Credential, authorization, unsupported-network, and unknown failures turn the switch off and clear the unusable saved preference.

## Security and privacy invariants

- Never log or persist a plaintext SSID, BSSID, scan result, or geographic coordinate. Persist only the SHA-256 SSID identifier needed to key a 5 GHz preference.
- Never put a Wi-Fi password anywhere except process memory and an app-specific Keychain item.
- Keep Keychain items device-local.
- Keep CoreWLAN work off the main actor and serialized.
- Use only public Apple APIs and declared sandbox entitlements.
- Keep switch-off mode free of recurring monitoring.
- Never publish an update archive without a Sparkle EdDSA signature, and never put the private signing key in the repository.

Changes that cross one of these boundaries require corresponding tests, `PRIVACY.md` and `SECURITY.md` updates, and hardware validation.
