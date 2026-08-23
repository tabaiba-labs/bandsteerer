import SwiftUI

@main
struct BandSteererApp: App {
  @StateObject private var model = AppModel()
  @StateObject private var updates = UpdateController()

  var body: some Scene {
    MenuBarExtra {
      MenuBarView(model: model, updates: updates)
    } label: {
      MenuBarLabel(model: model)
    }
    .menuBarExtraStyle(.window)

    Window("About BandSteerer", id: "about") {
      AboutView(onResetSavedPreferences: model.resetSavedPreferences)
    }
    .windowResizability(.contentSize)
  }
}

private struct MenuBarLabel: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var locationPermission: LocationPermission

  init(model: AppModel) {
    self.model = model
    locationPermission = model.locationPermission
  }

  var body: some View {
    let presentation = model.menuBarPresentation

    Image(presentation.iconAssetName)
      .renderingMode(.template)
      .accessibilityLabel(Text(presentation.accessibilityLabel))
  }
}
