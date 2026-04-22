import SwiftUI

struct KeyboardKey: View {
    let label: String
    let action: () -> Void
    var width: CGFloat? = nil
    var color: Color = Color(UIColor.systemBackground)
    var foregroundColor: Color = .primary
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 20))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(color)
                .foregroundColor(foregroundColor)
                .cornerRadius(5)
                .shadow(color: Color.black.opacity(0.2), radius: 0, x: 0, y: 1)
        }
        .frame(width: width)
    }
}

struct KeyboardExtensionView: View {
    var proxy: UITextDocumentProxy
    var advanceToNextInputMode: () -> Void
    var startDictation: () -> Void
    
    @State private var isUppercase = false
    
    let row1 = ["Q", "W", "E", "R", "T", "Z", "U", "I", "O", "P"]
    let row2 = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
    let row3 = ["Y", "X", "C", "V", "B", "N", "M"]
    
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
                    color: isUppercase ? .blue : Color(UIColor.systemGray2),
                    foregroundColor: isUppercase ? .white : .primary
                )
                
                ForEach(row3, id: \.self) { key in
                    KeyboardKey(label: transform(key), action: { insert(key) })
                }
                
                KeyboardKey(
                    label: "⌫",
                    action: { proxy.deleteBackward() },
                    width: 44,
                    color: Color(UIColor.systemGray2)
                )
            }
            
            // Row 4
            HStack(spacing: 6) {
                KeyboardKey(label: "123", action: { }, width: 44, color: Color(UIColor.systemGray2))
                KeyboardKey(label: "🌐", action: advanceToNextInputMode, width: 44, color: Color(UIColor.systemGray2))
                KeyboardKey(label: "space", action: { proxy.insertText(" ") })
                KeyboardKey(label: "🎙️", action: startDictation, width: 44, color: Color(UIColor.systemGray2))
                KeyboardKey(label: "return", action: { proxy.insertText("\n") }, width: 64, color: Color(UIColor.systemGray2))
            }
        }
        .padding(4)
        .background(Color(UIColor.systemGray4).edgesIgnoringSafeArea(.all))
    }
    
    private func transform(_ key: String) -> String {
        isUppercase ? key.uppercased() : key.lowercased()
    }
    
    private func insert(_ key: String) {
        proxy.insertText(transform(key))
        // Auto-lowercase if we wanted to be fancy, but keeping it simple for now
    }
}
