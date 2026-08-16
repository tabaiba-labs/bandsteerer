# Contributing

BandSteerer intentionally stays small and native. Changes should use public Apple APIs, preserve the App Sandbox, avoid third-party dependencies unless there is a compelling and documented need, and keep automatic mode free of recurring work.

Participation is governed by [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). The component boundaries and invariants are documented in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Development setup

You need macOS 14 or later and Xcode 16 or later. The standalone Command Line Tools are not sufficient because the repository uses a native macOS application target and Swift Testing.

Open `BandSteerer.xcodeproj` and use the shared **BandSteerer** scheme. Before submitting a change:

1. Choose **Product > Test**.
2. Choose **Product > Analyze**.
3. Run `xcrun swift format lint --recursive BandSteerer BandSteererTests --strict` from the project root.
4. Confirm the `verify` GitHub Actions job passes.

No Apple account or development team is required for local tests and builds. Never commit a development team, provisioning profile, certificate name, archive, Derived Data, `xcuserdata`, or `.xcuserstate`. Xcode account and signing data must remain in the developer's local Keychain and user settings.

## Change guidelines

- Add or update Swift Testing tests for policy and selection behavior.
- Never log an SSID, BSSID, password, scan result, geographic coordinate, or user path.
- Do not add account identifiers, signing subjects, secrets, local SDK paths, or generated artifacts to source control.
- Keep UI changes native and accessible. Menu-bar artwork must remain legible as a monochrome macOS template image. Application icon changes must update every rendition declared in `BandSteerer/Assets.xcassets/AppIcon.appiconset/Contents.json`.
- Document behavior, compatibility, privacy, entitlement, and release-process changes.
- Explain any new entitlement or outbound connection in both the pull request and `PRIVACY.md`.
- Follow the Swift API Design Guidelines. Use `xcrun swift format --in-place --recursive BandSteerer BandSteererTests` when Swift files changed, then repeat the checks above.

Hardware validation is required for changes to scanning, association, password lookup, sleep/wake recovery, or login-item behavior because those paths depend on macOS services and cannot be fully exercised by unit tests.

Maintainers should require the `verify` CI job and at least one approving review on the default branch, prevent force pushes and deletion, enable private vulnerability reporting and secret scanning, and restrict workflow permissions to the minimum necessary.
