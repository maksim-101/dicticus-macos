import SwiftUI

/// Persistent header row for the popover: wordmark on the left, gear button on the right.
///
/// Per UI-SPEC §macOS — Persistent Header:
///   - Wordmark: "Dicticus" in `.headline`
///   - Gear button: 40×40pt, corner radius 10, Color.primary.opacity(0.07) idle / 0.14 hover,
///     1pt Color.primary.opacity(0.10) stroke, SF Symbol "gear" at 22pt.
///   - Accessibility label: "Settings (Command-Comma)"
///   - Spacing exception `phead`: 10pt top/bottom, 16pt leading, 12pt trailing.
///
/// The gear ACTION is a placeholder using @Environment(\.openSettings).
/// PLAN 35-05: replace with the Q-03 spike-locked mechanism once the Settings scene is wired.
struct PopoverHeader: View {

    @Environment(\.openSettings) private var openSettings
    @State private var isHoveringGear = false

    var body: some View {
        HStack {
            Text("Dicticus")
                .font(.headline)

            Spacer()

            Button {
                // PLAN 35-05: replace with locked Q-03 mechanism
                openSettings()
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 22))
            }
            .buttonStyle(.plain)
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(isHoveringGear ? 0.14 : 0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
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
