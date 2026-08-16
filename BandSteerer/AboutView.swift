import AppKit
import SwiftUI

struct AboutView: View {
  private let buildInfo = AppBuildInfo.current

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 10) {
        Image(nsImage: NSApplication.shared.applicationIconImage)
          .resizable()
          .interpolation(.high)
          .frame(width: 80, height: 80)
          .accessibilityHidden(true)

        Text("BandSteerer")
          .font(.title2.weight(.semibold))

        Text(buildInfo.displayText)
          .font(.callout)
          .foregroundStyle(.secondary)
          .monospacedDigit()
          .textSelection(.enabled)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 24)

      Divider()

      VStack(alignment: .leading, spacing: 20) {
        AboutSection(
          title: "What it’s for",
          systemImage: "wifi",
          text:
            "BandSteerer lets you prefer 2.4 GHz or 5 GHz on the Wi-Fi network you’re already using—useful when macOS roams to the wrong band."
        )

        AboutSection(
          title: "How it works",
          systemImage: "arrow.triangle.2.circlepath",
          text:
            "It watches the current channel. If macOS moves away from your preference, BandSteerer reconnects to the strongest visible access point on that band. Automatic leaves roaming to macOS."
        )
      }
      .padding(24)

      Divider()

      Text("Made for macOS with public system frameworks.")
        .font(.caption)
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
    .frame(width: 440)
    .fixedSize(horizontal: false, vertical: true)
  }
}

#Preview("About BandSteerer") {
  AboutView()
}

private struct AboutSection: View {
  let title: String
  let systemImage: String
  let text: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: systemImage)
        .font(.title3)
        .foregroundStyle(.tint)
        .frame(width: 24)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)

        Text(text)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}
