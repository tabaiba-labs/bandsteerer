# Privacy

BandSteerer performs its Wi-Fi work locally. It contains no analytics SDK, advertising SDK, crash-reporting service, or telemetry endpoint. Its only application-level internet access is the update flow described below.

## Data used while the app is running

BandSteerer reads these values from Apple’s CoreWLAN framework:

- the current Wi-Fi interface power and connection state;
- the current SSID, channel, signal strength, and negotiated transmit rate;
- scan results for the current SSID, including BSSID, band, and signal strength, when a band switch is necessary.

The current SSID and radio details are held in memory and shown in the menu. Scan-result BSSIDs are used transiently to rank access points and are not retained in application state.

When the user selects an explicit band, BandSteerer stores the band and a SHA-256 identifier derived from the SSID in the app's standard local `UserDefaults`. This lets the preference survive app launches and Mac reboots without storing the plaintext SSID. Choosing Automatic removes that network's entry. These identifiers and preferences are not written to logs or sent to a network service.

BandSteerer creates a `CLLocationManager` only to request and observe authorization. It does not start location updates, request a location, or receive geographic coordinates. macOS requires the permission before CoreWLAN reveals SSID and BSSID information.

## Wi-Fi credentials

When the user manually chooses a band on a password-protected personal network, BandSteerer may ask CoreWLAN to read that network’s existing password from the macOS user or system Keychain. macOS controls any authorization prompt.

After a successful association, BandSteerer saves a copy as a generic-password item in the user’s login Keychain:

- the item service is the running app’s bundle identifier followed by `.WiFi`;
- the account key is a base64 representation of the SSID bytes rather than a plaintext SSID;
- the item is marked `WhenUnlockedThisDeviceOnly`, so it is available only while the Keychain is unlocked and does not migrate to another device;
- the password is cached in process memory only for the current SSID.

The copy allows background corrections to reconnect without repeated authorization prompts. BandSteerer does not write it to app preferences, logs, or cloud storage.

Uninstalling a macOS app does not automatically delete its Keychain items. To remove BandSteerer’s copies, open **Keychain Access**, search for **BandSteerer Wi-Fi credential**, and delete the matching generic-password items. This does not delete the Wi-Fi passwords maintained by macOS for joining those networks.

## Logs

BandSteerer uses Apple unified logging for lifecycle and failure diagnostics. Log messages can contain Keychain status codes, interface power state, whether an SSID was visible, the numeric Wi-Fi channel, and whether wake recovery returned to the same session. They do not contain SSIDs, BSSIDs, passwords, geographic coordinates, or scan results.

## Network access and sandboxing

The application has the App Sandbox, outgoing network-client, Location, and Sparkle installer communication entitlements. CoreWLAN communicates with macOS system services through the sandbox.

At launch and no more than once every 24 hours while running, Sparkle requests the public update feed from `raw.githubusercontent.com`. If an update is available and the user accepts it, Sparkle downloads the signed release archive from the URL in that feed, currently a GitHub Release. These requests necessarily expose normal network metadata such as the device's public IP address to GitHub. BandSteerer does not add an account identifier, Wi-Fi data, credential, or analytics event to the request, and Sparkle's optional system profiling is explicitly disabled.

Sparkle verifies release archives with BandSteerer's EdDSA public key before installing them. The private signing key is not included in the app or repository.
