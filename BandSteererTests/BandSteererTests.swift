import Foundation
import Testing

@testable import BandSteerer

struct BandSteererTests {
  @Test
  func checksForUpdatesOnLaunchWhenAutomaticChecksAreEnabled() {
    #expect(UpdateCheckPolicy.shouldCheckOnLaunch(automaticChecksEnabled: true))
  }

  @Test
  func respectsDisabledAutomaticChecksOnLaunch() {
    #expect(!UpdateCheckPolicy.shouldCheckOnLaunch(automaticChecksEnabled: false))
  }

  @Test
  func updaterIsConfiguredForDailyChecks() throws {
    let infoDictionary = try #require(Bundle.main.infoDictionary)

    #expect(infoDictionary["SUEnableAutomaticChecks"] as? Bool == true)
    #expect(infoDictionary["SUEnableSystemProfiling"] as? Bool == false)
    #expect(infoDictionary["SUScheduledCheckInterval"] as? Int == 86_400)
    #expect(
      infoDictionary["SUFeedURL"] as? String
        == "https://raw.githubusercontent.com/tabaiba-labs/bandsteerer/main/appcast.xml"
    )
  }

  @Test
  func formatsCurrentVersionAndBuild() {
    let buildInfo = AppBuildInfo(
      infoDictionary: [
        "CFBundleShortVersionString": "0.2.1",
        "CFBundleVersion": "7",
      ]
    )

    #expect(buildInfo.displayText == "Version 0.2.1 (Build 7)")
  }

  @Test
  func missingBuildMetadataHasAnExplicitFallback() {
    let buildInfo = AppBuildInfo(infoDictionary: [:])

    #expect(buildInfo.displayText == "Version Unknown (Build Unknown)")
  }

  @Test
  func locationPermissionMenuCopyUsesCompactNativeMenuRows() {
    let variants = [
      LocationPermissionMenuCopy.undetermined,
      LocationPermissionMenuCopy.restricted,
      LocationPermissionMenuCopy.denied,
    ]
    let localizedLines = variants.map { lines in
      lines.map { String(localized: $0) }
    }

    #expect(localizedLines.allSatisfy { $0.count == 2 })
    #expect(localizedLines.flatMap { $0 }.allSatisfy { $0.count <= 55 })
  }

  @Test
  func choosesStrongestCandidateInRequestedBand() {
    let candidates = [
      NetworkCandidate(identifier: "2g", band: .twoPointFour, rssi: -30),
      NetworkCandidate(identifier: "5g-weak", band: .five, rssi: -70),
      NetworkCandidate(identifier: "5g-strong", band: .five, rssi: -54),
    ]

    let selected = BandSelection.bestCandidate(for: .five, among: candidates)

    #expect(selected?.identifier == "5g-strong")
  }

  @Test
  func returnsNilWhenRequestedBandIsUnavailable() {
    let candidates = [
      NetworkCandidate(identifier: "2g", band: .twoPointFour, rssi: -30)
    ]

    #expect(BandSelection.bestCandidate(for: .five, among: candidates) == nil)
  }

  @Test
  func onlyTransientAssociationFailuresKeepPreferenceActive() {
    #expect(
      AssociationFailurePolicy.keepsPreferenceActive(
        after: WiFiServiceError.noNetworkInBand(.five)
      )
    )
    #expect(
      AssociationFailurePolicy.keepsPreferenceActive(
        after: WiFiServiceError.verificationFailed(.five)
      )
    )
    #expect(
      !AssociationFailurePolicy.keepsPreferenceActive(
        after: WiFiServiceError.credentialsUnavailable
      )
    )
    #expect(
      !AssociationFailurePolicy.keepsPreferenceActive(
        after: NSError(domain: "Authorization", code: 1)
      )
    )
  }

  @Test
  func candidateTieBreakIsDeterministic() {
    let candidates = [
      NetworkCandidate(identifier: "b", band: .five, rssi: -50),
      NetworkCandidate(identifier: "a", band: .five, rssi: -50),
    ]

    let selected = BandSelection.bestCandidate(for: .five, among: candidates)

    #expect(selected?.identifier == "a")
  }

  @Test
  func preferenceSurvivesEventsForSameNetwork() {
    var session = SessionPolicy()
    session.observe(ssid: "Cafe")
    session.select(.five)

    session.observe(ssid: "Cafe")

    #expect(session.preference == .five)
  }

  @Test
  func sessionRestoresSavedPreferenceWhenNetworkConnects() {
    var session = SessionPolicy()

    session.observe(ssid: "Cafe", savedPreference: .five)

    #expect(session.preference == .five)
    #expect(session.ssid == "Cafe")
  }

  @Test
  func repeatedObservationDoesNotOverwriteActivePreference() {
    var session = SessionPolicy()
    session.observe(ssid: "Cafe", savedPreference: .five)

    session.observe(ssid: "Cafe", savedPreference: .automatic)

    #expect(session.preference == .five)
  }

  @Test
  func savedPreferenceFallsBackToAutomaticWhenApplyingItWouldPrompt() {
    let preference = PreferenceRestorationPolicy.effectivePreference(
      savedPreference: .five,
      canApplyWithoutUserInteraction: false
    )

    #expect(preference == .automatic)
  }

  @Test
  func savedPreferenceRestoresWhenItCanBeAppliedWithoutPrompting() {
    let preference = PreferenceRestorationPolicy.effectivePreference(
      savedPreference: .five,
      canApplyWithoutUserInteraction: true
    )

    #expect(preference == .five)
    #expect(
      PreferenceRestorationPolicy.effectivePreference(
        savedPreference: .automatic,
        canApplyWithoutUserInteraction: false
      ) == .automatic
    )
  }

  @Test
  func preferenceResetsWhenNetworkChanges() {
    var session = SessionPolicy()
    session.observe(ssid: "Cafe")
    session.select(.five)

    session.observe(ssid: "Home")

    #expect(session.preference == .automatic)
    #expect(session.ssid == "Home")
  }

  @Test
  func preferenceResetsOnDisconnect() {
    var session = SessionPolicy()
    session.observe(ssid: "Cafe")
    session.select(.five)

    session.observe(ssid: nil)

    #expect(session.preference == .automatic)
    #expect(session.ssid == nil)
  }

  @Test
  func correctionOnlyAppliesToMismatchedExplicitPreference() {
    var session = SessionPolicy()
    session.observe(ssid: "Cafe")
    #expect(!session.needsCorrection(for: .twoPointFour))

    session.select(.five)

    #expect(session.needsCorrection(for: .twoPointFour))
    #expect(!session.needsCorrection(for: .five))
  }

  @Test
  func cannotSelectBandWhileDisconnected() {
    var session = SessionPolicy()

    session.select(.five)

    #expect(session.preference == .automatic)
  }

  @Test
  func savedPreferenceSurvivesStoreRecreation() throws {
    let suiteName = "org.bandsteerer.BandSteererTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    BandPreferenceStore(defaults: defaults).set(.five, for: "Cafe")
    let relaunchedStore = BandPreferenceStore(
      defaults: try #require(UserDefaults(suiteName: suiteName))
    )

    #expect(relaunchedStore.preference(for: "Cafe") == .five)
    #expect(relaunchedStore.preference(for: "Home") == .automatic)
  }

  @Test
  func automaticClearsSavedPreference() throws {
    let suiteName = "org.bandsteerer.BandSteererTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = BandPreferenceStore(defaults: defaults)
    store.set(.twoPointFour, for: "Cafe")

    store.set(.automatic, for: "Cafe")

    #expect(store.preference(for: "Cafe") == .automatic)
  }

  @Test
  func savedPreferenceDoesNotPersistPlaintextSSID() throws {
    let suiteName = "org.bandsteerer.BandSteererTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    BandPreferenceStore(defaults: defaults).set(.five, for: "Private Network")

    let saved = try #require(
      defaults.dictionary(forKey: BandPreferenceStore.storageKey) as? [String: String]
    )

    #expect(saved["Private Network"] == nil)
    #expect(saved[BandPreferenceStore.networkIdentifier(for: "Private Network")] == "five")
  }

  @Test
  func malformedSavedPreferenceFallsBackToAutomatic() throws {
    let suiteName = "org.bandsteerer.BandSteererTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(
      [BandPreferenceStore.networkIdentifier(for: "Cafe"): "unsupported"],
      forKey: BandPreferenceStore.storageKey
    )

    #expect(BandPreferenceStore(defaults: defaults).preference(for: "Cafe") == .automatic)
  }

  @Test
  func removesAllSavedPreferences() throws {
    let suiteName = "org.bandsteerer.BandSteererTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = BandPreferenceStore(defaults: defaults)
    store.set(.five, for: "Cafe")
    store.set(.twoPointFour, for: "Home")

    store.removeAll()

    #expect(store.preference(for: "Cafe") == .automatic)
    #expect(store.preference(for: "Home") == .automatic)
    #expect(defaults.object(forKey: BandPreferenceStore.storageKey) == nil)
  }

  @Test
  func menuBarPresentationShowsOnlyWiFiInAutomaticMode() {
    let presentation = MenuBarPresentation(
      isLocationAuthorized: true,
      connection: connected(on: .five),
      preference: .automatic,
      isWorking: false,
      isRecoveringFromWake: false
    )

    #expect(presentation.systemImage == "wifi")
    #expect(presentation.bandText == nil)
    #expect(
      String(localized: presentation.accessibilityLabel)
        == "BandSteerer is using Automatic mode"
    )
  }

  @Test
  func automaticModeDoesNotAdvertiseWakeRecovery() {
    let presentation = MenuBarPresentation(
      isLocationAuthorized: true,
      connection: connected(on: .five),
      preference: .automatic,
      isWorking: false,
      isRecoveringFromWake: true
    )

    #expect(presentation.systemImage == "wifi")
    #expect(presentation.bandText == nil)
    #expect(
      String(localized: presentation.accessibilityLabel)
        == "BandSteerer is using Automatic mode"
    )
  }

  @Test
  func menuBarPresentationShowsActiveBandWithUnits() {
    let fiveGHz = MenuBarPresentation(
      isLocationAuthorized: true,
      connection: connected(on: .five),
      preference: .five,
      isWorking: false,
      isRecoveringFromWake: false
    )
    let twoPointFourGHz = MenuBarPresentation(
      isLocationAuthorized: true,
      connection: connected(on: .twoPointFour),
      preference: .twoPointFour,
      isWorking: false,
      isRecoveringFromWake: false
    )

    #expect(fiveGHz.systemImage == "wifi")
    #expect(fiveGHz.bandText == "5 GHz")
    #expect(
      String(localized: fiveGHz.accessibilityLabel)
        == "BandSteerer has the 5 GHz preference active"
    )
    #expect(twoPointFourGHz.systemImage == "wifi")
    #expect(twoPointFourGHz.bandText == "2.4 GHz")
    #expect(
      String(localized: twoPointFourGHz.accessibilityLabel)
        == "BandSteerer has the 2.4 GHz preference active"
    )
  }

  @Test
  func menuBarPresentationMakesCorrectionVisible() {
    let presentation = MenuBarPresentation(
      isLocationAuthorized: true,
      connection: connected(on: .twoPointFour),
      preference: .five,
      isWorking: false,
      isRecoveringFromWake: false
    )
    let switching = MenuBarPresentation(
      isLocationAuthorized: true,
      connection: connected(on: .five),
      preference: .five,
      isWorking: true,
      isRecoveringFromWake: false
    )

    #expect(presentation.systemImage == "wifi.exclamationmark")
    #expect(presentation.bandText == "5 GHz")
    #expect(
      String(localized: presentation.accessibilityLabel)
        == "BandSteerer is restoring the 5 GHz preference"
    )
    #expect(switching.systemImage == "wifi.exclamationmark")
  }

  @Test
  func menuBarPresentationShowsUnavailableStates() {
    let missingPermission = MenuBarPresentation(
      isLocationAuthorized: false,
      connection: connected(on: .five),
      preference: .five,
      isWorking: false,
      isRecoveringFromWake: false
    )
    let poweredOff = MenuBarPresentation(
      isLocationAuthorized: true,
      connection: WiFiConnection(isPoweredOn: false, isInterfaceAvailable: true),
      preference: .automatic,
      isWorking: false,
      isRecoveringFromWake: false
    )

    #expect(missingPermission.systemImage == "wifi.slash")
    #expect(missingPermission.bandText == nil)
    #expect(poweredOff.systemImage == "wifi.slash")
    #expect(poweredOff.bandText == nil)
  }

  @Test
  func oldMenuMessagesExpire() {
    let shownAt = Date(timeIntervalSince1970: 1_000)

    #expect(
      !MenuMessagePolicy.isExpired(
        shownAt: shownAt,
        now: shownAt.addingTimeInterval(MenuMessagePolicy.expirationInterval - 1)
      )
    )
    #expect(
      MenuMessagePolicy.isExpired(
        shownAt: shownAt,
        now: shownAt.addingTimeInterval(MenuMessagePolicy.expirationInterval)
      )
    )
  }

  @Test
  func correctionBackoffStartsFastAndCaps() {
    #expect(CorrectionPolicy.retryDelay(afterConsecutiveFailures: 0) == 15)
    #expect(CorrectionPolicy.retryDelay(afterConsecutiveFailures: 1) == 15)
    #expect(CorrectionPolicy.retryDelay(afterConsecutiveFailures: 2) == 30)
    #expect(CorrectionPolicy.retryDelay(afterConsecutiveFailures: 3) == 60)
    #expect(CorrectionPolicy.retryDelay(afterConsecutiveFailures: 20) == 120)
  }

  @Test
  func wakeRecoveryIgnoresTemporaryDisconnects() {
    #expect(!WakeRecoveryPolicy.shouldCommit(.disconnected, afterAttempt: 0))
    #expect(
      WakeRecoveryPolicy.shouldCommit(
        .disconnected,
        afterAttempt: WakeRecoveryPolicy.retryDelays.count - 1
      )
    )
  }

  @Test
  func wakeRecoveryAcceptsConnectedNetworkImmediately() {
    let connected = WiFiConnection(
      ssid: "Cafe",
      isPoweredOn: true,
      isInterfaceAvailable: true
    )

    #expect(WakeRecoveryPolicy.shouldCommit(connected, afterAttempt: 0))
  }

  @Test
  func wakeRecoveryIsBounded() {
    #expect(WakeRecoveryPolicy.retryDelays.reduce(0, +) == 32)
    #expect(WakeRecoveryPolicy.retryDelays.allSatisfy { $0 > 0 })
  }

  private func connected(on band: WiFiBand) -> WiFiConnection {
    WiFiConnection(
      ssid: "Cafe",
      band: band,
      isPoweredOn: true,
      isInterfaceAvailable: true
    )
  }
}
