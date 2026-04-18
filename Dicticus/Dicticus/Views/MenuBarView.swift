import SwiftUI

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
    @State private var showOnboarding = false

    var body: some View {
        VStack(spacing: 8) {
            if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
                    .environmentObject(permissionManager)
            } else {
                // Warm-up status row — hidden after models are ready (UI-SPEC Model Warm-up Row)
                WarmupRow()
                    .environmentObject(warmupService)

                if warmupService.showWarmupRow {
                    Divider()
                }

                // Permission rows — always visible per D-05/D-22
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
                }

                Divider()

                // AI Cleanup model info — always visible
                AiCleanupInfoView()
                    .environmentObject(warmupService)

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

                // D-03: Settings section above Quit — launch at login + modifier hotkey pickers
                SettingsSection(
                    plainDictationCombo: $modifierListener.plainDictationCombo,
                    cleanupCombo: $modifierListener.cleanupCombo
                )

                Divider()

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
            if !permissionManager.hasCompletedOnboarding {
                showOnboarding = true
            }
        }
    }
}
