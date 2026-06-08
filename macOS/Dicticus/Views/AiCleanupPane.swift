import SwiftUI

/// Settings → AI Cleanup pane.
///
/// Group "Model": model name row + LLM status + Configure Prompt button.
/// Group "Language": Swiss German toggle (App-Group-scoped — group.com.dicticus).
///
/// Relocates content from AiCleanupInfoView + SwissGermanToggleRow per UIORG-04
/// (bindings and App-Group requirements unchanged).
struct AiCleanupPane: View {
    @EnvironmentObject var warmupService: ModelWarmupService
    @State private var showPromptEditor = false

    var body: some View {
        Form {
            Section("Model") {
                LabeledContent("Gemma 4 E2B (Q4_K_M)") {
                    statusView
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(warmupService.llmStatus == .ready ? "Model ready" : warmupService.llmStatus.label)

                LabeledContent("Cleanup prompt") {
                    Button("Configure…") {
                        showPromptEditor.toggle()
                    }
                    .popover(isPresented: $showPromptEditor, arrowEdge: .trailing) {
                        PromptEditorView(isPresented: $showPromptEditor)
                    }
                }
            }

            Section("Language") {
                SwissGermanFormRow()
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var statusView: some View {
        HStack(spacing: 4) {
            if warmupService.llmStatus.isActive {
                ProgressView()
                    .controlSize(.small)
            }
            Text(warmupService.llmStatus.label)
                .foregroundStyle(statusColor)
        }
    }

    private var statusColor: Color {
        switch warmupService.llmStatus {
        case .ready:   return Color(red: 0.17, green: 0.64, blue: 0.44)   // DESIGN.md `ready` light
        case .failed:  return .red
        case .downloading, .loading: return .orange
        case .idle:    return .secondary
        }
    }
}

/// Swiss German toggle row styled for a Settings Form (LabeledContent layout).
///
/// Backs the same App-Group-scoped `useSwissGerman` key as SwissGermanToggleRow.
/// MUST use UserDefaults(suiteName: "group.com.dicticus") — never raw @AppStorage.
private struct SwissGermanFormRow: View {
    private static let appGroupDefaults = UserDefaults(suiteName: "group.com.dicticus")!

    @State private var isOn: Bool = SwissGermanFormRow.currentValue()

    private static func currentValue() -> Bool {
        SwissDefaultMigration.runIfNeeded()
        let defaults = appGroupDefaults
        return defaults.object(forKey: "useSwissGerman") == nil
            ? true
            : defaults.bool(forKey: "useSwissGerman")
    }

    var body: some View {
        Toggle("Swiss German spelling (ß→ss)", isOn: $isOn)
            .onChange(of: isOn) { _, newValue in
                Self.appGroupDefaults.set(newValue, forKey: "useSwissGerman")
            }
    }
}
