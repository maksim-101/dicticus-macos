import SwiftUI

@main
struct DicticusApp: App {
    @StateObject private var dictionaryService = DictionaryService.shared
    @StateObject private var historyService = HistoryService.shared
    @StateObject private var textProcessingService = TextProcessingService(cleanupService: nil)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dictionaryService)
                .environmentObject(historyService)
                .environmentObject(textProcessingService)
        }
    }
}
