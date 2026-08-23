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
    VStack(spacing: 0) {
      connectionHeader

      Divider()

      if locationPermission.isAuthorized {
        preferenceControl
      } else {
        permissionControl
      }

      if let message = model.message {
        Divider()
        messageView(message)
      }

      Divider()

      footer
    }
    .frame(width: 320)
    .fixedSize(horizontal: false, vertical: true)
    .onAppear {
      model.menuDidOpen()
    }
    .onChange(of: locationPermission.status) {
      model.menuDidOpen()
    }
  }

  private var connectionHeader: some View {
    HStack(spacing: 12) {
      Image(systemName: connectionSystemImage)
        .font(.system(size: 22, weight: .medium))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(connectionSymbolColor)
        .frame(width: 44, height: 44)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

      VStack(alignment: .leading, spacing: 3) {
        Text(connectionTitle)
          .font(.headline)
          .lineLimit(1)

        Text(connectionSubtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }

      Spacer(minLength: 8)

      if model.isRecoveringFromWake {
        ProgressView()
          .controlSize(.small)
          .accessibilityLabel("Checking Wi-Fi after wake")
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 16)
    .padding(.bottom, 14)
  }

  private var preferenceControl: some View {
    HStack(alignment: .center, spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Prefer 5 GHz")
          .font(.body.weight(.medium))

        Text(preferenceDescription)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 8)

      if model.isWorking {
        ProgressView()
          .controlSize(.small)
          .accessibilityLabel("Switching to 5 GHz")
      }

      Toggle(
        "Prefer 5 GHz",
        isOn: Binding(
          get: { model.prefersFiveGHz },
          set: { model.setFiveGHzPreference($0) }
        )
      )
      .labelsHidden()
      .toggleStyle(.switch)
      .controlSize(.large)
      .disabled(!model.connection.isConnected || model.isRecoveringFromWake)
    }
    .padding(16)
  }

  private var permissionControl: some View {
    VStack(alignment: .leading, spacing: 12) {
      locationPermissionExplanation

      locationAction
    }
    .padding(16)
  }

  private var locationPermissionExplanation: some View {
    VStack(alignment: .leading, spacing: 4) {
      ForEach(locationPermissionExplanationLines.indices, id: \.self) { index in
        Text(locationPermissionExplanationLines[index])
          .font(index == 0 ? .body : .caption)
          .foregroundStyle(index == 0 ? .primary : .secondary)
      }
    }
  }

  @ViewBuilder
  private var locationAction: some View {
    if locationPermission.isUndetermined {
      Button("Allow Wi-Fi Access…") {
        model.requestLocationAccess()
      }
      .buttonStyle(.borderedProminent)
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

  private func messageView(_ message: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)

      Text(message)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  private var footer: some View {
    HStack(spacing: 4) {
      Button {
        openWindow(id: "about")
        NSApplication.shared.activate()
      } label: {
        Label("About BandSteerer", systemImage: "info.circle")
          .labelStyle(.iconOnly)
      }
      .help("About BandSteerer")

      Spacer()

      Menu {
        Toggle(
          "Open at Login",
          isOn: Binding(
            get: { model.launchAtLogin },
            set: { model.setLaunchAtLogin($0) }
          )
        )

        Button("Check for Updates…") {
          updates.checkForUpdates()
        }
        .disabled(!updates.canCheckForUpdates)

        Divider()

        Button("Quit BandSteerer") {
          model.quit()
        }
        .keyboardShortcut("q", modifiers: .command)
      } label: {
        Label("More", systemImage: "ellipsis.circle")
          .labelStyle(.iconOnly)
      }
      .menuStyle(.borderlessButton)
      .help("More")
    }
    .buttonStyle(.borderless)
    .controlSize(.large)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  private var connectionSystemImage: String {
    if !locationPermission.isAuthorized || !model.connection.isInterfaceAvailable {
      return "wifi.slash"
    }
    if model.isRecoveringFromWake || model.connection.isConnected {
      return "wifi"
    }
    return model.connection.isPoweredOn ? "wifi.exclamationmark" : "wifi.slash"
  }

  private var connectionSymbolColor: Color {
    if !locationPermission.isAuthorized || !model.connection.isInterfaceAvailable {
      return .orange
    }
    if model.prefersFiveGHz, model.connection.isConnected {
      return .accentColor
    }
    return .secondary
  }

  private var connectionTitle: String {
    if !locationPermission.isAuthorized {
      return "Wi-Fi access needed"
    }
    if model.isRecoveringFromWake {
      return model.connection.ssid ?? "Reconnecting to Wi-Fi"
    }
    if model.connection.isConnected {
      return model.connection.ssid ?? "Wi-Fi"
    }
    if !model.connection.isInterfaceAvailable {
      return "Wi-Fi unavailable"
    }
    return model.connection.isPoweredOn ? "Not connected" : "Wi-Fi is off"
  }

  private var connectionSubtitle: String {
    if !locationPermission.isAuthorized {
      return "BandSteerer needs permission to identify this network."
    }
    if model.isRecoveringFromWake {
      return "Checking the connection after wake…"
    }
    if model.connection.isConnected {
      return connectionSummary
    }
    if !model.connection.isInterfaceAvailable {
      return "BandSteerer couldn't read the Wi-Fi interface."
    }
    if model.connection.isPoweredOn {
      return "Connect to Wi-Fi to set a 5 GHz preference."
    }
    return "Turn on Wi-Fi to set a 5 GHz preference."
  }

  private var preferenceDescription: String {
    guard model.connection.isConnected else {
      return model.connection.isPoweredOn
        ? "Connect to Wi-Fi to set this preference."
        : "Turn on Wi-Fi to set this preference."
    }
    if model.isWorking {
      return "Switching this Mac to 5 GHz…"
    }
    if model.prefersFiveGHz, model.connection.band != .five {
      return "Watching for this network's 5 GHz band."
    }
    if model.prefersFiveGHz {
      return "BandSteerer will restore 5 GHz if macOS switches bands."
    }
    return "macOS chooses the Wi-Fi band automatically."
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

  private var connectionSummary: String {
    [
      model.connection.band.rawValue,
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
