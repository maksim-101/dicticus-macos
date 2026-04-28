import SwiftUI
import Sparkle

/// Main content of the menu bar dropdown.
///
/// Phase 1 contents per D-05:
/// - Onboarding panel (first launch only, replaces content until dismissed)
/// - Permission status rows (Microphone, Accessibility)
/// - Warm-up status row
///
/// Phase 3 additions per D-20/D-21/D-22:
/// - Hotkey configuration section (KeyboardShortcuts recorder views)
/// - Last transcription preview with copy button
///
/// Phase 5 additions per D-02/D-03/D-09/D-10/D-11:
/// - Settings section above Quit with LaunchAtLogin toggle and modifier hotkey pickers
///
/// Permission polling starts here via onAppear so the polling lifecycle is tied
/// to the dropdown being visible, not the app lifetime (avoids timer leaks).
struct MenuBarView: View {
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var warmupService: ModelWarmupService
    @EnvironmentObject var hotkeyManager: HotkeyManager
    @EnvironmentObject var modifierListener: ModifierHotkeyListener
    @EnvironmentObject var updater: SparkleUpdater
    @Environment(\.openWindow) private var openWindow
    @State private var showOnboarding = false
    @State private var showMultiCopyDetail = false

    var body: some View {
        VStack(spacing: 8) {
            if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
                    .environmentObject(permissionManager)
            } else {
                // D-05: Repair banner — sticky when AX is denied post-onboarding,
                // OR when KeyboardShortcuts registration silently failed (D-04 layer 2).
                if (permissionManager.accessibilityStatus == .denied && permissionManager.hasCompletedOnboarding)
                    || hotkeyManager.registrationFailed {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Hotkeys disabled — Accessibility permission missing.")
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Button("Repair") {
                                SystemSettingsURL.open(SystemSettingsURL.accessibility)
                            }
                            .controlSize(.small)
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        Text("Relaunch Dicticus after granting.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 24)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(6)

                    Divider()
                }

                // D-07: Multi-copy warning — shown when launch-only mdfind returned > 1 path.
                if permissionManager.multipleDicticusCopies.count > 1 {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("Multiple Dicticus copies detected — may cause permission issues.")
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Button(showMultiCopyDetail ? "Hide" : "Show") {
                                showMultiCopyDetail.toggle()
                            }
                            .controlSize(.small)
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        if showMultiCopyDetail {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(permissionManager.multipleDicticusCopies, id: \.self) { url in
                                    Text(url.path)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Text("Run scripts/install-local.sh to consolidate.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 2)
                            }
                            .padding(.leading, 24)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(6)

                    Divider()
                }

                // Warm-up status row — hidden after models are ready (UI-SPEC Model Warm-up Row)
                WarmupRow()
                    .environmentObject(warmupService)

                if warmupService.showWarmupRow {
                    Divider()
                }

                // Permission rows — visible only while at least one is not .granted (D-11).
                // Quieter steady-state UI; loud only when action is needed.
                if !permissionManager.allGranted {
                    VStack(spacing: 4) {
                        PermissionRow(
                            title: "Microphone",
                            status: permissionManager.microphoneStatus,
                            grantAction: {
                                Task { await permissionManager.requestMicrophone() }
                            },
                            settingsURL: SystemSettingsURL.microphone,
                            showRestartHint: true
                        )
                        PermissionRow(
                            title: "Accessibility",
                            status: permissionManager.accessibilityStatus,
                            grantAction: { permissionManager.requestAccessibility() },
                            settingsURL: SystemSettingsURL.accessibility
                        )
                        PermissionRow(
                            title: "Input Monitoring",
                            status: permissionManager.inputMonitoringStatus,
                            grantAction: { permissionManager.requestInputMonitoring() },
                            settingsURL: SystemSettingsURL.inputMonitoring
                        )
                    }

                    Divider()
                }

                // AI Cleanup model info — always visible
                AiCleanupInfoView()
                    .environmentObject(warmupService)
                SwissGermanToggleRow()       // Phase 19.5 D-A2

                Divider()

                // D-20: Hotkey configuration section — always visible
                HotkeySettingsView()

                Divider()

                // D-21: Last transcription preview — hidden when no transcription yet
                LastTranscriptionView(text: hotkeyManager.lastTranscriptionText)

                // Only show divider if last transcription section is visible
                if hotkeyManager.lastTranscriptionText != nil {
                    Divider()
                }

                Button(action: {
                    openWindow(id: "history")
                    NSApp.activate(ignoringOtherApps: true)
                }) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("Transcription History\u{2026}")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.vertical, 4)

                Divider()

                // D-03: Settings section above Quit — launch at login + modifier hotkey pickers
                SettingsSection(
                    plainDictationCombo: $modifierListener.plainDictationCombo,
                    cleanupCombo: $modifierListener.cleanupCombo
                )

                Divider()

#if DEBUG
                Button("Cleanup Spike (Debug)…") {
                    openWindow(id: "cleanup-spike")
                }
#endif

                Button("Check for Updates...") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)

                Button("Quit Dicticus") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding()
        .frame(width: 360)
        .onAppear {
            // Start permission polling so changes in System Settings are detected live
            permissionManager.startPolling()

            // Load persisted onboarding state and show flow if not yet completed
            permissionManager.loadOnboardingState()

            // D-07: launch-only mdfind probe for stale Dicticus.app copies on disk
            permissionManager.checkMultipleInstalls()

            if !permissionManager.hasCompletedOnboarding {
                showOnboarding = true
            }
        }
    }
}
