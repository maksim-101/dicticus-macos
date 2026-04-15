import SwiftUI
import WhisperKit

@main
struct DicticusApp: App {
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var warmupService = ModelWarmupService()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(permissionManager)
                .environmentObject(warmupService)
                .onAppear {
                    // D-03: warm-up starts immediately at app launch, not on first hotkey press.
                    // Called here so warm-up begins as soon as the MenuBarExtra content is first shown.
                    warmupService.warmup()
                }
        } label: {
            // Icon state logic per D-04 (pulsing during warm-up) and D-06 (SF Symbol monochrome).
            // symbolEffect(.pulse) requires macOS 14+ — verified in Research Pattern 1.
            Image(systemName: iconName)
                .symbolEffect(.pulse, isActive: warmupService.isWarming)
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
