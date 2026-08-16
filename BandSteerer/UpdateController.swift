import Combine
import Sparkle

enum UpdateCheckPolicy {
  static func shouldCheckOnLaunch(automaticChecksEnabled: Bool) -> Bool {
    automaticChecksEnabled
  }
}

@MainActor
final class UpdateController: ObservableObject {
  @Published private(set) var canCheckForUpdates = false

  private let controller: SPUStandardUpdaterController
  private var canCheckForUpdatesObservation: AnyCancellable?

  init() {
    controller = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )
    canCheckForUpdatesObservation = controller.updater.publisher(for: \.canCheckForUpdates)
      .sink { [weak self] canCheckForUpdates in
        self?.canCheckForUpdates = canCheckForUpdates
      }

    if UpdateCheckPolicy.shouldCheckOnLaunch(
      automaticChecksEnabled: controller.updater.automaticallyChecksForUpdates
    ) {
      controller.updater.checkForUpdatesInBackground()
    }
  }

  func checkForUpdates() {
    controller.checkForUpdates(nil)
  }
}
