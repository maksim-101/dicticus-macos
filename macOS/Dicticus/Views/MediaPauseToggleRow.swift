import SwiftUI

/// Settings toggle for PTT media auto-pause. Default ON when the key is absent.
///
/// Reads/writes `UserDefaults.standard` (macOS-only feature; NOT the App Group
/// suite — no cross-platform sync needed for this toggle).
struct MediaPauseToggleRow: View {

    @State private var isOn: Bool = MediaPauseToggleRow.currentValue()

    private static func currentValue() -> Bool {
        // Default ON when the key has never been written.
        UserDefaults.standard.object(forKey: "pauseMediaDuringDictation") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "pauseMediaDuringDictation")
    }

    var body: some View {
        HStack {
            Label("Pause media while dictating", systemImage: "pause.circle")
                .font(.body)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .accessibilityLabel("Pause media while dictating")
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .onChange(of: isOn) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "pauseMediaDuringDictation")
        }
    }
}
