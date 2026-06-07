import SwiftUI
import FluidAudio

@main
struct DicticusApp: App {
    @StateObject private var warmupService = IOSModelWarmupService()
    @ObservedObject private var dictionaryService = DictionaryService.shared
    @ObservedObject private var historyService = HistoryService.shared
    @StateObject private var viewModel = DictationViewModel()

    @State private var transcriptionService: IOSTranscriptionService?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSeenWhatsNewV2") private var hasSeenWhatsNewV2 = false
    @AppStorage("hasSeenOnboardingTour") private var hasSeenOnboardingTour = false
    @State private var showingWhatsNew = false
    @State private var showingOnboardingTour = false

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(warmupService)
                    .environmentObject(dictionaryService)
                    .environmentObject(historyService)
                    .environmentObject(viewModel)
                    .onOpenURL { url in
                        if url.scheme == "dicticus" && url.host == "dictate" {
                            DicticusIPCBridge.defaults?.set(true, forKey: "pendingDictation")
                            NotificationCenter.default.post(name: .startDictation, object: nil)
                        }
                    }
                    .sheet(isPresented: $showingOnboardingTour, onDismiss: {
                        hasSeenOnboardingTour = true
                        if !hasSeenWhatsNewV2 {
                            showingWhatsNew = true
                        }
                    }) {
                        OnboardingTourView()
                    }
                    .sheet(isPresented: $showingWhatsNew, onDismiss: { hasSeenWhatsNewV2 = true }) {
                        WhatsNewView()
                    }
                    .onAppear {
                        SwissDefaultMigration.runIfNeeded()  // D-A3 — first-launch belt-and-suspenders before scenePhase fires
                        let pendingDictation = DicticusIPCBridge.defaults?.bool(forKey: "pendingDictation") ?? false
                        // Guard on viewModel.state as well: checkPendingIntent() may have already
                        // consumed pendingDictation and started dictation before onAppear fires.
                        let noDictation = pendingDictation == false && viewModel.state == .idle
                        if !hasSeenOnboardingTour && noDictation {
                            showingOnboardingTour = true
                        } else if !hasSeenWhatsNewV2 && noDictation {
                            showingWhatsNew = true
                        }
                    }
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .environmentObject(warmupService)
            }
        }
        // D-D1 (Phase 19.5): On scenePhase .active we re-read FS so a download
        // that completed in the background flips hasModels to true here, and a
        // stale-false from a prior session gets corrected.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                SwissDefaultMigration.runIfNeeded()  // D-A3 — must run before any useSwissGerman reader
                // D-D1 (Phase 19.5): Re-read FS on foreground so a download that completed
                // in the background flips hasModels to true here, and a stale-false from a
                // prior session gets corrected.
                if hasCompletedOnboarding {
                    warmupService.checkHasModels()
                    if warmupService.hasModels {
                        warmupService.warmup()
                    }
                }
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
        // Phase 19 Wave 5 — CLEAN-01 / CLEAN-02.
        // Inject the warmed-up CleanupService into DictationViewModel as soon
        // as warmup Step 4 publishes isLlmReady. Mirrors the isReady wiring
        // above. When Step 4 tears down (.failed or cancel), clear the seam
        // so the next dictation falls back to mode=.plain (D-26).
        .onChange(of: warmupService.isLlmReady) { _, isLlmReady in
            if isLlmReady, let cleanup = warmupService.cleanupServiceInstance {
                viewModel.cleanupService = cleanup
            } else if !isLlmReady {
                viewModel.cleanupService = nil
            }
        }
    }
}
