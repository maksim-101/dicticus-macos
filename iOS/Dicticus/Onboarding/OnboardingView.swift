import SwiftUI
@preconcurrency import AVFoundation

struct OnboardingView: View {
    @EnvironmentObject var warmupService: IOSModelWarmupService
    @Binding var hasCompletedOnboarding: Bool
    
    @State private var currentPage = 0
    @State private var micPermissionGranted = false
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                welcomeStep.tag(0)
                micStep.tag(1)
                downloadStep.tag(2)
                finalStep.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation { currentPage -= 1 }
                    }
                    .buttonStyle(.borderless)
                }
                
                Spacer()
                
                if currentPage < 3 {
                    Button(nextButtonLabel) {
                        handleNext()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isNextDisabled)
                } else {
                    Button("Start Using Dicticus") {
                        hasCompletedOnboarding = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .onAppear {
            checkInitialPermissions()
        }
    }
    
    // MARK: - Steps
    
    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            Text("Your Privacy Matters")
                .font(.title).bold()
            
            Text("Dicticus transcribes your voice entirely on this device. Your audio never leaves your iPhone, and no data is sent to the cloud.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Safe. Private. Fast.")
                .font(.subheadline).italic()
                .foregroundColor(.secondary)
        }
    }
    
    private var micStep: some View {
        VStack(spacing: 20) {
            Image(systemName: micPermissionGranted ? "mic.fill" : "mic.slash.fill")
                .font(.system(size: 80))
                .foregroundColor(micPermissionGranted ? .green : .orange)
            
            Text("Microphone Access")
                .font(.title).bold()
            
            Text("To transcribe your speech, Dicticus needs permission to use the microphone.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if !micPermissionGranted {
                Button("Enable Microphone") {
                    requestMicPermission()
                }
                .buttonStyle(.bordered)
            } else {
                Text("Permission Granted")
                    .foregroundColor(.green)
                    .font(.headline)
            }
        }
    }
    
    private var downloadStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
                .symbolEffect(.pulse, isActive: warmupService.isWarming)
            
            Text("Download ASR Model")
                .font(.title).bold()
            
            Text("Dicticus uses a high-accuracy neural model for transcription. This requires a one-time download of approximately 2.7 GB.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if !warmupService.hasModels && !warmupService.isWarming {
                Button("Download Now (Wi-Fi Recommended)") {
                    warmupService.warmup()
                }
                .buttonStyle(.bordered)
            } else if warmupService.isWarming {
                VStack(spacing: 12) {
                    ProgressView(value: warmupService.downloadProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .padding(.horizontal, 40)
                    
                    Text(warmupService.downloadStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(warmupService.downloadProgress * 100))%")
                        .font(.caption2).monospacedDigit()
                        .foregroundColor(.accentColor)
                }
                .padding()
            } else if warmupService.hasModels {
                Text("Model Ready")
                    .foregroundColor(.green)
                    .font(.headline)
            }
            
            if let error = warmupService.error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
    
    private var finalStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("You're All Set!")
                .font(.title).bold()
            
            VStack(alignment: .leading, spacing: 12) {
                Label("Dictate via the app or Siri.", systemImage: "mic")
                Label("Text is automatically copied to clipboard.", systemImage: "doc.on.doc")
                Label("Setup Action Button for instant access.", systemImage: "iphone.gen3")
            }
            .padding()
            
            if UIDevice.current.userInterfaceIdiom == .phone {
                Button(action: openActionButtonSettings) {
                    Label("Configure Action Button", systemImage: "gearshape.2.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    
    // MARK: - Logic
    
    private func openActionButtonSettings() {
        // Direct link to Action Button settings (iOS 17+)
        if let url = URL(string: "App-Prefs:root=Action_Button") {
            UIApplication.shared.open(url)
        }
    }
    
    private var nextButtonLabel: String {
        if currentPage == 1 && !micPermissionGranted { return "Skip" }
        if currentPage == 2 && !warmupService.hasModels { return "Download First" }
        return "Next"
    }
    
    private var isNextDisabled: Bool {
        if currentPage == 2 && !warmupService.hasModels && !warmupService.isWarming { return true }
        if currentPage == 2 && warmupService.isWarming { return true }
        return false
    }
    
    private func handleNext() {
        withAnimation { currentPage += 1 }
    }
    
    private func checkInitialPermissions() {
        let status = AVAudioApplication.shared.recordPermission
        micPermissionGranted = (status == .granted)
    }
    
    private func requestMicPermission() {
        Task {
            let granted = await AVAudioApplication.requestRecordPermission()
            await MainActor.run {
                self.micPermissionGranted = granted
                if granted {
                    withAnimation { currentPage += 1 }
                }
            }
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
        .environmentObject(IOSModelWarmupService())
}
