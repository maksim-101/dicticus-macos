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
                ProgressView()
                    .padding()
                Text("Downloading and compiling\u{2026}")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
        }
    }
    
    // MARK: - Logic
    
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
