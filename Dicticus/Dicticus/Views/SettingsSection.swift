import SwiftUI
import LaunchAtLogin

/// Settings section for the menu bar dropdown.
///
/// Shows Launch at Login toggle and modifier hotkey pickers.
/// Per D-02/D-03: Settings section appears above Quit with launch-at-login defaulting to off.
/// Per D-09/D-10/D-11: Modifier hotkey pickers offer Fn+Shift, Fn+Control, Fn+Option.
/// Per UI-SPEC: Matches HotkeySettingsView row layout (HStack + Spacer + control).
struct SettingsSection: View {

    /// Binding to the plain dictation modifier combo — sourced from ModifierHotkeyListener.
    @Binding var plainDictationCombo: ModifierCombo

    /// Binding to the AI cleanup modifier combo — sourced from ModifierHotkeyListener.
    @Binding var cleanupCombo: ModifierCombo

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 4)

            // Launch at Login toggle — SMAppService is source of truth, not UserDefaults (D-02/D-04)
            LaunchAtLogin.Toggle("Launch at Login")
                .padding(.horizontal)
                .padding(.vertical, 4)

            Divider()

            Text("Modifier Hotkeys")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 4)

            // Plain Dictation modifier combo picker — D-10/D-11
            HStack {
                Text("Plain Dictation")
                    .font(.body)
                Spacer()
                Picker("", selection: $plainDictationCombo) {
                    ForEach(ModifierCombo.allCases) { combo in
                        Text(combo.displayName).tag(combo)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityLabel("Plain dictation modifier hotkey")
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

            // AI Cleanup modifier combo picker — D-11
            HStack {
                Text("AI Cleanup")
                    .font(.body)
                Spacer()
                Picker("", selection: $cleanupCombo) {
                    ForEach(ModifierCombo.allCases) { combo in
                        Text(combo.displayName).tag(combo)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityLabel("AI Cleanup modifier hotkey")
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

            // External keyboard note — .caption in .secondary per UI-SPEC copywriting contract
            Text("Fn-based hotkeys require a Mac keyboard with an Fn key. Standard hotkeys above work on all keyboards.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Button(action: {
                openWindow(id: "dictionary")
                NSApp.activate(ignoringOtherApps: true)
            }) {
                HStack {
                    Image(systemName: "book.pages")
                    Text("Manage Custom Dictionary\u{2026}")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }
}
