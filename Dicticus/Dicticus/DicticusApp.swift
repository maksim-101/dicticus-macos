import SwiftUI
import FluidAudio
import KeyboardShortcuts
import Sparkle

@main
struct DicticusApp: App {
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var warmupService = ModelWarmupService()
    @StateObject private var hotkeyManager = HotkeyManager()
    @StateObject private var modifierListener = ModifierHotkeyListener()
    @StateObject private var updater = SparkleUpdater()

    // TranscriptionService is created once from the warm FluidAudio ASR and VAD managers.
    // Held here so Phase 3 hotkey wiring can access it without re-initialization.
    // Optional because it cannot be created until warmup completes.
    @State private var transcriptionService: TranscriptionService?

    // CleanupService is created during warmup (ModelWarmupService Step 4).
    // Exposed here for icon state machine (D-14/D-15) and passed to HotkeyManager.
    // Optional because it cannot be created until LLM warmup completes.
    @State private var cleanupService: CleanupService?

    // TextProcessingService orchestrates Dictionary, ITN, and CleanupService.
    @State private var textProcessingService: TextProcessingService?

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(permissionManager)
                .environmentObject(warmupService)
                .environmentObject(hotkeyManager)
                .environmentObject(modifierListener)
                .environmentObject(updater)
        } label: {
            // Icon state logic per UI-SPEC three-state machine:
            //   recording -> mic.circle.fill (red) per D-09
            //   transcribing -> waveform.circle (pulsing) per D-11
            //   idle/warming -> mic (pulsing during warm-up per D-04)
            // symbolEffect(.pulse) requires macOS 14+ — verified in Research Pattern 1.
            //
            // macOS renders menu bar icons as template images, stripping color.
            // To show red during recording, we use NSImage with isTemplate=false.
            menuBarIcon
                .symbolEffect(.pulse, isActive: warmupService.isWarming
                    || (hotkeyManager.pipelineState == .transcribing)
                    || (hotkeyManager.pipelineState == .cleaning))
                .task {
                    // Check permissions at launch so iconName reads correct state immediately
                    // (prevents mic.slash showing when permissions are already granted but
                    // status is still .pending from init)
                    permissionManager.checkAll()
                    warmupService.warmup()
                }
                .onChange(of: warmupService.isReady) { _, isReady in
                    if isReady,
                       let asrManager = warmupService.asrManagerInstance,
                       let vadManager = warmupService.vadManagerInstance {
                        let service = TranscriptionService(
                            asrManager: asrManager,
                            vadManager: vadManager
                        )
                        transcriptionService = service

                        // CleanupService may be nil here — LLM loads after ASR.
                        // Plain dictation works immediately; AI cleanup wires later.
                        let cleanup = warmupService.cleanupServiceInstance
                        cleanupService = cleanup
                        
                        let processingService = TextProcessingService(cleanupService: cleanup)
                        textProcessingService = processingService

                        hotkeyManager.setup(
                            transcriptionService: service,
                            warmupService: warmupService,
                            textProcessingService: processingService
                        )

                        // D-08: Wire modifier hotkey listener after ASR is ready so
                        // Fn+Shift / Fn+Control only activate when the app can record.
                        hotkeyManager.setupModifierListener(modifierListener)
                    }
                }
                .onChange(of: warmupService.isLlmReady) { _, ready in
                    // LLM finished loading after ASR was already ready.
                    // Wire CleanupService into HotkeyManager and icon state.
                    if ready, let cleanup = warmupService.cleanupServiceInstance {
                        cleanupService = cleanup
                        
                        let processingService = TextProcessingService(cleanupService: cleanup)
                        textProcessingService = processingService
                        hotkeyManager.textProcessingService = processingService
                        hotkeyManager.cleanupService = cleanup
                    }
                }
        }
        .menuBarExtraStyle(.window)

        // Window for managing the custom dictionary (TEXT-02)
        WindowGroup("Manage Dictionary", id: "dictionary") {
            DictionaryView()
                .environmentObject(DictionaryService.shared)
        }
    }

    /// Menu bar icon view — uses a colored NSImage for recording (isTemplate=false bypasses
    /// macOS template rendering), standard SF Symbol for all other states.
    @ViewBuilder
    private var menuBarIcon: some View {
        if hotkeyManager.pipelineState == .recording {
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            let image = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: "Recording")!
                .withSymbolConfiguration(config)!
            // isTemplate=false prevents macOS from stripping color in menu bar
            let _ = (image.isTemplate = false)
            Image(nsImage: image)
        } else {
            Image(systemName: iconName)
        }
    }

    /// Computed icon name combining permission, warm-up, recording, transcription, and cleanup state.
    ///
    /// State priority (highest first):
    ///   1. Permission missing -> mic.slash (degraded)
    ///   2. Recording -> mic.fill (D-09: red filled mic)
    ///   3. Transcribing -> waveform.circle (D-11/UI-SPEC: audio processing indicator)
    ///   4. AI cleanup -> sparkles (D-14/D-15: LLM processing indicator, pulsing)
    ///   5. Default -> mic (ready or warming, pulse animation handles warming)
    private var iconName: String {
        if !permissionManager.allGranted {
            return "mic.slash"  // Degraded: missing permissions
        }
        switch hotkeyManager.pipelineState {
        case .recording:
            return "mic.circle.fill"  // D-09: Recording in progress — distinct shape at menu bar size
        case .transcribing:
            return "waveform.circle"  // D-11/UI-SPEC: Transcription in progress
        case .cleaning:
            return "sparkles"  // D-14/D-15: AI cleanup in progress
        case .idle:
            return "mic"  // Ready or warming (pulse animation handles warming per Phase 1)
        }
    }
}
