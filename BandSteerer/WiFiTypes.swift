import Foundation

enum WiFiBand: String, Equatable, Sendable {
  case twoPointFour = "2.4 GHz"
  case five = "5 GHz"
  case six = "6 GHz"
  case unknown = "Unknown"

  var shortName: String {
    switch self {
    case .twoPointFour: "2.4"
    case .five: "5"
    case .six: "6"
    case .unknown: "?"
    }
  }
}

enum BandPreference: String, CaseIterable, Identifiable, Sendable {
  case automatic
  case twoPointFour
  case five

  var id: Self { self }

  var title: String {
    switch self {
    case .automatic: "Automatic"
    case .twoPointFour: "2.4 GHz"
    case .five: "5 GHz"
    }
  }

  var band: WiFiBand? {
    switch self {
    case .automatic: nil
    case .twoPointFour: .twoPointFour
    case .five: .five
    }
  }
}

enum PreferenceRestorationPolicy {
  static func effectivePreference(
    savedPreference: BandPreference,
    canApplyWithoutUserInteraction: Bool
  ) -> BandPreference {
    if savedPreference == .automatic || canApplyWithoutUserInteraction {
      return savedPreference
    }
    return .automatic
  }
}

struct WiFiConnection: Equatable, Sendable {
  var ssid: String?
  var band: WiFiBand = .unknown
  var channel: Int?
  var rssi: Int?
  var isPoweredOn = false
  var isInterfaceAvailable = false

  static let disconnected = WiFiConnection()

  var isConnected: Bool { ssid != nil }
}

struct MenuBarPresentation: Equatable {
  let systemImage: String
  let bandText: String?
  let accessibilityLabel: LocalizedStringResource

  init(
    isLocationAuthorized: Bool,
    connection: WiFiConnection,
    preference: BandPreference,
    isWorking: Bool,
    isRecoveringFromWake: Bool
  ) {
    let activeBandText = preference == .automatic ? nil : preference.title

    if !isLocationAuthorized {
      systemImage = "wifi.slash"
      bandText = nil
      accessibilityLabel = "BandSteerer needs Location access"
    } else if !connection.isInterfaceAvailable {
      systemImage = "wifi.slash"
      bandText = nil
      accessibilityLabel = "BandSteerer cannot read the Wi-Fi interface"
    } else if !connection.isPoweredOn {
      systemImage = "wifi.slash"
      bandText = nil
      accessibilityLabel = "Wi-Fi is off"
    } else if !connection.isConnected {
      systemImage = "wifi.slash"
      bandText = nil
      accessibilityLabel = "Wi-Fi is not connected"
    } else if preference == .automatic {
      systemImage = "wifi"
      bandText = nil
      accessibilityLabel = "BandSteerer is using Automatic mode"
    } else if isRecoveringFromWake {
      systemImage = "wifi.exclamationmark"
      bandText = activeBandText
      accessibilityLabel = "BandSteerer is checking Wi-Fi after wake"
    } else if isWorking || preference.band != connection.band {
      systemImage = "wifi.exclamationmark"
      bandText = activeBandText
      accessibilityLabel = "BandSteerer is restoring the \(preference.title) preference"
    } else {
      systemImage = "wifi"
      bandText = activeBandText
      accessibilityLabel = "BandSteerer has the \(preference.title) preference active"
    }
  }
}

struct NetworkCandidate: Equatable, Sendable {
  let identifier: String
  let band: WiFiBand
  let rssi: Int
}

enum BandSelection {
  static func bestCandidate(
    for band: WiFiBand,
    among candidates: [NetworkCandidate]
  ) -> NetworkCandidate? {
    candidates
      .filter { $0.band == band }
      .max { lhs, rhs in
        if lhs.rssi == rhs.rssi {
          lhs.identifier > rhs.identifier
        } else {
          lhs.rssi < rhs.rssi
        }
      }
  }
}

enum CorrectionPolicy {
  static func retryDelay(afterConsecutiveFailures failureCount: Int) -> TimeInterval {
    let delays: [TimeInterval] = [15, 30, 60, 120]
    let index = min(max(failureCount, 1) - 1, delays.count - 1)
    return delays[index]
  }
}

enum MenuMessagePolicy {
  static let expirationInterval: TimeInterval = 60

  static func isExpired(shownAt: Date, now: Date) -> Bool {
    now.timeIntervalSince(shownAt) >= expirationInterval
  }
}

enum WakeRecoveryPolicy {
  // Wi-Fi usually returns within a few seconds after wake. These bounded checks
  // tolerate a slower reconnect without leaving a permanent polling task behind.
  static let retryDelays: [TimeInterval] = [1, 2, 3, 5, 8, 13]

  static func shouldCommit(
    _ connection: WiFiConnection,
    afterAttempt attempt: Int
  ) -> Bool {
    connection.isConnected || attempt >= retryDelays.count - 1
  }
}

struct SessionPolicy: Equatable, Sendable {
  private(set) var ssid: String?
  private(set) var preference: BandPreference = .automatic

  mutating func observe(
    ssid newSSID: String?,
    savedPreference: BandPreference = .automatic
  ) {
    guard newSSID != ssid else { return }
    ssid = newSSID
    preference = newSSID == nil ? .automatic : savedPreference
  }

  mutating func select(_ newPreference: BandPreference) {
    guard ssid != nil else {
      preference = .automatic
      return
    }
    preference = newPreference
  }

  func needsCorrection(for currentBand: WiFiBand) -> Bool {
    guard let desiredBand = preference.band else { return false }
    return currentBand != desiredBand
  }
}
