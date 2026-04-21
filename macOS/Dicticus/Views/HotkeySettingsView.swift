import SwiftUI
import KeyboardShortcuts

/// Hotkey configuration section for the menu bar dropdown.
///
/// Per D-14: Hotkeys are user-configurable from the start.
/// Per D-20: KeyboardShortcuts recorder views for both hotkeys.
/// Per UI-SPEC: Section heading "Hotkeys" (.headline, semibold), recorder rows
/// match PermissionRow horizontal padding pattern.
struct HotkeySettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hotkeys")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 4)

            VStack(spacing: 4) {
                HStack {
                    Text("Plain Dictation")
                        .font(.body)
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .plainDictation)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)

                HStack {
                    Text("AI Cleanup")
                        .font(.body)
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .aiCleanup)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }
}
