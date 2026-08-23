import CryptoKit
import Foundation

struct FiveGHzPreferenceStore {
  static let storageKey = "bandPreferencesByNetwork"
  private static let enabledValue = "five"

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func isEnabled(for ssid: String) -> Bool {
    let identifier = Self.networkIdentifier(for: ssid)
    guard let value = preferences[identifier] else { return false }
    guard value == Self.enabledValue else {
      setEnabled(false, for: ssid)
      return false
    }
    return true
  }

  func setEnabled(_ enabled: Bool, for ssid: String) {
    var preferences = preferences
    let identifier = Self.networkIdentifier(for: ssid)

    if enabled {
      preferences[identifier] = Self.enabledValue
    } else {
      preferences.removeValue(forKey: identifier)
    }

    if preferences.isEmpty {
      defaults.removeObject(forKey: Self.storageKey)
    } else {
      defaults.set(preferences, forKey: Self.storageKey)
    }
  }

  func removeAll() {
    defaults.removeObject(forKey: Self.storageKey)
  }

  static func networkIdentifier(for ssid: String) -> String {
    Data(SHA256.hash(data: Data(ssid.utf8))).base64EncodedString()
  }

  private var preferences: [String: String] {
    defaults.dictionary(forKey: Self.storageKey)?.compactMapValues { $0 as? String } ?? [:]
  }
}
