import SwiftUI
import FluidAudio

@main
struct DicticusApp: App {
    @StateObject private var warmupService = IOSModelWarmupService()
    @StateObject private var dictionaryService = DictionaryService.shared
    @StateObject private var historyService = HistoryService.shared
    @StateObject private var viewModel = DictationViewModel()

    @State private var transcriptionService: IOSTranscriptionService?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSeenWhatsNewV2") private var hasSeenWhatsNewV2 = false
    @State private var showingWhatsNew = false

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(warmupService)
                    .environmentObject(dictionaryService)
                    .environmentObject(historyService)
                    .environmentObject(viewModel)
                    .sheet(isPresented: $showingWhatsNew) {
                        WhatsNewView()
                            .onDisappear {
                                hasSeenWhatsNewV2 = true
                            }
                    }
                    .onAppear {
                        if !hasSeenWhatsNewV2 {
                            showingWhatsNew = true
                        }
                    }
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .environmentObject(warmupService)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Only auto-warmup if onboarding is done and models exist
            if newPhase == .active && hasCompletedOnboarding && warmupService.hasModels {
                warmupService.warmup()
            }
        }
        .onChange(of: warmupService.isReady) { _, isReady in
            if isReady,
               let asrManager = warmupService.asrManagerInstance,
               let vadManager = warmupService.vadManagerInstance {
                let service = IOSTranscriptionService(
                    asrManager: asrManager,
                    vadManager: vadManager
                )
                transcriptionService = service
                viewModel.transcriptionService = service
            }
        }
    }
}
