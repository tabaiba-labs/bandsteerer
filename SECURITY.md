# Security policy

Security fixes are provided for the latest released version of BandSteerer.

## Reporting a vulnerability

Use [GitHub private vulnerability reporting](https://github.com/tabaiba-labs/bandsteerer/security/advisories/new). Include the affected version, macOS version and architecture, impact, reproduction steps, and any minimal proof of concept needed to verify the issue.

Do not put credentials, Wi-Fi identifiers, Keychain exports, crash reports containing personal paths, or exploit details in a public issue.

## Security boundaries

BandSteerer handles Wi-Fi credentials only through Apple Keychain APIs, uses public CoreWLAN APIs, and runs inside the App Sandbox. The app has no privileged helper, remote service, or plug-in system. Updates use Sparkle's sandboxed installer service and must pass EdDSA signature validation. A valid report may concern credential access, sandbox entitlements, update or code-signing integrity, unsafe logging, or behavior that connects to an unintended access point.

Official binary releases are signed and notarized for macOS Gatekeeper.
