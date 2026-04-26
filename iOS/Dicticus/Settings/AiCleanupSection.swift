import SwiftUI

/// Phase 19 Wave 4: AI Cleanup + Swiss German Settings UI.
///
/// Two orthogonal toggles plus an inline GGUF download panel. Hidden behind an
/// explainer on RAM-ineligible devices (D-03). Inline — not modal — per D-10.
///
/// **Persistence (D-08):** Toggles read/write the `group.com.dicticus` App Group
/// UserDefaults suite so the keyboard extension (if revived) and warmup service
/// see the same values. Keys: `aiCleanupEnabled`, `useSwissGerman`. Both default
/// `false`.
///
/// **Downloader (D-10):** `@StateObject private var downloader` is ephemeral —
/// it only exists while the Settings screen is on-screen. The warmup service's
/// Step 4 (Wave 3) reads the *cached file* on the next app launch. When the user
/// dismisses Settings mid-download, the in-flight task is cancelled and the user
/// must retry via the inline panel; this is acceptable scope per the phase-19
/// threat register (T-19-05-03).
///
/// **RAM gating (D-03 / D-20):** When `IOSModelWarmupService.isAiCleanupSupported`
/// is `false` the AI Cleanup toggle is *replaced* by a disabled explainer row; the
/// Swiss German toggle remains visible because it operates on plain dictation
/// independently of LLM availability (D-15).
struct AiCleanupSection: View {
    @EnvironmentObject var warmupService: IOSModelWarmupService

    /// Ephemeral downloader — only alive while this view is in the hierarchy.
    @StateObject private var downloader = IOSModelDownloadService()

    /// Local mirror of on-disk cache state so UI refreshes when the downloader
    /// transitions to `.completed`.
    @State private var isModelCached: Bool = IOSModelDownloadService.isModelCached()

    // MARK: - AppGroup suite (D-08)

    private static let appGroupDefaults = UserDefaults(suiteName: "group.com.dicticus")!

    private func appGroupBinding(_ key: String, default defaultValue: Bool) -> Binding<Bool> {
        Binding(
            get: {
                let defaults = Self.appGroupDefaults
                return defaults.object(forKey: key) == nil ? defaultValue : defaults.bool(forKey: key)
            },
            set: { Self.appGroupDefaults.set($0, forKey: key) }
        )
    }

    // MARK: - Body

    var body: some View {
        Section {
            if IOSModelWarmupService.isAiCleanupSupported {
                aiCleanupToggle
                if aiCleanupEnabledValue {
                    statusRow
                    if !isModelCached {
                        downloadPanel
                    }
                }
            } else {
                unsupportedRow
            }

            // Swiss toggle is ALWAYS visible (D-15) — orthogonal to AI Cleanup
            // and operates on plain dictation (\u{00DF} \u{2192} ss).
            swissGermanToggle
        } header: {
            Text("AI Cleanup")
        } footer: {
            Text("Gemma 4 E2B (Q4_K_M) runs entirely on-device \u{2014} no audio is sent to any server. Swiss German spelling applies to plain dictation independently of AI Cleanup.")
        }
        .onChange(of: downloader.state) { _, newState in
            // Refresh cached-state when download completes so the panel swaps to
            // the "relaunch to enable" hint.
            if newState == .completed {
                isModelCached = IOSModelDownloadService.isModelCached()
            }
        }
    }

    // MARK: - Subviews

    private var aiCleanupEnabledValue: Bool {
        let defaults = Self.appGroupDefaults
        return defaults.object(forKey: "aiCleanupEnabled") == nil ? false : defaults.bool(forKey: "aiCleanupEnabled")
    }

    private var aiCleanupToggle: some View {
        Toggle(isOn: appGroupBinding("aiCleanupEnabled", default: false)) {
            Label("AI Cleanup", systemImage: "sparkles")
        }
    }

    private var swissGermanToggle: some View {
        Toggle(isOn: appGroupBinding("useSwissGerman", default: true)) {
            Label("Swiss German Spelling", systemImage: "character.bubble")
        }
    }

    private var unsupportedRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("AI Cleanup", systemImage: "sparkles")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Unavailable")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            Text("Requires iPhone 14 or newer (at least 5 GB of RAM).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Status row — reflects Wave 3's `llmStatus` / `isLlmReady` when the toggle is ON.
    @ViewBuilder
    private var statusRow: some View {
        switch warmupService.llmStatus {
        case .idle:
            if isModelCached {
                // Cached but not yet loaded — next launch will warm up Step 4.
                HStack {
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundStyle(.orange)
                    Text("Relaunch Dicticus to enable AI Cleanup")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            // else: .idle with no cache → download panel shows below; no extra row.
        case .loading:
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text(warmupService.llmStatus.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .ready:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("AI Cleanup Ready")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .failed(let reason):
            HStack(alignment: .top) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Download panel (D-10: inline, not modal)

    @ViewBuilder
    private var downloadPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch downloader.state {
            case .idle:
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Download Required")
                            .font(.subheadline.weight(.medium))
                        Text("Gemma 4 E2B \u{2248} 3 GB. Wi-Fi recommended.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Button {
                    downloader.start()
                } label: {
                    Label("Download Model", systemImage: "arrow.down.to.line")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

            case .downloading:
                ProgressView(value: downloader.progress)
                HStack {
                    Text("\(Int(downloader.progress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Self.formatBytesPerSec(downloader.bytesPerSec))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Button {
                    downloader.pause()
                } label: {
                    Label("Pause", systemImage: "pause.circle")
                }
                .buttonStyle(.bordered)

            case .paused:
                ProgressView(value: downloader.progress)
                Text("Paused \u{00B7} \(Int(downloader.progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    downloader.resume()
                } label: {
                    Label("Resume", systemImage: "play.circle")
                }
                .buttonStyle(.borderedProminent)

            case .completed:
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Download Complete \u{2014} relaunch Dicticus to enable")
                        .font(.subheadline)
                }

            case .failed(let reason):
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button {
                    downloader.start()
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private static func formatBytesPerSec(_ bps: Double) -> String {
        guard bps > 0 else { return "" }
        let mbps = bps / (1024.0 * 1024.0)
        return String(format: "%.1f MB/s", mbps)
    }
}

#Preview {
    NavigationStack {
        List {
            AiCleanupSection()
        }
        .navigationTitle("Settings")
    }
    .environmentObject(IOSModelWarmupService())
}
