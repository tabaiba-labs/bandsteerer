# Security policy

Security fixes are provided for the latest released version of BandSteerer.

## Reporting a vulnerability

Use the repository host’s private vulnerability-reporting feature when it is enabled. Include the affected version, macOS version and architecture, impact, reproduction steps, and any minimal proof of concept needed to verify the issue.

Do not put credentials, Wi-Fi identifiers, Keychain exports, crash reports containing personal paths, or exploit details in a public issue. If private reporting is not enabled, open a public issue containing no sensitive details and ask the maintainers to establish a private channel.

## Security boundaries

BandSteerer handles Wi-Fi credentials only through Apple Keychain APIs, uses public CoreWLAN APIs, and runs inside the App Sandbox. The app has no privileged helper, remote service, plug-in system, or update mechanism. A valid report may still concern credential access, sandbox entitlements, code signing, release integrity, unsafe logging, or behavior that connects to an unintended access point.

Official binary releases are signed and notarized for macOS Gatekeeper.
