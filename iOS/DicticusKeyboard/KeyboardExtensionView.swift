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
    var startDictation: () -> Void
    
    @State private var isUppercase = false
    
    let row1 = ["Q", "W", "E", "R", "T", "Z", "U", "I", "O", "P"]
    let row2 = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
    let row3 = ["Y", "X", "C", "V", "B", "N", "M"]
    
    private var functionalKeyColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color(UIColor.systemGray2)
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
                    label: "⇧",
                    action: { isUppercase.toggle() },
                    width: 44,
                    color: isUppercase ? .blue : functionalKeyColor,
                    foregroundColor: isUppercase ? .white : .primary
                )
                
                ForEach(row3, id: \.self) { key in
                    KeyboardKey(label: transform(key), action: { insert(key) })
                }
                
                KeyboardKey(
                    label: "⌫",
                    action: { proxy.deleteBackward() },
                    width: 44,
                    color: functionalKeyColor
                )
            }
            
            // Row 4
            HStack(spacing: 6) {
                KeyboardKey(label: "123", action: { }, width: 44, color: functionalKeyColor)
                KeyboardKey(label: "🌐", action: advanceToNextInputMode, width: 44, color: functionalKeyColor)
                KeyboardKey(label: "space", action: { proxy.insertText(" ") })
                KeyboardKey(label: "🎙️", action: startDictation, width: 44, color: functionalKeyColor)
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
        // Auto-lowercase if we wanted to be fancy, but keeping it simple for now
    }
}
