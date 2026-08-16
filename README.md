# BandSteerer

[![CI](https://github.com/tabaiba-labs/bandsteerer/actions/workflows/ci.yml/badge.svg)](https://github.com/tabaiba-labs/bandsteerer/actions/workflows/ci.yml)

BandSteerer is a native macOS menu-bar utility for choosing the 2.4 GHz or 5 GHz access point behind the Wi-Fi network you are already using. It is useful when one SSID is broadcast by several access points or frequency bands and macOS has roamed to an unsuitable band.

BandSteerer remembers a separate preference for each Wi-Fi network across disconnects, app launches, and Mac reboots. Choosing **Automatic** clears the saved preference for the current network. It does not change macOS saved-network settings.

## What it does

- **Automatic** leaves Wi-Fi roaming to macOS.
- **Prefer 2.4 GHz** scans the current SSID and associates with its strongest visible 2.4 GHz access point.
- **Prefer 5 GHz** does the same for 5 GHz.
- A preference is restored whenever the Mac reconnects to that SSID. While disconnected or on a network without a saved preference, BandSteerer uses **Automatic**.
- A selected preference is checked every ten seconds. The check reads the current channel; it scans only after macOS moves to the wrong band.
- A corrective association waits two seconds to ignore a momentary roam. Transient scan misses are retried, and repeated failures back off from 15 seconds to two minutes.
- Sleep pauses session checks. After wake, BandSteerer gives Wi-Fi up to 32 seconds to reconnect and resumes the preference only when the Mac returns to the same SSID.
- Moving between access points within the selected band requires no intervention.
- Preferences are stored locally in standard macOS app preferences. SSID names are represented by SHA-256 identifiers rather than stored in plaintext.

BandSteerer uses public Apple frameworks and has no third-party dependencies, analytics, update service, root helper, private framework, or internet API. It runs in the App Sandbox. See [PRIVACY.md](PRIVACY.md) for the precise data and Keychain behavior.

## Limits

CoreWLAN can request association with a scanned access point, but it cannot disable macOS roaming at the driver level. A preference is therefore corrective rather than an absolute radio lock. macOS or the access point may move the connection for up to one check interval, and reconnecting can briefly interrupt network traffic.

The SSID identifies the network for preference purposes. Two unrelated networks with exactly the same SSID therefore share one band preference; BSSID cannot be used because BandSteerer intentionally moves between BSSIDs on that SSID.

Enterprise Wi-Fi is not supported by the public password-based association API used here. Open, OWE, and personal password-protected networks are supported. BandSteerer identifies 6 GHz connections in its status, but this release offers preferences only for 2.4 GHz and 5 GHz.

## Requirements

- macOS 14 or later
- Xcode 16 or later
- Location permission, because macOS protects SSID and BSSID information behind it

BandSteerer asks only for authorization status and Wi-Fi information. It never requests geographic coordinates from `CLLocationManager`.

## Install

Download the latest `BandSteerer-<version>.dmg` from [GitHub Releases](https://github.com/tabaiba-labs/bandsteerer/releases/latest), open it, and drag **BandSteerer** to the **Applications** shortcut. The public DMG is Developer ID signed, notarized by Apple, and stapled for Gatekeeper.

## Build and test

1. Open `BandSteerer.xcodeproj` in Xcode.
2. Select the shared **BandSteerer** scheme and **My Mac** destination.
3. Choose **Product > Run** to build and launch the app.
4. Choose **Product > Test** to run the Swift Testing suite.
5. Choose **Product > Analyze** for Xcode's static analysis.

Quit any installed copy of BandSteerer before using **Product > Run**. Development builds run from Xcode's Derived Data and do not need to replace the copy in Applications. When you want to keep a local build, choose **Product > Archive**, then export it from Organizer and replace the installed app.

`BandSteerer.xcodeproj` is the sole build definition. The repository has no external package manager or parallel command-line build system. Continuous integration invokes the same shared scheme with `xcodebuild`.

An Apple Developer account is not required for local development. Xcode can sign local builds to run on the current Mac. The committed project contains no development team, provisioning profile, certificate subject, account data, or Xcode user state.

## First launch

1. Open BandSteerer and click its Wi-Fi menu-bar icon.
2. Choose **Allow Wi-Fi Access** and approve Location permission.
3. Select a band while connected to a supported network.

That choice is remembered for the network. Select **Automatic** to remove it.

Password-protected personal networks may trigger a native authorization prompt when BandSteerer reads the password already saved by macOS. After a successful manual selection, BandSteerer stores an app-specific, device-local copy in the login Keychain so automatic corrections do not prompt. It never writes the password to a file or log.

The **Open at Login** toggle uses `SMAppService`, Apple's login-item API. Moving the app after enabling it may require disabling and re-enabling the toggle.

Saved preferences remain on the Mac whether or not BandSteerer is running. Enable **Open at Login** if the app should resume enforcing them automatically after signing in; otherwise they are restored the next time BandSteerer opens.

### Migrating from a pre-public build

The public source uses a neutral bundle identifier, so macOS treats it as a different app identity from earlier private builds. Before replacing an earlier build, turn off **Open at Login** in that build and quit it. After installing the public build, grant Location permission again, select a band once so it can create its new app-specific Keychain item, and re-enable **Open at Login** if desired.

Earlier app-specific password copies are not read by the public build. They can be removed in Keychain Access by searching for **BandSteerer Wi-Fi credential**; removing them does not delete the passwords macOS uses to join those networks.

## Xcode configuration

The project uses Swift 6, macOS 14 as its deployment target, complete strict-concurrency checking, warnings as errors, the App Sandbox, and the hardened runtime. The shared scheme builds both the application and its test target.

Set the public version and build number in the BandSteerer target's **General** settings before archiving. Changing the bundle identifier creates a distinct macOS privacy, login-item, and app-Keychain identity.

Signing settings that identify a developer or Apple account must remain local. Select your team in Xcode only when you need a signed archive; never commit that selection or any generated Xcode user data.

## Public binary releases

The `Release` GitHub Actions workflow is the canonical public distribution path. Pushing an annotated `vMAJOR.MINOR.PATCH` tag whose version matches the Xcode target:

1. builds the Xcode Release configuration for both Apple Silicon and Intel;
2. signs the app and disk image with a Developer ID Application identity;
3. creates a drag-and-drop DMG containing the app and an Applications shortcut;
4. submits the DMG to Apple's notary service and staples the accepted ticket;
5. verifies the mounted app, Gatekeeper assessment, architectures, signature, and DMG; and
6. publishes the DMG and SHA-256 checksum as a GitHub Release.

Account identifiers, certificates, private keys, and notarization credentials are never committed. Maintainers configure the six encrypted Actions secrets documented in [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md). Local fallback releases can still use **Product > Archive** and Xcode Organizer's **Distribute App > Developer ID** workflow.

Apple references:

- [Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Packaging Mac software for distribution](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)

## Icons

`BandSteerer/Assets.xcassets/AppIcon.appiconset` contains the ten processed macOS renditions from 16×16 through 1024×1024. Xcode validates and compiles them into the application icon used in Finder, Applications, and release bundles.

When replacing the application icon, update every filename and scale declared in the asset catalog's `Contents.json`, then inspect the compiled icon at small and large sizes. The menu-bar label intentionally uses SwiftUI's monochrome `wifi` SF Symbol so macOS controls its size, contrast, highlighted state, and accessibility appearance.

## Open-source maintenance

- License: [MIT](LICENSE)
- Contributing: [CONTRIBUTING.md](CONTRIBUTING.md)
- Code of conduct: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- Security reports: [SECURITY.md](SECURITY.md)
- Release history: [CHANGELOG.md](CHANGELOG.md)
- Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Release checklist: [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md)

Xcode build products, archives, Derived Data, and per-user settings are excluded from source control.
