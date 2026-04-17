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
                .symbolEffect(.pulse, isActive: warmupService.isWarming || (transcriptionService?.state == .transcribing))
                .foregroundStyle(hotkeyManager.isRecording ? .red : .primary)
                .task {
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
                        hotkeyManager.setup(transcriptionService: service, warmupService: warmupService)
                    }
                }
        }
        .menuBarExtraStyle(.window)
    }

    /// Computed icon name combining permission, warm-up, recording, and transcription state.
    ///
    /// State priority (highest first):
    ///   1. Permission missing -> mic.slash (degraded)
    ///   2. Recording -> mic.fill (D-09: red filled mic)
    ///   3. Transcribing -> waveform.circle (D-11/UI-SPEC: audio processing indicator)
    ///   4. Default -> mic (ready or warming, pulse animation handles warming)
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
        return "mic"  // Ready or warming (pulse animation handles warming per Phase 1)
    }
}
