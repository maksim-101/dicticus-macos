import SwiftUI

struct MenuBarView: View {
    var body: some View {
        VStack(spacing: 8) {
            // Permission rows and warm-up status will be added by Plans 02 and 03

            Divider()

            Button("Quit Dicticus") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 300)
    }
}
