import SwiftUI
import WhisperKit

@main
struct DicticusApp: App {
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            Image(systemName: "mic")
        }
        .menuBarExtraStyle(.window)
    }
}
