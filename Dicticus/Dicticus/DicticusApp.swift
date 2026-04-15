import SwiftUI
import WhisperKit

@main
struct DicticusApp: App {
    @StateObject private var permissionManager = PermissionManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(permissionManager)
        } label: {
            // mic.slash signals degraded state when any permission is missing (D-06)
            Image(systemName: permissionManager.allGranted ? "mic" : "mic.slash")
        }
        .menuBarExtraStyle(.window)
    }
}
