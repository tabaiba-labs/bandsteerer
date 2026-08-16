import SwiftUI

@main
struct BandSteererApp: App {
  @StateObject private var model = AppModel()

  var body: some Scene {
    MenuBarExtra("BandSteerer", systemImage: "wifi") {
      MenuBarView(model: model)
    }
    .menuBarExtraStyle(.menu)
  }
}
