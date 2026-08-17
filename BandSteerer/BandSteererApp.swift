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
    .menuBarExtraStyle(.menu)

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

    HStack(spacing: 3) {
      Image(systemName: presentation.systemImage)

      if let bandText = presentation.bandText {
        Text(bandText)
          .monospacedDigit()
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(presentation.accessibilityLabel))
  }
}
