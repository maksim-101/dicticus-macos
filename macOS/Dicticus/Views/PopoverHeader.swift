import SwiftUI
import AppKit

/// Persistent header row for the popover: wordmark on the left, gear button on the right.
///
/// Per UI-SPEC §macOS — Persistent Header:
///   - Wordmark: "Dicticus" in `.headline`
///   - Gear button: 40×40pt, corner radius 10, Color.primary.opacity(0.07) idle / 0.14 hover,
///     1pt Color.primary.opacity(0.10) stroke, SF Symbol "gear" at 22pt.
///   - Accessibility label: "Settings (Command-Comma)"
///   - Spacing exception `phead`: 10pt top/bottom, 16pt leading, 12pt trailing.
///
/// Gear action uses Q-03 spike-locked mechanism B:
///   NSApp.activate(ignoringOtherApps: true) then openSettings().
///   The NSApp.activate call guards against the .accessory MenuBarExtra first-click
///   foreground pitfall documented in 35-RESEARCH (Pitfall 1).
struct PopoverHeader: View {

    @Environment(\.openSettings) private var openSettings
    @State private var isHoveringGear = false

    var body: some View {
        HStack {
            Text("Dicticus")
                .font(.headline)

            Spacer()

            Button {
                // Q-03 spike-locked mechanism B (35-SPIKE-SETTINGS-OPEN.md):
                // NSApp.activate guards the .accessory first-click foreground pitfall.
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 15))
            }
            .buttonStyle(.plain)
            .frame(width: 26, height: 26)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(isHoveringGear ? 0.14 : 0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            )
            .onHover { hovering in
                isHoveringGear = hovering
            }
            .accessibilityLabel("Settings (Command-Comma)")
        }
        .padding(.top, 10)
        .padding(.bottom, 10)
        .padding(.leading, 16)
        .padding(.trailing, 12)
    }
}
