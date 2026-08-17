import SwiftUI

struct MenuBarView: View {
  @Environment(\.openWindow) private var openWindow
  @ObservedObject var model: AppModel
  @ObservedObject var updates: UpdateController
  @ObservedObject private var locationPermission: LocationPermission

  init(model: AppModel, updates: UpdateController) {
    self.model = model
    self.updates = updates
    locationPermission = model.locationPermission
  }

  var body: some View {
    Group {
      statusSection

      if locationPermission.isAuthorized {
        bandPicker
      } else {
        locationActions
      }

      Divider()

      Toggle(
        "Open at Login",
        isOn: Binding(
          get: { model.launchAtLogin },
          set: { model.setLaunchAtLogin($0) }
        )
      )

      Divider()

      Button("About BandSteerer") {
        openWindow(id: "about")
        NSApplication.shared.activate()
      }

      Button("Check for Updates…") {
        updates.checkForUpdates()
      }
      .disabled(!updates.canCheckForUpdates)

      Divider()

      Button("Quit BandSteerer") {
        model.quit()
      }
      .keyboardShortcut("q", modifiers: .command)
    }
    .onAppear {
      model.menuDidOpen()
    }
    .onChange(of: locationPermission.status) {
      model.menuDidOpen()
    }
  }

  @ViewBuilder
  private var statusSection: some View {
    if !locationPermission.isAuthorized {
      Section("Wi-Fi Access") {
        locationPermissionExplanation
      }
    } else if model.isRecoveringFromWake {
      Section(model.connection.ssid ?? "Reconnecting to Wi-Fi") {
        Text("Checking the connection after wake…")
      }
    } else if model.connection.isConnected {
      Section(networkTitle) {
        if !connectionSummary.isEmpty {
          Text(connectionSummary)
        }

        if model.isWorking {
          Text("Switching to \(model.preference.title)…")
        } else if let desiredBand = model.preference.band,
          model.connection.band != desiredBand
        {
          Text("Restoring \(model.preference.title)…")
        } else if model.preference != .automatic {
          Text("\(model.preference.title) preference active")
        }
      }
    } else if !model.connection.isInterfaceAvailable {
      Section("Wi-Fi Unavailable") {
        Text("BandSteerer couldn't read the Wi-Fi interface.")
        Button("Refresh Status") {
          model.menuDidOpen()
        }
      }
    } else if model.connection.isPoweredOn {
      Section("Not Connected") {
        Text("Connect to Wi-Fi to choose a band.")
      }
    } else {
      Section("Wi-Fi is Off") {
        Text("Turn on Wi-Fi to choose a band.")
      }
    }

    if let message = model.message {
      Section {
        Label(message, systemImage: "exclamationmark.triangle")
      }
    }
  }

  private var locationPermissionExplanation: some View {
    let lines = locationPermissionExplanationLines

    return ForEach(lines.indices, id: \.self) { index in
      Text(lines[index])
    }
  }

  private var locationPermissionExplanationLines: [LocalizedStringResource] {
    if locationPermission.isUndetermined {
      LocationPermissionMenuCopy.undetermined
    } else if locationPermission.status == .restricted {
      LocationPermissionMenuCopy.restricted
    } else {
      LocationPermissionMenuCopy.denied
    }
  }

  private var bandPicker: some View {
    Picker(
      "Band preference",
      selection: Binding(
        get: { model.preference },
        set: { model.select($0) }
      )
    ) {
      Text("Automatic (macOS chooses)").tag(BandPreference.automatic)
      Text("Prefer 2.4 GHz").tag(BandPreference.twoPointFour)
      Text("Prefer 5 GHz").tag(BandPreference.five)
    }
    .pickerStyle(.inline)
    .disabled(!model.connection.isConnected || model.isRecoveringFromWake)
  }

  @ViewBuilder
  private var locationActions: some View {
    if locationPermission.isUndetermined {
      Button("Allow Wi-Fi Access…") {
        model.requestLocationAccess()
      }
    } else {
      Button("Open Location Settings…") {
        if let url = URL(
          string:
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocationServices"
        ) {
          NSWorkspace.shared.open(url)
        }
      }
    }
  }

  private var networkTitle: String {
    "\(model.connection.ssid ?? "Wi-Fi") — \(model.connection.band.rawValue)"
  }

  private var connectionSummary: String {
    [
      model.connection.channel.map { "Channel \($0)" },
      model.connection.rssi.map { "Signal \($0) dBm" },
    ]
    .compactMap { $0 }
    .joined(separator: " · ")
  }
}

enum LocationPermissionMenuCopy {
  static let undetermined: [LocalizedStringResource] = [
    "macOS requires Location access for Wi-Fi names.",
    "BandSteerer never reads your location.",
  ]

  static let restricted: [LocalizedStringResource] = [
    "Location access is restricted.",
    "Allow it to reveal Wi-Fi names.",
  ]

  static let denied: [LocalizedStringResource] = [
    "Location access is off.",
    "Enable it in System Settings to reveal Wi-Fi names.",
  ]
}
