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
}
