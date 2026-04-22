import SwiftUI

struct DictationView: View {
    @EnvironmentObject var viewModel: DictationViewModel
    @EnvironmentObject var warmupService: IOSModelWarmupService
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: iconName)
                    .font(.system(size: 64))
                    .foregroundStyle(viewModel.state == .recording ? .red : .primary)
                    .symbolEffect(.pulse, isActive: warmupService.isWarming || viewModel.state == .transcribing)
                    .accessibilityLabel(iconName == "mic" ? "Microphone" : "Recording status")
                    .accessibilityAddTraits(.isImage)

                Text(statusLabel)
                    .font(.headline)
                    .accessibilityLabel("Status")
                    .accessibilityValue(statusLabel)

                Button(action: handleButton) {
                    Text(buttonLabel)
                        .frame(minWidth: 160)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.state == .recording ? .red : .accentColor)
                .disabled(!warmupService.isReady || viewModel.state == .transcribing || viewModel.state == .preparingLiveActivity)
                .accessibilityLabel(buttonLabel)
                .accessibilityHint(viewModel.state == .recording ? "Stops recording and transcribes" : "Starts a new dictation")

                if let result = viewModel.lastResult {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Copied to clipboard:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(result)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }

                if let error = viewModel.error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(warmupService)
            }
            .onChange(of: viewModel.state) { _, newState in
                if newState == .recording {
                    showingSettings = false
                }
            }
        }
    }

    private var iconName: String {
        if warmupService.isWarming { return "arrow.down.circle" }
        switch viewModel.state {
        case .idle:                  return "mic"
        case .preparingLiveActivity: return "mic"
        case .recording:             return "mic.circle.fill"
        case .transcribing:          return "waveform.circle"
        }
    }

    private var statusLabel: String {
        if warmupService.isWarming { return "Downloading ASR Models (2.7GB)\u{2026}" }
        if let error = warmupService.error { return error }
        switch viewModel.state {
        case .idle:                  return "Ready"
        case .preparingLiveActivity: return "Starting\u{2026}"
        case .recording:             return "Recording\u{2026}"
        case .transcribing:          return "Transcribing\u{2026}"
        }
    }

    private var buttonLabel: String {
        viewModel.state == .recording ? "Stop" : "Start Dictation"
    }

    private func handleButton() {
        Task {
            if viewModel.state == .idle {
                await viewModel.startDictation()
            } else if viewModel.state == .recording {
                await viewModel.stopDictation()
            }
        }
    }
}

#Preview {
    DictationView()
        .environmentObject(DictationViewModel())
        .environmentObject(IOSModelWarmupService())
}
