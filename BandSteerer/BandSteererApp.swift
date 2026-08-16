import SwiftUI

@main
struct BandSteererApp: App {
  @StateObject private var model = AppModel()
  @StateObject private var updates = UpdateController()

  var body: some Scene {
    MenuBarExtra("BandSteerer", systemImage: "wifi") {
      MenuBarView(model: model, updates: updates)
    }
    .menuBarExtraStyle(.menu)

    Window("About BandSteerer", id: "about") {
      AboutView()
    }
    .windowResizability(.contentSize)
  }
}
