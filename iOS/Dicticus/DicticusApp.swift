import SwiftUI
import FluidAudio
import ActivityKit
#if DEBUG
import os
private let diagLog = Logger(subsystem: "com.dicticus.diag", category: "DicticusApp")
#endif

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

    init() {
        // ADDENDUM A: On launch, reconcile any orphaned Live Activities left by a prior process
        // that terminated mid-recording (crash, SIGKILL, memory pressure). Without this,
        // phantom "Recording…" banners stack indefinitely on the lock screen.
        // Also reset the isRecording App Group flag — if it's stale-true from a prior process,
        // DictateIntent toggle-to-stop would misfire (D-01a corollary).
        #if DEBUG
        let proc = ProcessInfo.processInfo.processName
        let bundle = Bundle.main.bundleIdentifier ?? "unknown"
        let staleIsRecording = DicticusIPCBridge.defaults?.bool(forKey: DicticusIPCBridge.Key.isRecording) ?? false
        let activityCount = Activity<DictationAttributes>.activities.count
        diagLog.debug("[DicticusApp.init] process=\(proc, privacy: .public) bundle=\(bundle, privacy: .public) staleIsRecording=\(staleIsRecording, privacy: .public) orphanedActivities=\(activityCount, privacy: .public)")
        #endif
        Task { @MainActor in
            let activities = Activity<DictationAttributes>.activities
            #if DEBUG
            diagLog.debug("[DicticusApp.init reconcile] ending \(activities.count, privacy: .public) orphaned activities")
            #endif
            for activity in activities {
                await activity.end(
                    ActivityContent(
                        state: DictationAttributes.ContentState(isRecording: false, startedAt: Date.now),
                        staleDate: nil
                    ),
                    dismissalPolicy: .immediate
                )
            }
        }
        DicticusIPCBridge.defaults?.set(false, forKey: DicticusIPCBridge.Key.isRecording)
    }

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
                    // On foreground, decide between delivering a pending transcript and starting
                    // a new recording session. These two actions MUST NOT run in the same cycle
                    // (delivery sets state=.transcribing; startDictation() guards on state==.idle).
                    // handleForeground() owns the branch: when pendingDictation is set the new
                    // session wins and delivery is deferred; otherwise delivery runs first (D-02/D-05).
                    let pendingDictation = DicticusIPCBridge.defaults?.bool(forKey: "pendingDictation") ?? false
                    #if DEBUG
                    let pendingUUID = DicticusIPCBridge.defaults?.string(forKey: DicticusIPCBridge.Key.pendingTranscriptUUID) ?? ""
                    diagLog.debug("[DicticusApp.scenePhase.active] pendingDictation=\(pendingDictation, privacy: .public) vmState=\(String(describing: viewModel.state), privacy: .public) pendingTranscriptUUID=\(pendingUUID.isEmpty ? "none" : "set", privacy: .public)")
                    #endif
                    Task { @MainActor in
                        await viewModel.handleForeground(pendingDictation: pendingDictation)
                    }
                }
            } else if newPhase == .background {
                // Background recording continues — do not finalize.
                // UIBackgroundModes:audio keeps the AVAudioSession alive.
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
                // Retry deferred delivery: if .active fired before LLM was ready, the pending
                // transcript was delivered as plain text (correct but un-cleaned). Now that the
                // LLM is ready AND a pending UUID still exists, re-deliver with AI cleanup.
                // deliverPendingTranscriptsIfNeeded() checks for the UUID; it's a no-op if already cleared.
                if hasCompletedOnboarding,
                   let pending = DicticusIPCBridge.defaults?.string(forKey: DicticusIPCBridge.Key.pendingTranscriptUUID),
                   !pending.isEmpty {
                    Task { @MainActor in
                        await viewModel.deliverPendingTranscriptsIfNeeded()
                    }
                }
            } else if !isLlmReady {
                viewModel.cleanupService = nil
            }
        }
        // WR-03: Re-present the tour when Settings resets hasSeenOnboardingTour.
        // oldValue guard ensures the initial false default does NOT auto-trigger;
        // only an explicit true→false transition (Settings button) shows the tour.
        .onChange(of: hasSeenOnboardingTour) { oldValue, newValue in
            if oldValue == true && newValue == false {
                showingOnboardingTour = true
            }
        }
    }
}
