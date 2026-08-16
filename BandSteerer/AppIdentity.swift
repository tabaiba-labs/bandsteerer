import Foundation

enum AppIdentity {
  static let fallbackBundleIdentifier = "org.bandsteerer.BandSteerer"
  static let bundleIdentifier = Bundle.main.bundleIdentifier ?? fallbackBundleIdentifier
  static let keychainService = "\(bundleIdentifier).WiFi"
}
