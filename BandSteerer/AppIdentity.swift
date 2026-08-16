import Foundation

enum AppIdentity {
  static let fallbackBundleIdentifier = "org.bandsteerer.BandSteerer"
  static let bundleIdentifier = Bundle.main.bundleIdentifier ?? fallbackBundleIdentifier
  static let keychainService = "\(bundleIdentifier).WiFi"
}

struct AppBuildInfo: Equatable {
  let version: String
  let build: String

  init(infoDictionary: [String: Any]) {
    version = Self.value(for: "CFBundleShortVersionString", in: infoDictionary)
    build = Self.value(for: "CFBundleVersion", in: infoDictionary)
  }

  static var current: AppBuildInfo {
    AppBuildInfo(infoDictionary: Bundle.main.infoDictionary ?? [:])
  }

  var displayText: String {
    "Version \(version) (Build \(build))"
  }

  private static func value(for key: String, in infoDictionary: [String: Any]) -> String {
    guard let value = infoDictionary[key] as? String, !value.isEmpty else { return "Unknown" }
    return value
  }
}
