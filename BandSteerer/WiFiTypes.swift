import Foundation

enum WiFiBand: String, Equatable, Sendable {
  case twoPointFour = "2.4 GHz"
  case five = "5 GHz"
  case six = "6 GHz"
  case unknown = "Unknown"
}

enum PreferenceRestorationPolicy {
  static func shouldEnableFiveGHz(
    savedPreferenceEnabled: Bool,
    canApplyWithoutUserInteraction: Bool
  ) -> Bool {
    savedPreferenceEnabled && canApplyWithoutUserInteraction
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
  let iconAssetName: String
  let accessibilityLabel: LocalizedStringResource

  init(
    isLocationAuthorized: Bool,
    connection: WiFiConnection,
    prefersFiveGHz: Bool,
    isWorking: Bool,
    isRecoveringFromWake: Bool
  ) {
    let canShowActivePreference =
      isLocationAuthorized && connection.isInterfaceAvailable && connection.isPoweredOn
      && connection.isConnected
    iconAssetName =
      canShowActivePreference && prefersFiveGHz ? "MenuBarIconOn" : "MenuBarIconOff"

    if !isLocationAuthorized {
      accessibilityLabel = "BandSteerer needs Location access"
    } else if !connection.isInterfaceAvailable {
      accessibilityLabel = "BandSteerer cannot read the Wi-Fi interface"
    } else if !connection.isPoweredOn {
      accessibilityLabel = "Wi-Fi is off"
    } else if !connection.isConnected {
      accessibilityLabel = "Wi-Fi is not connected"
    } else if !prefersFiveGHz {
      accessibilityLabel = "BandSteerer is using automatic Wi-Fi selection"
    } else if isRecoveringFromWake {
      accessibilityLabel = "BandSteerer is checking Wi-Fi after wake"
    } else if isWorking || connection.band != .five {
      accessibilityLabel = "BandSteerer is restoring the 5 GHz preference"
    } else {
      accessibilityLabel = "BandSteerer has the 5 GHz preference active"
    }
  }
}

struct NetworkCandidate: Equatable, Sendable {
  let identifier: String
  let rssi: Int
}

enum FiveGHzSelection {
  static func strongestCandidate(among candidates: [NetworkCandidate]) -> NetworkCandidate? {
    candidates
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
  private(set) var prefersFiveGHz = false

  mutating func observe(
    ssid newSSID: String?,
    savedPreferenceEnabled: Bool = false
  ) {
    guard newSSID != ssid else { return }
    ssid = newSSID
    prefersFiveGHz = newSSID != nil && savedPreferenceEnabled
  }

  mutating func setFiveGHzPreference(_ enabled: Bool) {
    prefersFiveGHz = ssid != nil && enabled
  }

  func needsCorrection(for currentBand: WiFiBand) -> Bool {
    prefersFiveGHz && currentBand != .five
  }
}
