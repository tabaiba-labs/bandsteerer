# Publishing updates

BandSteerer uses Sparkle 2.9.4. The app checks the static `appcast.xml` feed once at process launch and then on Sparkle's 24-hour schedule. A manual **Check for Updates…** action is also available in the menu. Downloads and installation use Sparkle's standard user interface.

## Trust model

- `BandSteerer/Info.plist` contains the public EdDSA key used to verify update archives.
- The matching private key lives in the maintainer's macOS login Keychain under the Sparkle account `tabaiba-labs.bandsteerer`. It must never enter this repository.
- Official app bundles and disk images must also be signed with Developer ID and notarized.
- `appcast.xml` is served over HTTPS from the repository's `main` branch. Its enclosure URLs point to immutable GitHub Release assets.

Back up the private key to secure offline storage before the first public update. Sparkle's official tool exports it without printing it:

```sh
generate_keys --account tabaiba-labs.bandsteerer -x /secure/offline/location/bandsteerer-sparkle-private-key
```

Never use a repository path or shared cloud folder for that export.

## Release checklist

1. Update `MARKETING_VERSION` and increment `CURRENT_PROJECT_VERSION` in both target build configurations. Build numbers must never be reused.
2. Run the complete test, analyze, universal Release build, signing, and notarization checks.
3. Export the Developer ID-signed `BandSteerer.app` and create the drag-and-drop disk image. The script creates an APFS/LZFSE DMG containing the app and an `Applications` shortcut:

   ```sh
   scripts/create-dmg.sh VERSION /path/to/BandSteerer.app /path/to/release-directory
   ```

4. Sign the DMG with the same Developer ID identity, submit it to Apple's notary service, wait for acceptance, and staple the ticket to the DMG:

   ```sh
   codesign --force --timestamp --sign "Developer ID Application: YOUR NAME (TEAMID)" \
     /path/to/BandSteerer-VERSION.dmg
   xcrun notarytool submit /path/to/BandSteerer-VERSION.dmg \
     --keychain-profile YOUR_NOTARY_PROFILE --wait
   xcrun stapler staple /path/to/BandSteerer-VERSION.dmg
   xcrun stapler validate /path/to/BandSteerer-VERSION.dmg
   ```

5. Download the matching Sparkle 2.9.4 distribution from the official Sparkle release. Generate the signed appcast entry from the final stapled DMG at the repository root:

   ```sh
   scripts/generate-appcast.sh \
     /path/to/Sparkle-2.9.4/bin/generate_appcast \
     VERSION \
     /path/to/BandSteerer-VERSION.dmg
   ```

6. Create and publish GitHub Release `vVERSION`, uploading the exact DMG passed to the script. This is both the user-facing drag-and-drop installer and Sparkle's update archive. Do not modify or replace it after generating the appcast signature.
7. Verify the published asset URL works, review the generated `appcast.xml` diff, and merge that file to `main`.
8. From a genuinely older updater-enabled signed installation, select **Check for Updates…**, complete the install and relaunch, then verify the installed version, bundle signature, and notarization ticket.

Publishing the release asset before the appcast is safe: existing users keep seeing the previous feed until the signed entry reaches `main`. Publishing the appcast first is unsafe because it can advertise a missing DMG.

## Local checks

```sh
xmllint --noout appcast.xml
curl --fail --location https://raw.githubusercontent.com/tabaiba-labs/bandsteerer/main/appcast.xml
```

Sparkle compares `CFBundleVersion`, not only the marketing version. If a new release is not offered, first confirm its build number is strictly greater than the installed build and that the appcast enclosure has a valid `sparkle:edSignature`.
