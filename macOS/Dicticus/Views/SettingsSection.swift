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

            // Phase 20.04 ACT-4-RESILIENCE: parity warning row.
            // macOS rarely hits this path (App Group resolution is more reliable
            // on macOS than iOS) but cross-platform-parity convention requires
            // symmetric surfacing. Reads the static flag set during HistoryService
            // init — immutable for the process lifetime so no observation needed.
            if !HistoryService.appGroupAvailable {
                appGroupFallbackWarningRow
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                Divider()
            }

            // Launch at Login toggle — SMAppService is source of truth, not UserDefaults (D-02/D-04)
            LaunchAtLogin.Toggle("Launch at Login")
                .padding(.horizontal)
                .padding(.vertical, 4)

            // Phase 30: PTT media auto-pause toggle — macOS only, UserDefaults.standard
            MediaPauseToggleRow()

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

            // Phase 20.05 ACT-3-VISIBILITY: Copy mode parity row.
            // Writes the same UserDefaults key (`cleanupCopyMode`) consumed by
            // every per-row Copy button across iOS + macOS.
            Text("History")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 4)

            HStack {
                Text("Copy from rows")
                    .font(.body)
                Spacer()
                Picker("", selection: copyModeBinding) {
                    Text("Raw").tag(CleanupCopyMode.raw)
                    Text("Polished").tag(CleanupCopyMode.polished)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 180)
                .accessibilityLabel("Copy mode for history rows")
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

            Text("Raw = unedited ASR output. Polished = post-cleanup text.")
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

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text(AppBuildInfo.displayVersion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let date = AppBuildInfo.buildDate {
                    Text("Built \(date)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(AppBuildInfo.recentChanges, id: \.self) { note in
                            Text(note)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } label: {
                    Text("Recent Changes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Link("Full Changelog", destination: AppBuildInfo.releasesURL)
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }

    /// Phase 20.05 ACT-3-VISIBILITY: Binding into the cross-platform
    /// `CleanupCopyMode.current` (UserDefaults.standard, key `cleanupCopyMode`).
    /// Read by every per-row Copy button on both platforms.
    private var copyModeBinding: Binding<CleanupCopyMode> {
        Binding(
            get: { CleanupCopyMode.current },
            set: { CleanupCopyMode.current = $0 }
        )
    }

    /// Phase 20.04 ACT-4-RESILIENCE: macOS parity diagnostic row.
    /// Shown only when HistoryService fell back to per-app applicationSupport
    /// storage. macOS-specific copy: omits the keyboard-extension reference
    /// (no equivalent on macOS — the keyboard scenario is iOS-only).
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
