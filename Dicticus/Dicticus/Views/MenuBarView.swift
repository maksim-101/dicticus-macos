import SwiftUI

/// Main content of the menu bar dropdown.
///
/// Phase 1 contents per D-05:
/// - Onboarding panel (first launch only, replaces content until dismissed)
/// - Permission status rows (Microphone, Accessibility, Input Monitoring)
/// - Warm-up status row (added by Plan 03)
/// - Quit button
///
/// Permission polling starts here via onAppear so the polling lifecycle is tied
/// to the dropdown being visible, not the app lifetime (avoids timer leaks).
struct MenuBarView: View {
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var warmupService: ModelWarmupService
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

                // Permission rows — always visible per D-05
                VStack(spacing: 4) {
                    PermissionRow(
                        title: "Microphone",
                        status: permissionManager.microphoneStatus,
                        grantAction: {
                            Task { await permissionManager.requestMicrophone() }
                        },
                        settingsURL: SystemSettingsURL.microphone
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

                Button("Quit Dicticus") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding()
        .frame(width: 300)
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
