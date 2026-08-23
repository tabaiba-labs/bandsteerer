import AppKit
import Foundation
import Testing

@testable import BandSteerer

struct BandSteererTests {
  @Test
  func menuBarIconsHaveNativeStatusItemDimensions() throws {
    let expectedSize = NSSize(width: 18, height: 18)

    #expect(try #require(NSImage(named: "MenuBarIconOn")).size == expectedSize)
    #expect(try #require(NSImage(named: "MenuBarIconOff")).size == expectedSize)
  }

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
  func locationPermissionCopyStaysCompactInNativePanel() {
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
  func choosesStrongestFiveGHzCandidate() {
    let candidates = [
      NetworkCandidate(identifier: "5g-weak", rssi: -70),
      NetworkCandidate(identifier: "5g-strong", rssi: -54),
    ]

    let selected = FiveGHzSelection.strongestCandidate(among: candidates)

    #expect(selected?.identifier == "5g-strong")
  }

  @Test
  func returnsNilWhenFiveGHzIsUnavailable() {
    #expect(FiveGHzSelection.strongestCandidate(among: []) == nil)
  }

  @Test
  func onlyTransientAssociationFailuresKeepPreferenceActive() {
    #expect(
      AssociationFailurePolicy.keepsPreferenceActive(
        after: WiFiServiceError.noFiveGHzNetwork
      )
    )
    #expect(
      AssociationFailurePolicy.keepsPreferenceActive(
        after: WiFiServiceError.verificationFailed
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
      NetworkCandidate(identifier: "b", rssi: -50),
      NetworkCandidate(identifier: "a", rssi: -50),
    ]

    let selected = FiveGHzSelection.strongestCandidate(among: candidates)

    #expect(selected?.identifier == "a")
  }

  @Test
  func preferenceSurvivesEventsForSameNetwork() {
    var session = SessionPolicy()
    session.observe(ssid: "Cafe")
    session.setFiveGHzPreference(true)

    session.observe(ssid: "Cafe")

    #expect(session.prefersFiveGHz)
  }

  @Test
  func sessionRestoresSavedPreferenceWhenNetworkConnects() {
    var session = SessionPolicy()

    session.observe(ssid: "Cafe", savedPreferenceEnabled: true)

    #expect(session.prefersFiveGHz)
    #expect(session.ssid == "Cafe")
  }

  @Test
  func repeatedObservationDoesNotOverwriteActivePreference() {
    var session = SessionPolicy()
    session.observe(ssid: "Cafe", savedPreferenceEnabled: true)

    session.observe(ssid: "Cafe", savedPreferenceEnabled: false)

    #expect(session.prefersFiveGHz)
  }

  @Test
  func savedPreferenceFallsBackToAutomaticWhenApplyingItWouldPrompt() {
    let shouldEnable = PreferenceRestorationPolicy.shouldEnableFiveGHz(
      savedPreferenceEnabled: true,
      canApplyWithoutUserInteraction: false
    )

    #expect(!shouldEnable)
  }

  @Test
  func savedPreferenceRestoresWhenItCanBeAppliedWithoutPrompting() {
    let shouldEnable = PreferenceRestorationPolicy.shouldEnableFiveGHz(
      savedPreferenceEnabled: true,
      canApplyWithoutUserInteraction: true
    )

    #expect(shouldEnable)
    #expect(
      !PreferenceRestorationPolicy.shouldEnableFiveGHz(
        savedPreferenceEnabled: false,
        canApplyWithoutUserInteraction: false
      )
    )
  }

  @Test
  func preferenceResetsWhenNetworkChanges() {
    var session = SessionPolicy()
    session.observe(ssid: "Cafe")
    session.setFiveGHzPreference(true)

    session.observe(ssid: "Home")

    #expect(!session.prefersFiveGHz)
    #expect(session.ssid == "Home")
  }

  @Test
  func preferenceResetsOnDisconnect() {
    var session = SessionPolicy()
    session.observe(ssid: "Cafe")
    session.setFiveGHzPreference(true)

    session.observe(ssid: nil)

    #expect(!session.prefersFiveGHz)
    #expect(session.ssid == nil)
  }

  @Test
  func correctionOnlyAppliesToMismatchedExplicitPreference() {
    var session = SessionPolicy()
    session.observe(ssid: "Cafe")
    #expect(!session.needsCorrection(for: .twoPointFour))

    session.setFiveGHzPreference(true)

    #expect(session.needsCorrection(for: .twoPointFour))
    #expect(!session.needsCorrection(for: .five))
  }

  @Test
  func cannotEnableFiveGHzPreferenceWhileDisconnected() {
    var session = SessionPolicy()

    session.setFiveGHzPreference(true)

    #expect(!session.prefersFiveGHz)
  }

  @Test
  func savedPreferenceSurvivesStoreRecreation() throws {
    let suiteName = "org.bandsteerer.BandSteererTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    FiveGHzPreferenceStore(defaults: defaults).setEnabled(true, for: "Cafe")
    let relaunchedStore = FiveGHzPreferenceStore(
      defaults: try #require(UserDefaults(suiteName: suiteName))
    )

    #expect(relaunchedStore.isEnabled(for: "Cafe"))
    #expect(!relaunchedStore.isEnabled(for: "Home"))
  }

  @Test
  func disablingClearsSavedPreference() throws {
    let suiteName = "org.bandsteerer.BandSteererTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = FiveGHzPreferenceStore(defaults: defaults)
    store.setEnabled(true, for: "Cafe")

    store.setEnabled(false, for: "Cafe")

    #expect(!store.isEnabled(for: "Cafe"))
    #expect(defaults.object(forKey: FiveGHzPreferenceStore.storageKey) == nil)
  }

  @Test
  func savedPreferenceDoesNotPersistPlaintextSSID() throws {
    let suiteName = "org.bandsteerer.BandSteererTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    FiveGHzPreferenceStore(defaults: defaults).setEnabled(true, for: "Private Network")

    let saved = try #require(
      defaults.dictionary(forKey: FiveGHzPreferenceStore.storageKey) as? [String: String]
    )

    #expect(saved["Private Network"] == nil)
    #expect(saved[FiveGHzPreferenceStore.networkIdentifier(for: "Private Network")] == "five")
  }

  @Test
  func legacyTwoPointFourPreferenceMigratesToOff() throws {
    let suiteName = "org.bandsteerer.BandSteererTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(
      [FiveGHzPreferenceStore.networkIdentifier(for: "Cafe"): "twoPointFour"],
      forKey: FiveGHzPreferenceStore.storageKey
    )

    #expect(!FiveGHzPreferenceStore(defaults: defaults).isEnabled(for: "Cafe"))
    #expect(defaults.object(forKey: FiveGHzPreferenceStore.storageKey) == nil)
  }

  @Test
  func removesAllSavedPreferences() throws {
    let suiteName = "org.bandsteerer.BandSteererTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = FiveGHzPreferenceStore(defaults: defaults)
    store.setEnabled(true, for: "Cafe")
    store.setEnabled(true, for: "Home")

    store.removeAll()

    #expect(!store.isEnabled(for: "Cafe"))
    #expect(!store.isEnabled(for: "Home"))
    #expect(defaults.object(forKey: FiveGHzPreferenceStore.storageKey) == nil)
  }

  @Test
  func menuBarPresentationUsesOffIconInAutomaticMode() {
    let presentation = MenuBarPresentation(
      isLocationAuthorized: true,
      connection: connected(on: .five),
      prefersFiveGHz: false,
      isWorking: false,
      isRecoveringFromWake: false
    )

    #expect(presentation.iconAssetName == "MenuBarIconOff")
    #expect(
      String(localized: presentation.accessibilityLabel)
        == "BandSteerer is using automatic Wi-Fi selection"
    )
  }

  @Test
  func automaticModeDoesNotAdvertiseWakeRecovery() {
    let presentation = MenuBarPresentation(
      isLocationAuthorized: true,
      connection: connected(on: .five),
      prefersFiveGHz: false,
      isWorking: false,
      isRecoveringFromWake: true
    )

    #expect(presentation.iconAssetName == "MenuBarIconOff")
    #expect(
      String(localized: presentation.accessibilityLabel)
        == "BandSteerer is using automatic Wi-Fi selection"
    )
  }

  @Test
  func menuBarPresentationUsesOnIconForActiveFiveGHzPreference() {
    let presentation = MenuBarPresentation(
      isLocationAuthorized: true,
      connection: connected(on: .five),
      prefersFiveGHz: true,
      isWorking: false,
      isRecoveringFromWake: false
    )

    #expect(presentation.iconAssetName == "MenuBarIconOn")
    #expect(
      String(localized: presentation.accessibilityLabel)
        == "BandSteerer has the 5 GHz preference active"
    )
  }

  @Test
  func menuBarPresentationMakesCorrectionVisible() {
    let presentation = MenuBarPresentation(
      isLocationAuthorized: true,
      connection: connected(on: .twoPointFour),
      prefersFiveGHz: true,
      isWorking: false,
      isRecoveringFromWake: false
    )
    let switching = MenuBarPresentation(
      isLocationAuthorized: true,
      connection: connected(on: .five),
      prefersFiveGHz: true,
      isWorking: true,
      isRecoveringFromWake: false
    )

    #expect(presentation.iconAssetName == "MenuBarIconOn")
    #expect(
      String(localized: presentation.accessibilityLabel)
        == "BandSteerer is restoring the 5 GHz preference"
    )
    #expect(switching.iconAssetName == "MenuBarIconOn")
  }

  @Test
  func menuBarPresentationShowsUnavailableStates() {
    let missingPermission = MenuBarPresentation(
      isLocationAuthorized: false,
      connection: connected(on: .five),
      prefersFiveGHz: true,
      isWorking: false,
      isRecoveringFromWake: false
    )
    let poweredOff = MenuBarPresentation(
      isLocationAuthorized: true,
      connection: WiFiConnection(isPoweredOn: false, isInterfaceAvailable: true),
      prefersFiveGHz: false,
      isWorking: false,
      isRecoveringFromWake: false
    )
    let interfaceUnavailable = MenuBarPresentation(
      isLocationAuthorized: true,
      connection: WiFiConnection(
        ssid: "Cafe",
        band: .five,
        isPoweredOn: true,
        isInterfaceAvailable: false
      ),
      prefersFiveGHz: true,
      isWorking: false,
      isRecoveringFromWake: false
    )
    let disconnected = MenuBarPresentation(
      isLocationAuthorized: true,
      connection: WiFiConnection(isPoweredOn: true, isInterfaceAvailable: true),
      prefersFiveGHz: true,
      isWorking: false,
      isRecoveringFromWake: false
    )

    #expect(missingPermission.iconAssetName == "MenuBarIconOff")
    #expect(poweredOff.iconAssetName == "MenuBarIconOff")
    #expect(interfaceUnavailable.iconAssetName == "MenuBarIconOff")
    #expect(disconnected.iconAssetName == "MenuBarIconOff")
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
