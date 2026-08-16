# Contributing

BandSteerer intentionally stays small and native. Changes should use public Apple APIs, preserve the App Sandbox, avoid third-party dependencies beyond the narrowly scoped Sparkle updater unless there is a compelling and documented need, and keep automatic mode free of recurring Wi-Fi work.

Participation is governed by [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). The component boundaries and invariants are documented in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Development setup

You need macOS 14 or later and Xcode 16 or later. The standalone Command Line Tools are not sufficient because the repository uses a native macOS application target and Swift Testing.

Open `BandSteerer.xcodeproj` and use the shared **BandSteerer** scheme. Before submitting a change:

1. Choose **Product > Test**.
2. Choose **Product > Analyze**.
3. Run `xcrun swift format lint --recursive BandSteerer BandSteererTests --strict` from the project root.
4. Confirm the `verify` GitHub Actions job passes.

No Apple account is required for local tests and builds. Keep signing configuration, archives, Derived Data, `xcuserdata`, and `.xcuserstate` out of commits.

## Change guidelines

- Add or update Swift Testing tests for policy and selection behavior.
- Never log an SSID, BSSID, password, scan result, geographic coordinate, or user path.
- Do not add credentials, private identifiers, local paths, or generated artifacts to source control.
- Keep UI changes native and accessible. Menu-bar artwork must remain legible as a monochrome macOS template image. Application icon changes must update every rendition declared in `BandSteerer/Assets.xcassets/AppIcon.appiconset/Contents.json`.
- Document changes to behavior, compatibility, privacy, or entitlements.
- Explain any new entitlement or outbound connection in both the pull request and `PRIVACY.md`.
- Follow the Swift API Design Guidelines. Use `xcrun swift format --in-place --recursive BandSteerer BandSteererTests` when Swift files changed, then repeat the checks above.

Hardware validation is required for changes to scanning, association, password lookup, sleep/wake recovery, or login-item behavior because those paths depend on macOS services and cannot be fully exercised by unit tests.

## Publishing updates

The signed release and appcast procedure is documented in [docs/UPDATES.md](docs/UPDATES.md). Never commit or paste the Sparkle private key into an issue, pull request, workflow, shell history, or repository file.
