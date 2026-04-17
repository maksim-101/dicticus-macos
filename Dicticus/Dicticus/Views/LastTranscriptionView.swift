import SwiftUI

/// Last transcription preview with copy button.
///
/// Per D-21: Shows truncated text of last successful transcription.
///   Copy button as fallback if paste-at-cursor failed or user wants the text again.
/// Per UI-SPEC:
///   - Section heading "Last Transcription" (.headline, semibold)
///   - Text: .lineLimit(2), .truncationMode(.tail), .body style
///   - Copy button: .controlSize(.small), .buttonStyle(.bordered), right-aligned
///   - Section hidden entirely when text is nil
struct LastTranscriptionView: View {
    let text: String?

    var body: some View {
        if let text, !text.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Last Transcription")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 4)

                HStack(alignment: .top) {
                    Text(text)
                        .font(.body)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .accessibilityLabel("Last transcription")

                    Spacer()

                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Copy last transcription")
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }
}
