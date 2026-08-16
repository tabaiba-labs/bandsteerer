import CryptoKit
import Foundation

struct BandPreferenceStore {
  static let storageKey = "bandPreferencesByNetwork"

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func preference(for ssid: String) -> BandPreference {
    guard let rawValue = preferences[Self.networkIdentifier(for: ssid)] else {
      return .automatic
    }
    return BandPreference(rawValue: rawValue) ?? .automatic
  }

  func set(_ preference: BandPreference, for ssid: String) {
    var preferences = preferences
    let identifier = Self.networkIdentifier(for: ssid)

    if preference == .automatic {
      preferences.removeValue(forKey: identifier)
    } else {
      preferences[identifier] = preference.rawValue
    }
    defaults.set(preferences, forKey: Self.storageKey)
  }

  static func networkIdentifier(for ssid: String) -> String {
    Data(SHA256.hash(data: Data(ssid.utf8))).base64EncodedString()
  }

  private var preferences: [String: String] {
    defaults.dictionary(forKey: Self.storageKey)?.compactMapValues { $0 as? String } ?? [:]
  }
}
