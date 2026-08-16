import SwiftUI

struct MenuBarView: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var locationPermission: LocationPermission

  init(model: AppModel) {
    self.model = model
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

      Button("Quit BandSteerer") {
        model.quit()
      }
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
        Text("Allow access so BandSteerer can identify the current Wi-Fi network.")
      }
    } else if model.isRecoveringFromWake {
      Section(model.connection.ssid ?? "Reconnecting to Wi-Fi") {
        Text("Checking the connection after wake…")
      }
    } else if model.connection.isConnected {
      Section(networkTitle) {
        Text(connectionSummary)

        if model.isWorking {
          Text("Switching to \(model.preference.title)…")
        } else if let desiredBand = model.preference.band,
          model.connection.band != desiredBand
        {
          Text("Restoring \(model.preference.title)…")
        } else if model.preference != .automatic {
          Text("\(model.preference.title) preference active")
        }

        if let message = model.message {
          Text(message)
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
    .disabled(
      !model.connection.isConnected || model.isWorking || model.isRecoveringFromWake
    )
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
      model.connection.transmitRate.map { "Link \(Int($0.rounded())) Mbps" },
    ]
    .compactMap { $0 }
    .joined(separator: " · ")
  }
}
