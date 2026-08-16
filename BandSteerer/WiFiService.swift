@preconcurrency import CoreWLAN
import Foundation
import OSLog

enum WiFiServiceError: LocalizedError {
  case noInterface
  case notConnected
  case noNetworkInBand(WiFiBand)
  case credentialsUnavailable
  case enterpriseUnsupported
  case verificationFailed(WiFiBand)

  var errorDescription: String? {
    switch self {
    case .noInterface:
      "No Wi-Fi interface is available."
    case .notConnected:
      "Connect to Wi-Fi first."
    case .noNetworkInBand(let band):
      "\(band.rawValue) isn't visible yet. BandSteerer will keep watching."
    case .credentialsUnavailable:
      "The saved Wi-Fi password couldn't be accessed. Choose the band again to retry."
    case .enterpriseUnsupported:
      "Enterprise Wi-Fi can't be steered with the public macOS APIs."
    case .verificationFailed(let band):
      "macOS moved away from \(band.rawValue). BandSteerer will keep watching."
    }
  }

  var isTransientAssociationFailure: Bool {
    switch self {
    case .noNetworkInBand, .verificationFailed:
      true
    default:
      false
    }
  }

  var keepsPreferenceActive: Bool {
    isTransientAssociationFailure
  }
}

final class WiFiService: @unchecked Sendable {
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

  func associate(
    with band: WiFiBand,
    allowSystemKeychainAccess: Bool
  ) async throws -> WiFiConnection {
    let retryDelays: [Duration] = [.milliseconds(750), .milliseconds(1_500)]

    for attempt in 0...retryDelays.count {
      try Task.checkCancellation()
      do {
        return try await associateOnce(
          with: band,
          allowSystemKeychainAccess: allowSystemKeychainAccess
        )
      } catch let error as WiFiServiceError {
        guard attempt < retryDelays.count, error.isTransientAssociationFailure else {
          throw error
        }
        try await Task.sleep(for: retryDelays[attempt], tolerance: .milliseconds(150))
      }
    }

    throw WiFiServiceError.noNetworkInBand(band)
  }

  func clearCachedPasswords() async {
    await withCheckedContinuation { continuation in
      operationQueue.async { [weak self] in
        self?.cachedPasswords.removeAll()
        continuation.resume()
      }
    }
  }

  private func associateOnce(
    with band: WiFiBand,
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

          if Self.band(for: interface.wlanChannel()) == band {
            if let password {
              credentialStore.save(password: password, for: ssidData)
            }
            continuation.resume(returning: Self.connection(from: interface))
            return
          }

          let candidates = try interface.scanForNetworks(withSSID: ssidData).compactMap {
            network -> (network: CWNetwork, candidate: NetworkCandidate)? in
            let networkBand = Self.band(for: network.wlanChannel)
            guard networkBand == band else { return nil }
            return (
              network,
              NetworkCandidate(
                identifier: network.bssid ?? "",
                band: networkBand,
                rssi: network.rssiValue
              )
            )
          }
          guard
            let selected = BandSelection.bestCandidate(
              for: band,
              among: candidates.map(\.candidate)
            ),
            let target = candidates.first(where: { $0.candidate == selected })?.network
          else {
            throw WiFiServiceError.noNetworkInBand(band)
          }

          do {
            try interface.associate(to: target, password: password)
          } catch {
            cachedPasswords[ssidData] = nil
            credentialStore.removePassword(for: ssidData)
            throw error
          }

          let connection = Self.connection(from: interface)
          guard connection.band == band else {
            throw WiFiServiceError.verificationFailed(band)
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
      transmitRate: ssid == nil ? nil : interface.transmitRate(),
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

  private func password(
    for ssidData: Data,
    security: CWSecurity,
    allowSystemKeychainAccess: Bool
  ) throws -> String? {
    if security == .none || security == .OWE || security == .oweTransition {
      return nil
    }
    if security == .dynamicWEP || security == .wpaEnterprise || security == .wpaEnterpriseMixed
      || security == .wpa2Enterprise || security == .enterprise || security == .wpa3Enterprise
    {
      throw WiFiServiceError.enterpriseUnsupported
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
