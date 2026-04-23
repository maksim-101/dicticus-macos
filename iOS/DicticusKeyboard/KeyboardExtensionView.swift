import SwiftUI

struct KeyboardKey: View {
    let label: String
    let action: () -> Void
    var width: CGFloat? = nil
    var color: Color? = nil
    var foregroundColor: Color = .primary

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            Text(label)
                .font(.system(size: 20))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color ?? (colorScheme == .dark ? Color.white.opacity(0.3) : .white))
                )
                .foregroundColor(foregroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 0, x: 0, y: 1)
        }
        .frame(width: width)
    }
}

struct KeyboardExtensionView: View {
    @Environment(\.colorScheme) var colorScheme
    var proxy: UITextDocumentProxy
    var advanceToNextInputMode: () -> Void
    @ObservedObject var dictationController: DicticusKeyboardDictationController

    @State private var isUppercase = false

    let row1 = ["Q", "W", "E", "R", "T", "Z", "U", "I", "O", "P"]
    let row2 = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
    let row3 = ["Y", "X", "C", "V", "B", "N", "M"]

    private var functionalKeyColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color(UIColor.systemGray2)
    }

    // MARK: - Mic Button State

    private var micButtonLabel: String {
        switch dictationController.state {
        case .idle: return "\u{1F3A4}"           // microphone emoji
        case .waitingForApp: return "\u{23F3}"   // hourglass
        case .recording: return "\u{23F9}"       // stop button
        case .transcribing: return "\u{1F4AC}"   // speech bubble
        }
    }

    private var micButtonColor: Color {
        switch dictationController.state {
        case .idle: return functionalKeyColor
        case .waitingForApp: return .orange.opacity(0.7)
        case .recording: return .red
        case .transcribing: return .blue.opacity(0.7)
        }
    }

    private var micButtonForeground: Color {
        dictationController.state == .idle ? .primary : .white
    }

    var body: some View {
        VStack(spacing: 8) {
            // Row 1
            HStack(spacing: 6) {
                ForEach(row1, id: \.self) { key in
                    KeyboardKey(label: transform(key), action: { insert(key) })
                }
            }

            // Row 2
            HStack(spacing: 6) {
                Spacer(minLength: 15)
                ForEach(row2, id: \.self) { key in
                    KeyboardKey(label: transform(key), action: { insert(key) })
                }
                Spacer(minLength: 15)
            }

            // Row 3
            HStack(spacing: 6) {
                KeyboardKey(
                    label: "\u{21E7}",
                    action: { isUppercase.toggle() },
                    width: 44,
                    color: isUppercase ? .blue : functionalKeyColor,
                    foregroundColor: isUppercase ? .white : .primary
                )

                ForEach(row3, id: \.self) { key in
                    KeyboardKey(label: transform(key), action: { insert(key) })
                }

                KeyboardKey(
                    label: "\u{232B}",
                    action: { proxy.deleteBackward() },
                    width: 44,
                    color: functionalKeyColor
                )
            }

            // Row 4
            HStack(spacing: 6) {
                KeyboardKey(label: "123", action: { }, width: 44, color: functionalKeyColor)
                KeyboardKey(label: "\u{1F310}", action: advanceToNextInputMode, width: 44, color: functionalKeyColor)
                KeyboardKey(label: "space", action: { proxy.insertText(" ") })

                // Mic button -- shows state-dependent appearance, triggers dictation
                Button(action: {
                    dictationController.handleMicTap()
                }) {
                    Text(micButtonLabel)
                        .font(.system(size: 20))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(micButtonColor)
                        )
                        .foregroundColor(micButtonForeground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 0, x: 0, y: 1)
                }
                .frame(width: 44)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            if dictationController.state != .idle {
                                dictationController.handleCancelTap()
                            }
                        }
                )

                KeyboardKey(label: "return", action: { proxy.insertText("\n") }, width: 64, color: functionalKeyColor)
            }
        }
        .padding(4)
        .background(colorScheme == .dark ? Color.black.opacity(0.8) : Color(UIColor.systemGray4))
    }

    private func transform(_ key: String) -> String {
        isUppercase ? key.uppercased() : key.lowercased()
    }

    private func insert(_ key: String) {
        proxy.insertText(transform(key))
    }
}
