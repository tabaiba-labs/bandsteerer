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

  var shortTitle: String {
    switch self {
    case .automatic: "Auto"
    case .twoPointFour: "2.4"
    case .five: "5"
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

struct WiFiConnection: Equatable, Sendable {
  var ssid: String?
  var band: WiFiBand = .unknown
  var channel: Int?
  var rssi: Int?
  var transmitRate: Double?
  var isPoweredOn = false
  var isInterfaceAvailable = false

  static let disconnected = WiFiConnection()

  var isConnected: Bool { ssid != nil }
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
