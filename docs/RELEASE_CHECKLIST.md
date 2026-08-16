# Release checklist

Use this checklist for every public binary release.

## Prepare

1. Start from a clean checkout of the intended tag candidate.
2. Confirm Xcode 16 or later is selected and the intended account is available in **Xcode > Settings > Accounts**.
3. Update the BandSteerer target's version and build number, then update `CHANGELOG.md`.
4. Review every change since the previous release for new entitlements, network behavior, stored data, dependencies, and generated artifacts.
5. In Xcode, run **Product > Test** and **Product > Analyze** with the shared BandSteerer scheme.
6. Confirm the `verify` GitHub Actions job passes on the exact commit to be tagged.
7. Confirm no signing team, provisioning profile, archive, Derived Data, Xcode user state, personal path, account identifier, or private data is tracked.
8. If any history was imported or rewritten, run a dedicated secret scanner over the complete history before publishing.

## One-time GitHub configuration

Configure these encrypted GitHub Actions secrets. Never place their values in a file, commit, issue, pull request, workflow log, or release note.

- `APPLE_TEAM_ID`: the Apple Developer team used for public distribution.
- `APP_STORE_CONNECT_ISSUER_ID`: issuer ID for a team App Store Connect API key.
- `APP_STORE_CONNECT_KEY_ID`: key ID for that API key.
- `APP_STORE_CONNECT_PRIVATE_KEY_BASE64`: base64-encoded contents of the API key's `.p8` file.
- `DEVELOPER_ID_CERTIFICATE_BASE64`: base64-encoded PKCS #12 export containing exactly one Developer ID Application certificate and private key.
- `DEVELOPER_ID_CERTIFICATE_PASSWORD`: the strong, unique password used for that PKCS #12 export.

Use a dedicated App Store Connect API key with only the access needed for notarization. Restrict repository administration and Actions-secret access, enable secret scanning and push protection, and rotate either credential immediately if it may have been exposed.

## Build and publish

1. Confirm the Developer ID Application certificate and App Store Connect key belong to the intended public distributor and are not expired or revoked.
2. Update the target's marketing version and build number, update `CHANGELOG.md`, and merge the verified release commit to `main`.
3. Create and push an annotated tag named `vMAJOR.MINOR.PATCH`. The version after `v` must exactly match the target's marketing version.
4. Watch the `Release` workflow. It must complete signing, DMG creation, notarization, stapling, mounted-image verification, and GitHub Release publication.
5. Do not retry by moving or recreating a published tag. Fix the cause, increment the version, and create a new tag.

## Inspect the exported app

Download the published DMG and checksum, verify the checksum, mount the image, then set `EXPORTED_APP` to the mounted app's full path and run:

```sh
shasum -a 256 -c BandSteerer-<version>.dmg.sha256
hdiutil verify BandSteerer-<version>.dmg
lipo -archs "$EXPORTED_APP/Contents/MacOS/BandSteerer"
codesign --verify --deep --strict --verbose=2 "$EXPORTED_APP"
codesign -d --entitlements - "$EXPORTED_APP"
xcrun stapler validate BandSteerer-<version>.dmg
spctl --assess --type execute --verbose=2 "$EXPORTED_APP"
spctl --assess --type open --context context:primary-signature --verbose=2 BandSteerer-<version>.dmg
```

Confirm the executable contains both `arm64` and `x86_64`, the signature is valid, `com.apple.security.get-task-allow` is absent, the notarization ticket is stapled to the DMG, and Gatekeeper accepts both the app and disk image.

## Clean-machine validation

Download the exact DMG intended for publication on a Mac other than the build machine. Test both architectures when supported, using a clean user account with no earlier BandSteerer permissions or Keychain items.

Verify:

- Gatekeeper accepts the downloaded app without a bypass;
- the application and menu-bar icons are correctly sized in light and dark appearances;
- Location permission grant and denial states;
- 2.4 GHz and 5 GHz selection on a personal network;
- selection when the requested band is unavailable;
- Automatic clears the current network's saved preference and remains clear after relaunch;
- distinct preferences restore for two different SSIDs after disconnect and relaunch;
- disconnect, network change, sleep, and same-network wake recovery;
- wrong or unavailable saved credentials without credential disclosure;
- Open at Login enable, reboot/login launch, saved-preference restoration, and disable;
- replacement of an installed older version;
- migration from a pre-public bundle identity, including old login-item and app-Keychain cleanup;
- quit and relaunch behavior.

Use only disposable or sanitized network names in captured evidence.

## Publish

1. Confirm the GitHub Release points to the verified annotated tag and contains only the notarized DMG, SHA-256 file, and generated release notes.
2. Download the published assets and verify the checksum again.
3. Keep the previous release available for rollback until the new release has been exercised by real users.
