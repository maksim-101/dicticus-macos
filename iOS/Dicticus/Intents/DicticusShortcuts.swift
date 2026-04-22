import AppIntents

struct DicticusShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DictateIntent(),
            phrases: [
                "Start dictation in \(.applicationName)",
                "Dictate with \(.applicationName)",
                "Begin dictation in \(.applicationName)"
            ],
            shortTitle: "Start Dictation",
            systemImageName: "mic.fill"
        )
    }
}
