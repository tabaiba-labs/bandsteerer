import AppKit
import Foundation
@preconcurrency import Network
import OSLog
import ServiceManagement

@MainActor
final class AppModel: NSObject, ObservableObject {
  private static let logger = Logger(
    subsystem: AppIdentity.bundleIdentifier,
    category: "Lifecycle"
  )

  @Published private(set) var connection = WiFiConnection.disconnected
  @Published private(set) var preference: BandPreference = .automatic
  @Published private(set) var isWorking = false
  @Published private(set) var isRecoveringFromWake = false
  @Published private(set) var message: String?
  @Published private(set) var launchAtLogin = false

  let locationPermission = LocationPermission()

  private let service: WiFiService
  private let preferenceStore: BandPreferenceStore
  private let pathMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
  private let pathMonitorQueue = DispatchQueue(
    label: "\(AppIdentity.bundleIdentifier).network-path",
    qos: .utility
  )
  private var session = SessionPolicy()
  private var refreshTask: Task<Void, Never>?
  private var associationTask: Task<Void, Never>?
  private var correctionTask: Task<Void, Never>?
  private var monitoringTask: Task<Void, Never>?
  private var wakeRecoveryTask: Task<Void, Never>?
  private var sleepingSessionSSID: String?
  private var isAssociating = false
  private var associationGeneration = 0
  private var consecutiveCorrectionFailures = 0
  private var nextCorrectionAttempt = Date.distantPast

  init(
    service: WiFiService = WiFiService(),
    preferenceStore: BandPreferenceStore = BandPreferenceStore()
  ) {
    self.service = service
    self.preferenceStore = preferenceStore
    super.init()
    launchAtLogin = SMAppService.mainApp.status == .enabled
    observeWorkspaceLifecycle()
    observeNetworkPath()
    refresh()
  }

  deinit {
    pathMonitor.cancel()
    refreshTask?.cancel()
    associationTask?.cancel()
    correctionTask?.cancel()
    monitoringTask?.cancel()
    wakeRecoveryTask?.cancel()
    NSWorkspace.shared.notificationCenter.removeObserver(self)
  }

  func menuDidOpen() {
    refresh()
  }

  func requestLocationAccess() {
    locationPermission.request()
  }

  func select(_ newPreference: BandPreference) {
    guard connection.isConnected, let ssid = session.ssid else { return }
    session.select(newPreference)
    preference = session.preference
    preferenceStore.set(preference, for: ssid)
    message = nil
    correctionTask?.cancel()

    guard let desiredBand = newPreference.band else {
      cancelAssociation()
      stopPreferenceMonitoring()
      resetCorrectionBackoff()
      return
    }

    resetCorrectionBackoff()
    startPreferenceMonitoring()
    associate(with: desiredBand, automatic: false)
  }

  func setLaunchAtLogin(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      launchAtLogin = SMAppService.mainApp.status == .enabled
    } catch {
      launchAtLogin = SMAppService.mainApp.status == .enabled
      message = "Launch at login could not be changed: \(error.localizedDescription)"
    }
  }

  func quit() {
    NSApplication.shared.terminate(nil)
  }

  private func refresh() {
    guard !isRecoveringFromWake else { return }
    refreshTask?.cancel()
    refreshTask = Task { [weak self] in
      await self?.refreshFromService()
    }
  }

  private func refreshFromService() async {
    let updatedConnection = await service.readConnection()
    guard !Task.isCancelled else { return }

    await apply(updatedConnection)
  }

  private func apply(_ updatedConnection: WiFiConnection) async {
    if !isAssociating {
      let previousSSID = session.ssid
      if previousSSID != updatedConnection.ssid {
        let savedPreference =
          updatedConnection.ssid.map {
            preferenceStore.preference(for: $0)
          } ?? .automatic
        session.observe(ssid: updatedConnection.ssid, savedPreference: savedPreference)
        await service.clearCachedPasswords()
        message = nil
        resetCorrectionBackoff()
      }
      preference = session.preference
      if preference == .automatic {
        stopPreferenceMonitoring()
      } else if previousSSID != session.ssid {
        startPreferenceMonitoring()
      }
    }
    connection = updatedConnection

    guard updatedConnection.isConnected,
      session.needsCorrection(for: updatedConnection.band),
      !isAssociating,
      Date() >= nextCorrectionAttempt,
      let desiredBand = session.preference.band
    else { return }

    scheduleCorrection(to: desiredBand)
  }

  private func observeWorkspaceLifecycle() {
    let notificationCenter = NSWorkspace.shared.notificationCenter
    notificationCenter.addObserver(
      self,
      selector: #selector(workspaceWillSleep),
      name: NSWorkspace.willSleepNotification,
      object: NSWorkspace.shared
    )
    notificationCenter.addObserver(
      self,
      selector: #selector(workspaceDidWake),
      name: NSWorkspace.didWakeNotification,
      object: NSWorkspace.shared
    )
  }

  private func observeNetworkPath() {
    pathMonitor.pathUpdateHandler = { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.refresh()
      }
    }
    pathMonitor.start(queue: pathMonitorQueue)
  }

  @objc private func workspaceWillSleep(_ notification: Notification) {
    Self.logger.info("Mac is sleeping; pausing Wi-Fi checks")
    sleepingSessionSSID = session.ssid
    isRecoveringFromWake = true
    wakeRecoveryTask?.cancel()
    refreshTask?.cancel()
    correctionTask?.cancel()
    cancelAssociation()
    stopPreferenceMonitoring()
  }

  @objc private func workspaceDidWake(_ notification: Notification) {
    Self.logger.info("Mac woke; starting bounded Wi-Fi recovery")

    if !isRecoveringFromWake {
      sleepingSessionSSID = session.ssid
      isRecoveringFromWake = true
      refreshTask?.cancel()
      correctionTask?.cancel()
      stopPreferenceMonitoring()
    }

    wakeRecoveryTask?.cancel()
    wakeRecoveryTask = Task { [weak self] in
      await self?.recoverConnectionAfterWake()
    }
  }

  private func recoverConnectionAfterWake() async {
    for (attempt, delay) in WakeRecoveryPolicy.retryDelays.enumerated() {
      do {
        try await Task.sleep(for: .seconds(delay), tolerance: .milliseconds(250))
      } catch {
        return
      }

      let updatedConnection = await service.readConnection()
      guard !Task.isCancelled else { return }
      guard WakeRecoveryPolicy.shouldCommit(updatedConnection, afterAttempt: attempt) else {
        continue
      }

      let resumedSameSession =
        updatedConnection.isConnected && updatedConnection.ssid == sleepingSessionSSID
      isRecoveringFromWake = false
      await apply(updatedConnection)
      sleepingSessionSSID = nil

      if resumedSameSession, preference != .automatic {
        startPreferenceMonitoring()
      }

      Self.logger.info(
        "Wake recovery finished; connected=\(updatedConnection.isConnected, privacy: .public), sameSession=\(resumedSameSession, privacy: .public)"
      )
      return
    }
  }

  private func startPreferenceMonitoring() {
    monitoringTask?.cancel()
    monitoringTask = Task { [weak self] in
      while !Task.isCancelled {
        do {
          try await Task.sleep(for: .seconds(10), tolerance: .seconds(2))
        } catch {
          return
        }
        guard !Task.isCancelled, let self else { return }
        await refreshFromService()
        guard preference != .automatic else { return }
      }
    }
  }

  private func stopPreferenceMonitoring() {
    monitoringTask?.cancel()
    monitoringTask = nil
  }

  private func scheduleCorrection(to band: WiFiBand) {
    correctionTask?.cancel()
    correctionTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(2))
      guard !Task.isCancelled else { return }
      self?.associate(with: band, automatic: true)
    }
  }

  private func associate(with band: WiFiBand, automatic: Bool) {
    cancelAssociation()
    let generation = associationGeneration
    associationTask = Task { [weak self] in
      guard let self else { return }
      isAssociating = true
      isWorking = true
      defer {
        if associationGeneration == generation {
          isAssociating = false
          isWorking = false
          associationTask = nil
        }
      }

      do {
        let updatedConnection = try await service.associate(
          with: band,
          allowSystemKeychainAccess: !automatic
        )
        try Task.checkCancellation()
        guard associationGeneration == generation else { return }
        connection = updatedConnection
        message = nil
        resetCorrectionBackoff()
      } catch is CancellationError {
        return
      } catch {
        guard !Task.isCancelled, associationGeneration == generation else { return }
        recordCorrectionFailure()
        let serviceError = error as? WiFiServiceError
        if let serviceError, !serviceError.keepsPreferenceActive {
          let failedSSID = session.ssid
          session.select(.automatic)
          preference = .automatic
          stopPreferenceMonitoring()
          if !automatic, let failedSSID {
            preferenceStore.set(.automatic, for: failedSSID)
          }
        }
        if !automatic || serviceError?.keepsPreferenceActive == false {
          message = error.localizedDescription
        }
        let updatedConnection = await service.readConnection()
        guard !Task.isCancelled, associationGeneration == generation else { return }
        connection = updatedConnection
      }
    }
  }

  private func cancelAssociation() {
    associationGeneration &+= 1
    associationTask?.cancel()
    associationTask = nil
    isAssociating = false
    isWorking = false
  }

  private func recordCorrectionFailure() {
    consecutiveCorrectionFailures += 1
    nextCorrectionAttempt = Date().addingTimeInterval(
      CorrectionPolicy.retryDelay(afterConsecutiveFailures: consecutiveCorrectionFailures)
    )
  }

  private func resetCorrectionBackoff() {
    consecutiveCorrectionFailures = 0
    nextCorrectionAttempt = .distantPast
  }
}
