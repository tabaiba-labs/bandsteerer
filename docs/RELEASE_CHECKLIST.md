# Release checklist

BandSteerer releases are created locally from Xcode. GitHub Actions never receives an Apple certificate, private key, account identifier, or notarization credential. The repository has no release script or second build system; the commands below use only tools installed with Xcode.

## One-time maintainer setup

1. Keep the Developer ID Application certificate and its private key in the local login Keychain. Do not export them for GitHub or commit any certificate material.
2. Make sure the intended Apple Developer account is available in **Xcode > Settings > Accounts**.
3. Store notarization credentials in the local Keychain under the fixed profile name used below:

   ```sh
   xcrun notarytool store-credentials "BandSteerer-Notary"
   ```

   `notarytool` prompts interactively and validates the credentials before saving them. Never put the prompted values in this repository, shell scripts, issues, workflow logs, or release notes.

## Prepare the release commit

1. Start from a clean `main` checkout.
2. Update the BandSteerer target's marketing version and build number in Xcode, then update `CHANGELOG.md`.
3. Review changes since the previous release for new entitlements, network behavior, stored data, dependencies, and generated artifacts.
4. Run **Product > Test** and **Product > Analyze** with the shared BandSteerer scheme.
5. Run `xcrun swift format lint --recursive BandSteerer BandSteererTests --strict` from the project root.
6. Confirm the `verify` GitHub Actions job passes on the exact release commit.
7. Confirm `git status --short` is empty and no development team, provisioning profile, archive, Derived Data, Xcode user state, personal path, account identifier, secret, or private data is tracked.
8. Create an annotated tag locally, but do not push it yet:

   ```sh
   git tag -a vMAJOR.MINOR.PATCH -m "BandSteerer MAJOR.MINOR.PATCH"
   ```

If the local release fails, fix it before publishing and recreate the still-local tag. Never move or recreate a tag after it has been pushed.

## Archive and export with Xcode

1. Open `BandSteerer.xcodeproj` at the locally tagged commit.
2. Select the **BandSteerer** scheme and the generic **Any Mac (Apple Silicon, Intel)** destination.
3. Select the intended team under **Signing & Capabilities**. This is a local release setting; do not commit the resulting project change.
4. Choose **Product > Archive**.
5. In Organizer, select the archive and choose **Distribute App > Direct Distribution**. Follow Xcode's signing and notarization flow, then export the notarized app to `dist/XcodeExport` in the project directory. The `dist` directory is ignored by Git.
6. Restore any local signing-setting change and confirm again that source control contains no team or account identifier.

Open a fresh `zsh` session from the project root and verify the exported app:

```sh
set -euo pipefail
APP_PATH="$PWD/dist/XcodeExport/BandSteerer.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
EXECUTABLE="$APP_PATH/Contents/MacOS/BandSteerer"

test -d "$APP_PATH"
lipo -archs "$EXECUTABLE"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl --assess --type execute --verbose=2 "$APP_PATH"
```

The architecture output must contain exactly `arm64` and `x86_64`. The version must match the local tag, the signature and stapled ticket must validate, and Gatekeeper must accept the app.

## Create and notarize the DMG

Keep the variables from the previous command block in the same shell, then run:

```sh
set -euo pipefail
DIST_DIR="$PWD/dist"
STAGING_DIR="$(mktemp -d)"
DMG_PATH="$DIST_DIR/BandSteerer-$VERSION.dmg"
SIGNING_IDENTITY="$(codesign -dvv "$APP_PATH" 2>&1 | /usr/bin/sed -n 's/^Authority=\(Developer ID Application:.*\)$/\1/p' | /usr/bin/head -1)"

test -n "$SIGNING_IDENTITY"
/usr/bin/ditto "$APP_PATH" "$STAGING_DIR/BandSteerer.app"
/bin/ln -s /Applications "$STAGING_DIR/Applications"
/usr/bin/hdiutil create \
  -volname BandSteerer \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$DMG_PATH"
/bin/rm -R "$STAGING_DIR"

/usr/bin/codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"
/usr/bin/hdiutil verify "$DMG_PATH"

NOTARY_RESULT="$(mktemp)"
NOTARY_LOG="$(mktemp)"
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "BandSteerer-Notary" \
  --wait \
  --output-format json > "$NOTARY_RESULT"
test "$(/usr/bin/plutil -extract status raw -o - "$NOTARY_RESULT")" = Accepted
SUBMISSION_ID="$(/usr/bin/plutil -extract id raw -o - "$NOTARY_RESULT")"
xcrun notarytool log "$SUBMISSION_ID" \
  --keychain-profile "BandSteerer-Notary" \
  "$NOTARY_LOG"
/usr/bin/plutil -p "$NOTARY_LOG"
/bin/rm -f "$NOTARY_RESULT" "$NOTARY_LOG"

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"

cd "$DIST_DIR"
/usr/bin/shasum -a 256 "BandSteerer-$VERSION.dmg" > "BandSteerer-$VERSION.dmg.sha256"
```

Review the printed notarization log even when the submission is accepted. It should contain no issues.

## Verify the mounted distribution

Keep the same shell open and run:

```sh
set -euo pipefail
MOUNT_POINT="$(mktemp -d)"
/usr/bin/hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT_POINT" "$DMG_PATH"
MOUNTED_APP="$MOUNT_POINT/BandSteerer.app"
ENTITLEMENTS="$(mktemp)"

test -L "$MOUNT_POINT/Applications"
test "$(/usr/bin/readlink "$MOUNT_POINT/Applications")" = /Applications
lipo -archs "$MOUNTED_APP/Contents/MacOS/BandSteerer"
codesign --verify --deep --strict --verbose=2 "$MOUNTED_APP"
codesign -d --entitlements - "$MOUNTED_APP" > "$ENTITLEMENTS"
test "$(/usr/bin/grep -Fc 'com.apple.security.get-task-allow' "$ENTITLEMENTS" || true)" = 0
spctl --assess --type execute --verbose=2 "$MOUNTED_APP"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"

/usr/bin/hdiutil detach "$MOUNT_POINT"
/bin/rmdir "$MOUNT_POINT"
/bin/rm -f "$ENTITLEMENTS"
cd "$DIST_DIR"
/usr/bin/shasum -a 256 -c "BandSteerer-$VERSION.dmg.sha256"
```

The mounted executable must again contain exactly `arm64` and `x86_64`. The Applications shortcut, signature, entitlements, checksum, stapled ticket, and Gatekeeper assessments must all pass.

## Clean-machine validation

Test the exact DMG intended for publication on another Mac or in a clean user account with no earlier BandSteerer permissions or Keychain items. Test both architectures when practical.

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

1. Confirm the local tag resolves to the exact archived commit.
2. Push `main`, then push the annotated tag.
3. In GitHub's **Releases** page, draft a release for that existing tag and attach only `BandSteerer-<version>.dmg` and `BandSteerer-<version>.dmg.sha256`.
4. Generate release notes, review them for private data, and publish the release.
5. Download both published assets, run `shasum -a 256 -c BandSteerer-<version>.dmg.sha256`, and repeat the Gatekeeper check on the downloaded DMG.
6. Keep the previous release available for rollback until the new version has been exercised by real users.
