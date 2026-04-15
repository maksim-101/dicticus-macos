import SwiftUI
import AVFoundation
@preconcurrency import ApplicationServices

/// Status of a single macOS permission.
enum PermissionStatus: Equatable {
    case granted
    case pending   // not yet requested or in-progress (shows "Required")
    case denied

    /// SF Symbol name representing this status.
    var iconName: String {
        switch self {
        case .granted: return "checkmark.circle.fill"
        case .pending: return "clock"
        case .denied:  return "xmark.circle.fill"
        }
    }

    /// Semantic color for the status badge.
    var color: Color {
        switch self {
        case .granted: return .green
        case .pending: return .secondary
        case .denied:  return .red
        }
    }

    /// Short label shown next to the status badge.
    var label: String {
        switch self {
        case .granted: return "Granted"
        case .pending: return "Required"
        case .denied:  return "Denied"
        }
    }
}

// Capture the AX prompt key at module load time to avoid Swift 6 shared-mutable-state
// warning when accessing the C global `kAXTrustedCheckOptionPrompt` from an actor.
// `nonisolated(unsafe)` marks this as explicitly owner-managed (read-only after init).
private nonisolated(unsafe) let axTrustedPromptKey: String =
    kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String

/// ObservableObject that checks and requests all three required macOS permissions:
/// Microphone, Accessibility, and Input Monitoring.
///
/// Polling every 2 seconds detects grants made in System Settings while the app is running.
/// Timer uses `[weak self]` to prevent retain cycles (T-02-03 mitigation).
@MainActor
class PermissionManager: ObservableObject {
    @Published var microphoneStatus: PermissionStatus = .pending
    @Published var accessibilityStatus: PermissionStatus = .pending
    @Published var inputMonitoringStatus: PermissionStatus = .pending
    @Published var hasCompletedOnboarding = false

    private static let onboardingKey = "hasCompletedOnboarding"

    private var pollTimer: Timer?

    /// True only when all three permissions are .granted.
    var allGranted: Bool {
        microphoneStatus == .granted &&
        accessibilityStatus == .granted &&
        inputMonitoringStatus == .granted
    }

    /// Check current permission states without triggering OS prompts.
    func checkAll() {
        // Microphone: AVCaptureDevice is the standard check on macOS
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        switch audioStatus {
        case .authorized:           microphoneStatus = .granted
        case .denied, .restricted:  microphoneStatus = .denied
        case .notDetermined:        microphoneStatus = .pending
        @unknown default:           microphoneStatus = .pending
        }

        // Accessibility: AXIsProcessTrusted() reflects current TCC state
        accessibilityStatus = AXIsProcessTrusted() ? .granted : .denied

        // Input Monitoring: CGPreflightListenEventAccess() checks without requesting
        inputMonitoringStatus = CGPreflightListenEventAccess() ? .granted : .pending
    }

    /// Trigger the OS microphone permission prompt. Updates status after user responds.
    func requestMicrophone() async {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        microphoneStatus = granted ? .granted : .denied
    }

    /// Trigger the OS Accessibility permission prompt.
    /// The result is not immediate — the user must go to System Settings.
    /// Polling via startPolling() will detect the change.
    func requestAccessibility() {
        // Use the module-level cached key (avoids Swift 6 concurrency error on C global)
        let options: NSDictionary = [axTrustedPromptKey: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
        // Do not update status here — polling picks it up within 2 seconds
    }

    /// Trigger the OS Input Monitoring permission prompt.
    func requestInputMonitoring() {
        let granted = CGRequestListenEventAccess()
        inputMonitoringStatus = granted ? .granted : .pending
    }

    /// Start polling all permissions every 2 seconds.
    /// Call this once from the UI entry point (MenuBarView.onAppear).
    func startPolling() {
        checkAll()
        // [weak self] prevents retain cycle (T-02-03 mitigation)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAll()
            }
        }
    }

    /// Stop polling. Call when the app is terminating or entering background.
    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Mark onboarding as complete and persist to UserDefaults.
    func markOnboardingComplete() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
    }

    /// Load onboarding completion state from UserDefaults.
    func loadOnboardingState() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingKey)
    }
}
