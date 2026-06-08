import SwiftUI
import LaunchAtLogin

/// Settings → General pane.
///
/// Group "Startup & behavior": Launch at login + Media pause toggle.
/// Group "History": Copy-mode (Raw/Polished) picker with footer.
/// Diagnostic: App-Group fallback warning row (shown only when storage is degraded).
/// Last row (Q-01 fallback): Quit Dicticus.
///
/// Relocates controls from SettingsSection per UIORG-04 (bindings unchanged).
struct GeneralPane: View {

    var body: some View {
        Form {
            Section("Startup & behavior") {
                LaunchAtLogin.Toggle("Launch at login")

                MediaPauseToggleRow()
            }

            Section {
                Picker("Copy from history rows", selection: copyModeBinding) {
                    Text("Raw").tag(CleanupCopyMode.raw)
                    Text("Polished").tag(CleanupCopyMode.polished)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Copy mode for history rows")
            } header: {
                Text("History")
            } footer: {
                Text("Raw = unedited ASR. Polished = post-cleanup.")
            }

            if !HistoryService.appGroupAvailable {
                Section {
                    appGroupFallbackWarningRow
                }
            }

            Section {
                Button("Quit Dicticus") {
                    NSApplication.shared.terminate(nil)
                }
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    /// Binding into the cross-platform CleanupCopyMode.current
    /// (UserDefaults.standard, key `cleanupCopyMode`).
    private var copyModeBinding: Binding<CleanupCopyMode> {
        Binding(
            get: { CleanupCopyMode.current },
            set: { CleanupCopyMode.current = $0 }
        )
    }

    private var appGroupFallbackWarningRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("History storage degraded")
                    .font(.callout.weight(.semibold))
                Text("Dicticus is using local app storage for transcription history. Reinstall the app if this is unexpected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
