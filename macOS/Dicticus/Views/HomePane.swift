import SwiftUI
import KeyboardShortcuts

/// Home pane of the popover: live status block + last transcription (D-06, D-07).
///
/// Status block maps the pipeline + permission state to exactly three visual states:
///   Ready / Recording… / Needs Permission (color-independent: dot + headline + glow ring all change).
///
/// The hotkey subline is produced by HotkeyDisplay.hotkeySubline (Plan 35-01) and
/// re-renders on every KeyboardShortcuts rebind via NotificationCenter observation.
/// Fn-combos from @EnvironmentObject modifierListener already republish via @Published.
///
/// Degraded-state affordance (Q-02): the entire status block is tappable when Needs Permission,
/// opening System Settings. Does NOT recreate PermissionRows / WarmupRow / multi-copy banner.
struct HomePane: View {

    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var hotkeyManager: HotkeyManager
    @EnvironmentObject var modifierListener: ModifierHotkeyListener

    // Re-render the subline whenever a standard hotkey binding changes.
    @State private var shortcutChangeToken: AnyObject? = nil
    @State private var sublineText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                statusBlock
                    .padding(16)

                Divider()
                    .padding(.horizontal, 16)

                lastTranscriptionSection
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
            }
        }
        .onAppear {
            refreshSubline()
            observeShortcutChanges()
        }
        // Re-render when Fn-combo bindings change (already @Published on modifierListener).
        .onChange(of: modifierListener.plainDictationCombo) { _, _ in refreshSubline() }
        .onChange(of: modifierListener.cleanupCombo) { _, _ in refreshSubline() }
    }

    // MARK: - Status block

    private var statusBlock: some View {
        let state = derivedState
        let (dotColor, glowColor, glowOpacity, headline) = stateVisuals(for: state)
        let needsPermission = (state == .needsPermission)

        return Group {
            if needsPermission {
                Button {
                    SystemSettingsURL.open(SystemSettingsURL.accessibility)
                } label: {
                    statusContent(
                        dotColor: dotColor,
                        glowColor: glowColor,
                        glowOpacity: glowOpacity,
                        headline: headline,
                        needsPermission: true
                    )
                }
                .buttonStyle(.plain)
            } else {
                statusContent(
                    dotColor: dotColor,
                    glowColor: glowColor,
                    glowOpacity: glowOpacity,
                    headline: headline,
                    needsPermission: false
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voiceOverLabel(for: state))
        .accessibilityAddTraits(needsPermission ? .isButton : [])
    }

    @ViewBuilder
    private func statusContent(
        dotColor: Color,
        glowColor: Color,
        glowOpacity: Double,
        headline: String,
        needsPermission: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(glowColor.opacity(glowOpacity))
                    .frame(width: 20, height: 20)
                Circle()
                    .fill(dotColor)
                    .frame(width: 12, height: 12)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.headline)
                    .foregroundStyle(dotColor)

                if needsPermission {
                    Text("Open System Settings →")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#F5A524"))
                } else {
                    Text(sublineText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.secondary)
                }
            }
        }
    }

    // MARK: - Last Transcription

    @ViewBuilder
    private var lastTranscriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LAST TRANSCRIPTION")
                .font(.caption)
                .foregroundStyle(Color.secondary)

            if let text = hotkeyManager.lastTranscriptionText, !text.isEmpty {
                Text(text)
                    .font(.body)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                CopyToClipboardButton(text: text)
                    .frame(maxWidth: .infinity)
            } else {
                Text("No recent transcription.")
                    .font(.body)
                    .foregroundStyle(Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Copy to Clipboard") {}
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(true)
                    .accessibilityLabel("Copy to Clipboard")
            }
        }
    }

    // MARK: - State derivation

    private enum StatusState: Equatable {
        case ready
        case recording
        case needsPermission
    }

    private var derivedState: StatusState {
        if hotkeyManager.pipelineState == .recording {
            return .recording
        }
        if !permissionManager.allGranted || hotkeyManager.registrationFailed {
            return .needsPermission
        }
        return .ready
    }

    private func stateVisuals(for state: StatusState) -> (dotColor: Color, glowColor: Color, glowOpacity: Double, headline: String) {
        switch state {
        case .ready:
            return (Color(hex: "#2BA471"), Color(hex: "#2BA471"), 0.16, "Ready")
        case .recording:
            return (Color(hex: "#E5484D"), Color(hex: "#E5484D"), 0.18, "Recording…")
        case .needsPermission:
            return (Color(hex: "#F5A524"), Color(hex: "#F5A524"), 0.16, "Needs Permission")
        }
    }

    // MARK: - Accessibility label

    private func voiceOverLabel(for state: StatusState) -> String {
        let hotkeyState: HotkeyDisplay.StatusState
        switch state {
        case .ready:         hotkeyState = .ready
        case .recording:     hotkeyState = .recording
        case .needsPermission: hotkeyState = .needsPermission
        }
        let (plain, cleanup) = resolvedShortcutDescriptions()
        return HotkeyDisplay.voiceOverStatusLabel(
            state: hotkeyState,
            plainStandard: plain,
            cleanupStandard: cleanup
        )
    }

    // MARK: - Subline helpers

    private func refreshSubline() {
        let (plain, cleanup) = resolvedShortcutDescriptions()
        sublineText = HotkeyDisplay.hotkeySubline(
            plainStandard: plain,
            cleanupStandard: cleanup
        )
    }

    private func resolvedShortcutDescriptions() -> (plain: String?, cleanup: String?) {
        let plain = KeyboardShortcuts.getShortcut(for: .plainDictation)?.description
        let cleanup = KeyboardShortcuts.getShortcut(for: .aiCleanup)?.description
        return (plain, cleanup)
    }

    private func observeShortcutChanges() {
        // RESEARCH "Don't Hand-Roll": observe KeyboardShortcuts' own change notification
        // so the subline re-renders on rebind without polling or parsing UserDefaults.
        let token = NotificationCenter.default.addObserver(
            forName: .init("KeyboardShortcuts_shortcutByNameDidChange"),
            object: nil,
            queue: .main
        ) { [self] _ in
            // Capture is safe: this closure is dispatched on main queue and HomePane
            // is a value type — Swift captures a copy, so no retain cycle.
            refreshSubline()
        }
        shortcutChangeToken = token as AnyObject
    }
}

// MARK: - CopyToClipboardButton

/// Full-width bordered-prominent copy button with a transient "Copied!" label.
private struct CopyToClipboardButton: View {

    let text: String
    @State private var showCopied = false

    var body: some View {
        Button(showCopied ? "Copied!" : "Copy to Clipboard") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            showCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showCopied = false
            }
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Copy to Clipboard: \(text.prefix(40))")
    }
}

// MARK: - Color(hex:) helper (local, macOS only)

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8)  & 0xFF) / 255
            b = Double(int         & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}
