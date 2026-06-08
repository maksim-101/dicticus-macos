import SwiftUI

/// Root container for the ⌘, Settings window.
///
/// Presents 4 panes in order per UI-SPEC §macOS — Settings Window:
///   Hotkeys (keyboard) / AI Cleanup (sparkles) / General (gear) / About (info.circle)
///
/// Receives the same @EnvironmentObjects the popover uses, injected by the
/// Settings { } scene in DicticusApp.
struct SettingsRoot: View {
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var warmupService: ModelWarmupService
    @EnvironmentObject var hotkeyManager: HotkeyManager
    @EnvironmentObject var modifierListener: ModifierHotkeyListener
    @EnvironmentObject var updater: SparkleUpdater

    var body: some View {
        TabView {
            HotkeysPane()
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }
                .accessibilityLabel("Hotkeys settings pane")

            AiCleanupPane()
                .tabItem {
                    Label("AI Cleanup", systemImage: "sparkles")
                }
                .accessibilityLabel("AI Cleanup settings pane")

            GeneralPane()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .accessibilityLabel("General settings pane")

            AboutPane()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .accessibilityLabel("About settings pane")
        }
        .frame(minWidth: 400)
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }
}
