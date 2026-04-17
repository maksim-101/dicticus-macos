import UserNotifications

/// Notification types for user-facing error states.
///
/// Per D-15: macOS notification for real errors.
/// Per D-16: No notification for silence-only recordings.
/// Per D-10: No audio feedback — silent operation.
/// Per UI-SPEC Notification States table: exact wording specified.
enum DicticusNotification {
    /// D-19: Hotkey pressed while already transcribing
    case busy
    /// D-17: Hotkey pressed before model warm-up completes
    case modelLoading
    /// D-15: Transcription pipeline returned an error
    case transcriptionFailed(Error)
    /// Recording could not start (mic unavailable, permission denied)
    case recordingFailed(Error)
    /// ASR output contained non-Latin script (Cyrillic, CJK, Arabic, etc.)
    case unexpectedLanguage

    /// Notification title — always "Dicticus" per UI-SPEC copywriting contract.
    var title: String { "Dicticus" }

    /// Notification body — problem statement + action hint, under 80 characters.
    /// Exact wording per UI-SPEC copywriting contract.
    var message: String {
        switch self {
        case .busy:
            return "Still processing \u{2014} try again in a moment."
        case .modelLoading:
            return "Models still loading, please wait a moment."
        case .transcriptionFailed:
            return "Transcription failed. Check that models are loaded."
        case .recordingFailed:
            return "Could not start recording. Check microphone permission."
        case .unexpectedLanguage:
            return "Unexpected language detected. Please try again."
        }
    }
}

/// Thin wrapper around UNUserNotificationCenter for posting error notifications.
///
/// Per RESEARCH.md: UNUserNotificationCenter works for bundled LSUIElement apps (A1).
/// Notifications are delivered immediately (trigger: nil).
/// No notification permission prompt needed — macOS allows notifications by default
/// for bundled apps; user can disable in System Settings > Notifications.
///
/// @MainActor ensures Swift 6 concurrency safety for the singleton pattern.
/// All call sites (HotkeyManager, app lifecycle) are already on @MainActor.
@MainActor
class NotificationService {
    static let shared = NotificationService()

    private init() {}

    /// Request notification authorization on first use.
    /// macOS grants by default for bundled apps — this is a no-op in most cases.
    func setup() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in
            // No error handling needed — notifications are best-effort for error reporting
        }
    }

    /// Post a notification to the user.
    ///
    /// Delivered immediately via UNNotificationRequest with nil trigger.
    /// Identifier is unique per request to prevent deduplication.
    func post(_ notification: DicticusNotification) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.message

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}
