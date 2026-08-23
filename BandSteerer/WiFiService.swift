@preconcurrency import CoreWLAN
import Foundation
import OSLog

enum WiFiServiceError: LocalizedError {
  case noInterface
  case notConnected
  case noFiveGHzNetwork
  case credentialsUnavailable
  case enterpriseUnsupported
  case verificationFailed

  var errorDescription: String? {
    switch self {
    case .noInterface:
      "No Wi-Fi interface is available."
    case .notConnected:
      "Connect to Wi-Fi first."
    case .noFiveGHzNetwork:
      "5 GHz isn't visible yet. BandSteerer will keep watching."
    case .credentialsUnavailable:
      "The saved Wi-Fi password couldn't be accessed. Turn Prefer 5 GHz on again to retry."
    case .enterpriseUnsupported:
      "Enterprise Wi-Fi can't be steered with the public macOS APIs."
    case .verificationFailed:
      "macOS moved away from 5 GHz. BandSteerer will keep watching."
    }
  }

  var isTransientAssociationFailure: Bool {
    switch self {
    case .noFiveGHzNetwork, .verificationFailed:
      true
    default:
      false
    }
  }

  var keepsPreferenceActive: Bool {
    isTransientAssociationFailure
  }
}

enum AssociationFailurePolicy {
  static func keepsPreferenceActive(after error: Error) -> Bool {
    (error as? WiFiServiceError)?.keepsPreferenceActive == true
  }
}

final class WiFiService: @unchecked Sendable {
  private enum CredentialRequirement {
    case none
    case password
    case unsupported
  }

  private static let logger = Logger(
    subsystem: AppIdentity.bundleIdentifier,
    category: "WiFi"
  )

  private let client: CWWiFiClient
  private let credentialStore: CredentialStore
  private var cachedPasswords: [Data: String] = [:]
  private let operationQueue = DispatchQueue(
    label: "\(AppIdentity.bundleIdentifier).wifi",
    qos: .userInitiated
  )

  init() {
    client = CWWiFiClient.shared()
    credentialStore = CredentialStore()
  }

  func readConnection() async -> WiFiConnection {
    await withCheckedContinuation { continuation in
      operationQueue.async { [client] in
        continuation.resume(returning: Self.connection(from: Self.currentInterface(client)))
      }
    }
  }

  func associateWithFiveGHz(allowSystemKeychainAccess: Bool) async throws -> WiFiConnection {
    let retryDelays: [Duration] = [.milliseconds(750), .milliseconds(1_500)]

    for attempt in 0...retryDelays.count {
      try Task.checkCancellation()
      do {
        return try await associateOnceWithFiveGHz(
          allowSystemKeychainAccess: allowSystemKeychainAccess
        )
      } catch let error as WiFiServiceError {
        guard attempt < retryDelays.count, error.isTransientAssociationFailure else {
          throw error
        }
        try await Task.sleep(for: retryDelays[attempt], tolerance: .milliseconds(150))
      }
    }

    throw WiFiServiceError.noFiveGHzNetwork
  }

  func clearCachedPasswords() async {
    await withCheckedContinuation { continuation in
      operationQueue.async { [weak self] in
        self?.cachedPasswords.removeAll()
        continuation.resume()
      }
    }
  }

  func canApplySavedPreferenceWithoutUserInteraction(for ssid: String) async -> Bool {
    await withCheckedContinuation { continuation in
      operationQueue.async { [self] in
        guard
          let interface = Self.currentInterface(client),
          let configuration = interface.configuration(),
          !configuration.requireAdministratorForAssociation,
          interface.ssid() == ssid,
          let ssidData = interface.ssidData()
        else {
          continuation.resume(returning: false)
          return
        }

        let canApply =
          switch Self.credentialRequirement(for: interface.security()) {
          case .none:
            true
          case .password:
            credentialStore.password(for: ssidData) != nil
          case .unsupported:
            false
          }
        continuation.resume(returning: canApply)
      }
    }
  }

  private func associateOnceWithFiveGHz(
    allowSystemKeychainAccess: Bool
  ) async throws -> WiFiConnection {
    try await withCheckedThrowingContinuation { continuation in
      operationQueue.async { [self] in
        do {
          let interface = Self.currentInterface(client)
          guard let interface else { throw WiFiServiceError.noInterface }
          guard let ssidData = interface.ssidData(), interface.ssid() != nil else {
            throw WiFiServiceError.notConnected
          }

          let password = try password(
            for: ssidData,
            security: interface.security(),
            allowSystemKeychainAccess: allowSystemKeychainAccess
          )

          let requiresAdministrator =
            interface.configuration()?.requireAdministratorForAssociation ?? true
          if Self.band(for: interface.wlanChannel()) == .five, !requiresAdministrator {
            if let password {
              credentialStore.save(password: password, for: ssidData)
            }
            continuation.resume(returning: Self.connection(from: interface))
            return
          }

          let candidates = try interface.scanForNetworks(withSSID: ssidData).compactMap {
            network -> (network: CWNetwork, candidate: NetworkCandidate)? in
            let networkBand = Self.band(for: network.wlanChannel)
            guard networkBand == .five else { return nil }
            return (
              network,
              NetworkCandidate(
                identifier: network.bssid ?? "",
                rssi: network.rssiValue
              )
            )
          }
          guard
            let selected = FiveGHzSelection.strongestCandidate(
              among: candidates.map(\.candidate)
            ),
            let target = candidates.first(where: { $0.candidate == selected })?.network
          else {
            throw WiFiServiceError.noFiveGHzNetwork
          }

          do {
            try interface.associate(to: target, password: password)
          } catch {
            cachedPasswords[ssidData] = nil
            credentialStore.removePassword(for: ssidData)
            throw error
          }

          let connection = Self.connection(from: interface)
          guard connection.band == .five else {
            throw WiFiServiceError.verificationFailed
          }
          if let password {
            credentialStore.save(password: password, for: ssidData)
          }
          continuation.resume(returning: connection)
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private static func connection(from interface: CWInterface?) -> WiFiConnection {
    guard let interface else {
      logger.error("CoreWLAN did not vend a Wi-Fi interface")
      return .disconnected
    }
    let ssid = interface.ssid()
    let channel = interface.wlanChannel()
    logger.info(
      "CoreWLAN interface available; powered=\(interface.powerOn(), privacy: .public), ssidVisible=\(ssid != nil, privacy: .public), channel=\(channel?.channelNumber ?? 0, privacy: .public)"
    )
    return WiFiConnection(
      ssid: ssid,
      band: ssid == nil ? .unknown : band(for: channel),
      channel: ssid == nil ? nil : channel?.channelNumber,
      rssi: ssid == nil ? nil : interface.rssiValue(),
      isPoweredOn: interface.powerOn(),
      isInterfaceAvailable: true
    )
  }

  private static func currentInterface(_ client: CWWiFiClient) -> CWInterface? {
    if let primaryInterface = client.interface() {
      return primaryInterface
    }

    let interfaces = client.interfaces() ?? []
    return interfaces.first(where: { $0.powerOn() }) ?? interfaces.first
  }

  private static func band(for channel: CWChannel?) -> WiFiBand {
    guard let channel else { return .unknown }
    switch channel.channelBand {
    case .band2GHz:
      return .twoPointFour
    case .band5GHz:
      return .five
    case .band6GHz:
      return .six
    default:
      return .unknown
    }
  }

  private static func credentialRequirement(for security: CWSecurity) -> CredentialRequirement {
    if security == .none || security == .OWE || security == .oweTransition {
      return .none
    }
    if security == .dynamicWEP || security == .wpaEnterprise || security == .wpaEnterpriseMixed
      || security == .wpa2Enterprise || security == .enterprise || security == .wpa3Enterprise
    {
      return .unsupported
    }
    return .password
  }

  private func password(
    for ssidData: Data,
    security: CWSecurity,
    allowSystemKeychainAccess: Bool
  ) throws -> String? {
    switch Self.credentialRequirement(for: security) {
    case .none:
      return nil
    case .unsupported:
      throw WiFiServiceError.enterpriseUnsupported
    case .password:
      break
    }

    if let cachedPassword = cachedPasswords[ssidData] {
      return cachedPassword
    }

    if let storedPassword = credentialStore.password(for: ssidData) {
      cachedPasswords[ssidData] = storedPassword
      return storedPassword
    }

    guard allowSystemKeychainAccess else {
      throw WiFiServiceError.credentialsUnavailable
    }

    var password: NSString?
    var status = CWKeychainFindWiFiPassword(.user, ssidData, &password)
    if status != errSecSuccess {
      status = CWKeychainFindWiFiPassword(.system, ssidData, &password)
    }
    guard status == errSecSuccess, let password else {
      throw WiFiServiceError.credentialsUnavailable
    }
    let value = password as String
    cachedPasswords[ssidData] = value
    return value
  }

}
