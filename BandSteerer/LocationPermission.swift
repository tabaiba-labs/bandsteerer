@preconcurrency import CoreLocation
import Foundation

@MainActor
final class LocationPermission: NSObject, ObservableObject {
  @Published private(set) var status: CLAuthorizationStatus

  private let manager = CLLocationManager()

  override init() {
    status = manager.authorizationStatus
    super.init()
    manager.delegate = self
  }

  var isAuthorized: Bool {
    status == .authorized || status == .authorizedAlways
  }

  var isUndetermined: Bool {
    status == .notDetermined
  }

  func request() {
    manager.requestWhenInUseAuthorization()
  }
}

extension LocationPermission: @MainActor CLLocationManagerDelegate {
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    status = manager.authorizationStatus
  }
}
