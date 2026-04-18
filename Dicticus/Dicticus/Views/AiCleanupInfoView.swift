import SwiftUI

/// AI Cleanup model info section in the menu bar dropdown.
///
/// Shows the current LLM model name, status (downloading/loading/ready/failed),
/// and a progress indicator during download or loading.
struct AiCleanupInfoView: View {
    @EnvironmentObject var warmupService: ModelWarmupService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Cleanup")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 4)

            VStack(spacing: 4) {
                // Model name row
                HStack {
                    Text("Model")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Gemma 3 1B (Q4_0)")
                        .font(.body)
                }
                .padding(.horizontal)
                .padding(.vertical, 2)

                // Status row
                HStack {
                    Text("Status")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Spacer()

                    if warmupService.llmStatus.isActive {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                    }

                    statusLabel
                }
                .padding(.horizontal)
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch warmupService.llmStatus {
        case .idle:
            Text(warmupService.llmStatus.label)
                .font(.body)
                .foregroundColor(.secondary)
        case .downloading, .loading:
            Text(warmupService.llmStatus.label)
                .font(.body)
                .foregroundColor(.orange)
        case .ready:
            Text(warmupService.llmStatus.label)
                .font(.body)
                .foregroundColor(.green)
        case .failed:
            Text(warmupService.llmStatus.label)
                .font(.body)
                .foregroundColor(.red)
        }
    }
}
