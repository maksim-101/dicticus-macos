import SwiftUI

/// A reusable row component showing the status of a single macOS permission.
///
/// Displays:
/// - Status badge icon (checkmark/clock/xmark) with semantic color
/// - Permission name
/// - Status label ("Granted" / "Required" / "Denied")
/// - Action button: "Grant Access" for pending, "Open Settings" for denied
struct PermissionRow: View {
    let title: String
    let status: PermissionStatus
    /// Called when the user taps "Grant Access" in the .pending state.
    let grantAction: () -> Void
    /// The System Settings pane to open when the permission is .denied.
    let settingsURL: URL

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: status.iconName)
                .foregroundColor(status.color)
                .frame(width: 16)

            Text(title)
                .font(.body)

            Spacer()

            Text(status.label)
                .font(.caption)
                .foregroundColor(.secondary)

            if status != .granted {
                Button(status == .denied ? "Open Settings" : "Grant Access") {
                    if status == .denied {
                        SystemSettingsURL.open(settingsURL)
                    } else {
                        grantAction()
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}
