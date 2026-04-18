import SwiftUI
import FluidAudio
import KeyboardShortcuts

@main
struct DicticusApp: App {
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var warmupService = ModelWarmupService()
    @StateObject private var hotkeyManager = HotkeyManager()

    // TranscriptionService is created once from the warm FluidAudio ASR and VAD managers.
    // Held here so Phase 3 hotkey wiring can access it without re-initialization.
    // Optional because it cannot be created until warmup completes.
    @State private var transcriptionService: TranscriptionService?

    // CleanupService is created during warmup (ModelWarmupService Step 4).
    // Exposed here for icon state machine (D-14/D-15) and passed to HotkeyManager.
    // Optional because it cannot be created until LLM warmup completes.
    @State private var cleanupService: CleanupService?

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(permissionManager)
                .environmentObject(warmupService)
                .environmentObject(hotkeyManager)
        } label: {
            // Icon state logic per UI-SPEC three-state machine:
            //   recording -> mic.fill (red) per D-09
            //   transcribing -> waveform.circle (pulsing) per D-11
            //   idle/warming -> mic (pulsing during warm-up per D-04)
            // symbolEffect(.pulse) requires macOS 14+ — verified in Research Pattern 1.
            Image(systemName: iconName)
                .symbolEffect(.pulse, isActive: warmupService.isWarming
                    || (transcriptionService?.state == .transcribing)
                    || (cleanupService?.state == .cleaning))
                .foregroundStyle(hotkeyManager.isRecording ? .red : .primary)
                .task {
                    // Check permissions at launch so iconName reads correct state immediately
                    // (prevents mic.slash showing when permissions are already granted but
                    // status is still .pending from init)
                    permissionManager.checkAll()
                    warmupService.warmup()
                }
                .onChange(of: warmupService.isReady) { _, isReady in
                    if isReady,
                       let asrManager = warmupService.asrManagerInstance,
                       let vadManager = warmupService.vadManagerInstance {
                        let service = TranscriptionService(
                            asrManager: asrManager,
                            vadManager: vadManager
                        )
                        transcriptionService = service

                        // Wire CleanupService from warmup (D-07, D-14)
                        let cleanup = warmupService.cleanupServiceInstance
                        cleanupService = cleanup

                        hotkeyManager.setup(
                            transcriptionService: service,
                            warmupService: warmupService,
                            cleanupService: cleanup
                        )
                    }
                }
        }
        .menuBarExtraStyle(.window)
    }

    /// Computed icon name combining permission, warm-up, recording, transcription, and cleanup state.
    ///
    /// State priority (highest first):
    ///   1. Permission missing -> mic.slash (degraded)
    ///   2. Recording -> mic.fill (D-09: red filled mic)
    ///   3. Transcribing -> waveform.circle (D-11/UI-SPEC: audio processing indicator)
    ///   4. AI cleanup -> sparkles (D-14/D-15: LLM processing indicator, pulsing)
    ///   5. Default -> mic (ready or warming, pulse animation handles warming)
    private var iconName: String {
        if !permissionManager.allGranted {
            return "mic.slash"  // Degraded: missing permissions
        }
        if hotkeyManager.isRecording {
            return "mic.fill"  // D-09: Recording in progress
        }
        if let service = transcriptionService, service.state == .transcribing {
            return "waveform.circle"  // D-11/UI-SPEC: Transcription in progress
        }
        // D-14/D-15: AI cleanup in progress — sparkles SF Symbol indicates AI processing
        if let cleanup = cleanupService, cleanup.state == .cleaning {
            return "sparkles"
        }
        return "mic"  // Ready or warming (pulse animation handles warming per Phase 1)
    }
}
