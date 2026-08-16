import Foundation
import OSLog
import Security

final class CredentialStore: @unchecked Sendable {
  private static let logger = Logger(
    subsystem: AppIdentity.bundleIdentifier,
    category: "Credentials"
  )
  private static let service = AppIdentity.keychainService

  func password(for ssidData: Data) -> String? {
    var result: CFTypeRef?
    let status = SecItemCopyMatching(
      query(for: ssidData, returningData: true) as CFDictionary,
      &result
    )

    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess,
      let data = result as? Data,
      let password = String(data: data, encoding: .utf8)
    else {
      Self.logger.error("Could not read app credential; status=\(status, privacy: .public)")
      return nil
    }
    return password
  }

  func save(password: String, for ssidData: Data) {
    let passwordData = Data(password.utf8)
    let query = query(for: ssidData)
    let updateStatus = SecItemUpdate(
      query as CFDictionary,
      [kSecValueData as String: passwordData] as CFDictionary
    )

    if updateStatus == errSecSuccess {
      return
    }
    guard updateStatus == errSecItemNotFound else {
      Self.logger.error(
        "Could not update app credential; status=\(updateStatus, privacy: .public)")
      return
    }

    var item = query
    item[kSecValueData as String] = passwordData
    item[kSecAttrLabel as String] = "BandSteerer Wi-Fi credential"
    item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    let addStatus = SecItemAdd(item as CFDictionary, nil)
    if addStatus != errSecSuccess && addStatus != errSecDuplicateItem {
      Self.logger.error("Could not save app credential; status=\(addStatus, privacy: .public)")
    }
  }

  func removePassword(for ssidData: Data) {
    let status = SecItemDelete(query(for: ssidData) as CFDictionary)
    if status != errSecSuccess && status != errSecItemNotFound {
      Self.logger.error("Could not remove app credential; status=\(status, privacy: .public)")
    }
  }

  private func query(for ssidData: Data, returningData: Bool = false) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: ssidData.base64EncodedString(),
    ]
    if returningData {
      query[kSecReturnData as String] = true
      query[kSecMatchLimit as String] = kSecMatchLimitOne
    }
    return query
  }
}
