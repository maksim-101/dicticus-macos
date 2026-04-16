import SwiftUI
import WhisperKit

@main
struct DicticusApp: App {
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var warmupService = ModelWarmupService()

    // D-10, D-13: TranscriptionService is created once from the warm WhisperKit instance.
    // Held here so Phase 3 hotkey wiring can access it without re-initialization.
    // Optional because it cannot be created until warmup completes.
    @State private var transcriptionService: TranscriptionService?

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(permissionManager)
                .environmentObject(warmupService)
                .onChange(of: warmupService.isReady) { _, isReady in
                    if isReady, let whisperKit = warmupService.whisperKitInstance {
                        transcriptionService = TranscriptionService(whisperKit: whisperKit)
                    }
                }
        } label: {
            // Icon state logic per D-04 (pulsing during warm-up) and D-06 (SF Symbol monochrome).
            // symbolEffect(.pulse) requires macOS 14+ — verified in Research Pattern 1.
            Image(systemName: iconName)
                .symbolEffect(.pulse, isActive: warmupService.isWarming)
                .task {
                    // D-03: warm-up starts at app launch (label renders immediately),
                    // not on first popover open. Guard in warmup() prevents duplicate calls.
                    warmupService.warmup()
                }
        }
        .menuBarExtraStyle(.window)
    }

    /// Computed icon name combining permission and warm-up state.
    /// - mic.slash: any permission missing (degraded state, D-06)
    /// - mic: ready or warming up (pulse animation communicates warm-up, D-04)
    private var iconName: String {
        if !permissionManager.allGranted {
            return "mic.slash"  // Degraded: missing permissions
        }
        return "mic"  // Ready or warming (pulse animation handles warming visual per D-04)
    }
}
