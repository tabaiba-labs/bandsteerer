# BandSteerer

[![CI](https://github.com/tabaiba-labs/bandsteerer/actions/workflows/ci.yml/badge.svg)](https://github.com/tabaiba-labs/bandsteerer/actions/workflows/ci.yml)

BandSteerer is a native macOS menu-bar utility for choosing the 2.4 GHz or 5 GHz band of the Wi-Fi network you are already using. It is useful when one network name is broadcast by several access points or frequency bands and macOS has roamed to an unsuitable band.

## Features

- **Automatic** leaves Wi-Fi roaming to macOS.
- **Prefer 2.4 GHz** associates with the strongest visible 2.4 GHz access point for the current network.
- **Prefer 5 GHz** does the same for 5 GHz.
- Band preferences are remembered separately for each network across disconnects, app launches, and Mac reboots.
- BandSteerer corrects a connection only when macOS moves to the wrong band. Moving between access points within the selected band requires no intervention.
- Sleep pauses connection checks. After wake, the app waits for Wi-Fi to reconnect before restoring the preference for the same network.
- **Open at Login** can restore saved preferences automatically after signing in.

BandSteerer is built with public macOS frameworks and has no third-party dependencies, analytics, updater, root helper, private framework, or application-level internet service. It runs in the App Sandbox.

## Requirements

- macOS 14 or later
- Location permission, which macOS requires before apps can read Wi-Fi network information

BandSteerer does not request or receive geographic coordinates.

## Install

Download the latest DMG from [GitHub Releases](https://github.com/tabaiba-labs/bandsteerer/releases), open it, and drag **BandSteerer** to **Applications**. Official binary releases are signed and notarized for macOS Gatekeeper.

## First use

1. Open BandSteerer and click its Wi-Fi menu-bar icon.
2. Choose **Allow Wi-Fi Access** and approve Location permission.
3. Select **Prefer 2.4 GHz** or **Prefer 5 GHz** while connected to a supported network.

The selection is remembered for that network. Choose **Automatic** to remove it.

On password-protected personal networks, macOS may show an authorization prompt when BandSteerer reads the password already saved in the Keychain. After a successful selection, the app stores a device-local Keychain copy so future corrections do not prompt repeatedly. BandSteerer never writes Wi-Fi passwords to files or logs.

## Limitations

BandSteerer requests a corrective association; it cannot disable macOS roaming at the driver level. macOS or the access point may move the connection temporarily, and reconnecting can briefly interrupt network traffic.

Preferences are identified by network name. Two unrelated networks with exactly the same name therefore share one band preference.

Open, OWE, and personal password-protected networks are supported. Enterprise Wi-Fi is not supported by the password-based association API used by the app. BandSteerer identifies 6 GHz connections in its status but currently offers preferences only for 2.4 GHz and 5 GHz.

## Build from source

Building requires Xcode 16 or later:

1. Open `BandSteerer.xcodeproj`.
2. Select the shared **BandSteerer** scheme and **My Mac** destination.
3. Choose **Product > Run** to build and launch the app.
4. Choose **Product > Test** to run the test suite.

Quit any installed copy before running from Xcode because BandSteerer allows only one instance. See [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a change.

## Privacy and security

Band preferences are stored locally using a SHA-256 identifier instead of the plaintext network name. Wi-Fi credentials remain in process memory or the macOS Keychain. SSIDs, BSSIDs, passwords, scan results, and geographic coordinates are never logged.

See [PRIVACY.md](PRIVACY.md) for data handling and [SECURITY.md](SECURITY.md) for vulnerability reporting.

## Project

- [MIT License](LICENSE)
- [Contributing](CONTRIBUTING.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Changelog](CHANGELOG.md)
- [Architecture](docs/ARCHITECTURE.md)
